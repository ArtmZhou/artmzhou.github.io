---
title: "Ascend C 算子开发：从工程生成到 ACLNN 分层接入与调用"
date: 2026-10-08T16:00:00+08:00
lastmod: 2026-10-10T16:00:00+08:00
draft: false
tags: ["Ascend C", "ACLNN", "自定义算子"]
categories: ["Ascend C 算子开发"]
summary: "从 msopgen 工程生成与算子包部署出发，串起原型、InferShape、Tiling、L2 / L0 与 Kernel，说明 ACLNN 两阶段调用、关键宏和内存生命周期。"
description: "融合工程实践与 CANN ACLNN 分层机制，梳理自定义算子的开发、注册、编译安装和两阶段调用流程。"
showtoc: true
tocopen: true
---

一个自定义算子要被应用调用，除了 Kernel 计算，还需要完整的接入流程：工程描述输入输出，Host 推导形状与切分策略，接口组织执行任务，部署产物让调用方找到它。

本文以 `add_custom` 的工程记录为起点，结合 ACLNN 的分层实现，沿着“生成工程 → 理解内部职责 → 编译部署 → 应用调用”展开。2026 年 10 月 10 日更新，合并了《CANN aclnn 单算子开发接入》的内容，保留原有工程与安装截图。

文中的目录和注册方式来自不同层次的工程：`msopgen` 模板可以自动生成部分胶水代码，算子源码仓库则可能显式维护 `op_graph`、`op_api` 等目录。它们有对应职责，但不要求每个自定义算子都手写全部文件。代码用于说明接入流程，未在 NPU 上编译运行。

## 1. 从 msopgen 生成工程开始

`add_custom.json` 描述算子原型，包括输入、输出、数据类型、格式及属性等。原笔记中的简写命令是：

```bash
msopgen gen -i ./add_custom.json -lan cpp -out ./
```

实际使用时应按安装版本补齐参数。例如，CANN 8.5 的工具文档将 `-c` 列为必选项，用于指定计算资源和目标 SoC；下面的 `AscendXXX` 需要替换为设备型号：

```bash
msopgen gen -i ./add_custom.json \
  -c ai_core-AscendXXX -lan cpp -out ./AddCustom
```

使用前可通过 `msopgen gen --help` 核对当前工具支持的选项。框架选项与生成模板也随版本变化，不能仅凭一条历史命令判断最终目录结构。[msOpGen 参数说明][msopgen]

![msopgen 生成的算子工程目录结构](/images/ascend-c/operator-project.png)

主要目录和文件的作用如下：

| 目录 / 文件 | 作用 |
| --- | --- |
| `op_host` | Host 侧原型注册、Tiling、Shape / Dtype 推导及相关编译配置。 |
| `op_kernel` | Device 侧 Kernel 实现，以及模板安排在此处的 Tiling 定义和编译配置。 |
| `build.sh` | 工程编译脚本。 |
| `CMakeLists.txt` | 工程编译文件。 |
| `CMakePresets.json` | CANN 路径、目标产品、编译产物等配置，具体字段取决于模板。 |

工程生成只搭好框架。原型、支持的数据类型与格式、Host 推导逻辑、Kernel 实现仍要保持一致，之后才能编译出可用的算子。

## 2. 七类职责：从工程目录看到运行链路

阅读采用显式分层结构的算子源码时，可以按下面的职责定位文件。这里的 L2、L0 是 **Host 侧接口层次**，与硬件存储中的 L2 Cache、L0A / L0B / L0C 不是同一个概念。

| 职责 | 常见位置 | 关键接口或宏 |
| --- | --- | --- |
| 原型声明 | `op_graph/<op>_proto.h` | `REG_OP`、`INPUT`、`OUTPUT`、`ATTR` |
| 算子信息与产品配置 | `op_host/<op>_def.cpp` | `OpDef` 的 `Input`、`Output`、`Attr`、`AICore` 配置 |
| 输出推导 | `op_host/<op>_infershape.cpp` | `IMPL_OP_INFERSHAPE`，或模板中的推导函数注册 |
| 切分与实现选择 | `op_host/op_tiling/` | `IMPL_OP_OPTILING`、`Tiling`、`TilingParse` |
| 对外 L2 接口 | `op_host/op_api/aclnn_<op>.cpp` | `aclnnXxxGetWorkspaceSize`、`aclnnXxx` |
| 内部 L0 接口 | `op_host/op_api/<op>.cpp` | `OP_TYPE_REGISTER`、`INFER_SHAPE`、`ADD_TO_LAUNCHER_LIST_AICORE` |
| Kernel 计算 | `op_kernel/<op>.cpp` | `__global__ __aicore__`、`GET_TILING_DATA_WITH_STRUCT` |

这是一张职责地图，不是固定的七个开发步骤。简单模板可能把原型、InferShape 和 Tiling 注册放在同一个 Host 文件中，并自动生成 ACLNN 接口。多策略算子才可能额外使用 `REGISTER_TILING_TEMPLATE`；它不是每个算子的必选项。

### 原型声明与 OpDef 配置分别看什么

原型描述算子的输入、可选输入、输出和属性。例如，采用图原型声明方式时，一个带可选 bias 的独立示例可以写成：

```cpp
// 原型示意；类型、属性和头文件按实际工程补齐。
REG_OP(ExampleWithBias)
    .INPUT(x, TensorType({DT_FLOAT16}))
    .OPTIONAL_INPUT(bias, TensorType({DT_FLOAT16}))
    .OUTPUT(y, TensorType({DT_FLOAT16}))
    .ATTR(transpose, Bool, false)
    .OP_END_FACTORY_REG(ExampleWithBias)
```

采用 `OpDef` 的模板通过 `this->Input()`、`this->Output()`、`this->Attr()` 等接口描述算子，并配置支持的产品及实现。继承 `OpDef`、通过 `OP_ADD` 注册后，工程工具可以自动生成图模式原型与单算子 API。[算子原型定义][op-definition]

这里的 `OpDef` 是正式的算子定义接口，与原笔记中引用的框架能力 `op_def` 预留接口章节并非同一概念。实际开发应沿用所属工程的定义方式，避免重复手写工具已经生成的原型。

## 3. 先理解 ACLNN 的两阶段接口

对调用者而言，核心接口通常是这两个：

```cpp
// 签名示意：实际输入、属性和输出以生成的 aclnn_*.h 为准。
aclnnStatus aclnnXxxGetWorkspaceSize(
    /* 输入、属性、输出 */ ...,
    uint64_t* workspaceSize, aclOpExecutor** executor);

aclnnStatus aclnnXxx(
    void* workspace, uint64_t workspaceSize,
    aclOpExecutor* executor, aclrtStream stream);
```

第一阶段在 Host 侧校验参数、组织任务并准备执行所需信息，返回临时内存大小与执行器。调用者据此分配 workspace，再调用第二阶段向指定 stream 提交计算。第二阶段成功返回，并不等于 Device 已完成计算；读取结果前仍需要同步。[单算子 API 调用][single-op]

```text
应用准备输入、输出与 aclTensor
  ↓
aclnnXxxGetWorkspaceSize
  ├─ L2：参数校验，创建 executor，组织转换及计算任务
  ├─ L0：准备输出描述，按需推导 Shape，加入任务
  └─ Host 准备与内存规划 → 返回 workspaceSize、executor
  ↓
应用按 workspaceSize 分配 Device workspace
  ↓
aclnnXxx → CommonOpExecutorRun → 向 stream 提交任务
  ↓
Kernel 读取 TilingData，搬运、计算、写回
  ↓
应用同步 stream，读取结果，释放资源
```

这里的 workspace 是 Device 全局内存中的临时工作区，不是 UB、L1 或 L0 中的片上缓冲区。不同算子可能用它存放中间结果、转换后的数据或其他执行所需内容。

## 4. L2 与 L0：把一次 API 调用组织成执行任务

### L2 负责对外语义和任务编排

第一阶段常见的步骤是创建执行器、校验参数、处理非连续输入或格式差异、调用 L0 接口，再将内部结果对接到用户输出。一个 L2 接口可以组合多个 L0 任务，例如格式转换、核心计算和输出拷贝。

下面是**省略错误分支与业务处理的伪代码**，用于展示调用顺序。真实实现必须检查空指针、Shape、Dtype、格式及各步骤返回值：

```cpp
// 位于 aclnnExampleOpGetWorkspaceSize 内。
L2_DFX_PHASE_1(aclnnExampleOp, DFX_IN(x), DFX_OUT(out));
auto uniqueExecutor = CREATE_EXECUTOR();
// 检查 uniqueExecutor、workspaceSize、executor 及业务参数。

// 按需通过 L0 接口组织连续化、转换等任务。
auto result = l0op::ExampleOp(x, uniqueExecutor.get());
// 检查 result；若需要，将内部结果写入调用者的 out。
auto copyResult = l0op::ViewCopy(result, out, uniqueExecutor.get());
// 检查 copyResult。

*workspaceSize = uniqueExecutor->GetWorkspaceSize();
uniqueExecutor.ReleaseTo(executor);
// 返回 ACLNN_SUCCESS。
```

连续化、转置、格式转换和 `ViewCopy` 是否需要，取决于算子实现。第一阶段可以把这些操作加入任务列表；不能据此认为相应的 Device 数据搬运已经完成。

第二阶段常见的封装较短：

```cpp
extern "C" aclnnStatus aclnnExampleOp(
    void* workspace, uint64_t workspaceSize,
    aclOpExecutor* executor, aclrtStream stream)
{
    L2_DFX_PHASE_2(aclnnExampleOp);
    return CommonOpExecutorRun(workspace, workspaceSize, executor, stream);
}
```

| 宏 / 接口 | 在这条链路中的作用 |
| --- | --- |
| `L2_DFX_PHASE_1` | 在第一阶段入口记录接口时延与参数。 |
| `DFX_IN` / `DFX_OUT` | 包装需要记录的输入、属性与输出参数。 |
| `CREATE_EXECUTOR` | 创建管理 `aclOpExecutor` 的 `UniqueExecutor`。 |
| `GetWorkspaceSize` | 汇总执行这些任务所需的 workspace 大小。 |
| `ReleaseTo` | 将执行器指针移交给第一阶段的输出参数。 |
| `L2_DFX_PHASE_2` | 在第二阶段入口记录执行阶段时延。 |
| `CommonOpExecutorRun` | 使用 workspace 和 stream 执行执行器中的任务。 |

打点宏应放在相应接口入口。`ReleaseTo` 传递的是执行器指针，并不代表 Device 已执行；workspace 大于 0 时，第二阶段必须收到有效的 workspace 地址。[CREATE_EXECUTOR][create-executor]、[GetWorkspaceSize][workspace-size]、[ReleaseTo][release-to]、[CommonOpExecutorRun][executor-run]

### L0 负责把具体算子任务加入执行器

L0 一般围绕一个具体算子准备张量描述、推导输出，并调用任务构建宏。下面仍是流程片段，假设相关类型、函数和原型已在工程中定义：

```cpp
namespace l0op {
OP_TYPE_REGISTER(ExampleOp);

const aclTensor* ExampleOp(const aclTensor* x, aclOpExecutor* executor)
{
    L0_DFX(ExampleOp, x);
    auto output = executor->AllocTensor(
        x->GetDataType(), Format::FORMAT_ND, Format::FORMAT_ND);
    if (output == nullptr) { return nullptr; }

    auto ret = INFER_SHAPE(ExampleOp, OP_INPUT(x), OP_OUTPUT(output));
    if (ret != ACLNN_SUCCESS) { return nullptr; }

    ret = ADD_TO_LAUNCHER_LIST_AICORE(
        ExampleOp, OP_INPUT(x), OP_OUTPUT(output));
    if (ret != ACLNN_SUCCESS) { return nullptr; }
    return output;
}
}
```

| 宏 / 接口 | 使用时关注的点 |
| --- | --- |
| `OP_TYPE_REGISTER` | 注册 L0 算子名称与 TypeID，通常位于 L0 实现文件开头。 |
| `L0_DFX` | 位于 L0 函数入口，用于时延与参数记录。 |
| `AllocTensor` | 向执行器申请内部 Tensor，描述其类型、形状与格式。 |
| `INFER_SHAPE` | 调用已注册的推导逻辑；需要推导时，应在任务入队前完成。 |
| `OP_INPUT` / `OP_OUTPUT` / `OP_ATTR` | 按原型顺序包装输入、输出和属性。 |
| `ADD_TO_LAUNCHER_LIST_AICORE` | 创建 AI Core 执行任务并加入执行器队列。 |
| `ConvertToTensor` | 将支持的 Host 标量、数组等转换为 Host 侧 Tensor 对象。 |

`AllocTensor` 是执行器内部的 Tensor 管理接口，不应与调用方的 `aclrtMalloc` 等同。内部临时 Tensor 的内存需求进入框架的执行与 workspace 规划；应用仍要负责分配第一阶段返回的 workspace。[AllocTensor][alloc-tensor]、[ConvertToTensor][convert-tensor]

`INFER_SHAPE` 解决的是输出形状，`ADD_TO_LAUNCHER_LIST_AICORE` 组织的是执行任务。后者文档中的“在二阶段执行”，指的是任务执行，不足以推断所有 Host 准备工作也都发生在第二阶段。[INFER_SHAPE][infer-shape]、[ADD_TO_LAUNCHER_LIST_AICORE][launcher]

## 5. InferShape 与 Tiling：注册入口，分清时机

InferShape 回答“输出是什么形状”；Tiling 回答“任务怎样切分、选择哪个实现、需要多少临时空间”。二者都可以通过注册机制让框架调用，但职责不同。

| 项目 | InferShape | Tiling |
| --- | --- | --- |
| 常见上下文 | `gert::InferShapeContext` | `gert::TilingContext` |
| 主要输入 | 输入形状、属性等 | Shape、Dtype、属性、平台与实现信息等 |
| 主要产物 | 输出形状 | TilingData、TilingKey、核数及 workspace 需求等 |
| 显式注册示例 | `IMPL_OP_INFERSHAPE` | `IMPL_OP_OPTILING` |
| 后续消费 | 输出 Tensor 描述与任务构建 | Kernel 分支选择与分块计算 |

采用拆分注册文件的工程，常见写法如下；函数名与编译信息类型是示意：

```cpp
IMPL_OP_INFERSHAPE(ExampleOp).InferShape(InferShapeForExampleOp);

IMPL_OP_OPTILING(ExampleOp)
    .Tiling(TilingForExampleOp)
    .TilingParse<ExampleCompileInfo>(TilingParseForExampleOp);
```

`TilingParse` 可用于解析编译信息和准备平台相关数据。另一类模板通过 `OpDef` 的 `SetInferShape`、`AICore().SetTiling` 等接口注册相应函数。应沿用当前工程的方式，不要把两套示意代码全部重复添加。[OpDef 注册示例][op-definition]

多策略工程还可能通过 `REGISTER_TILING_TEMPLATE`、`TilingRegistry` 管理候选实现。这属于相应仓库的策略选择机制，具体优先级与筛选流程要看该仓库实现，不能当作所有 ACLNN 算子的统一要求。

### Tiling 不是只能在第二阶段触发

L0 函数里没有显式写 `TilingFunc(...)`，不代表第一阶段不会做 Tiling。任务准备可以通过框架间接触发 Tiling；第一阶段需要完成足以确定 workspace 的准备工作，后续还可能复用缓存结果。

官方算子接口文档中，第一阶段存在 `ACLNN_ERR_INNER_TILING_ERROR` 返回码，这直接说明“第一阶段绝不发生 Tiling”的说法不成立。阅读源码时，应追踪具体版本的任务构建与执行器准备流程。[第一阶段 Tiling 错误示例][tiling-phase]

因此，更稳妥的理解是：**Host 按注册信息准备执行所需的 Tiling，Kernel 消费这些信息；两阶段边界用于区分准备与提交执行，不能简单等同于“无 Tiling / 有 Tiling”。**

## 6. Kernel：按约定读取 TilingData

Kernel 接收到 `tiling` 参数后，按 Host 侧约定的结构读取数据，初始化计算对象，再执行搬运、计算与写回。

```cpp
// 示意代码：ExampleTilingData 与 KernelExample 由具体算子定义。
extern "C" __global__ __aicore__ void example_op(
    GM_ADDR x, GM_ADDR y, GM_ADDR workspace, GM_ADDR tiling)
{
    REGISTER_TILING_DEFAULT(ExampleTilingData);
    GET_TILING_DATA_WITH_STRUCT(ExampleTilingData, tilingData, tiling);
    KernelExample op;
    op.Init(x, y, workspace, &tilingData);
    op.Process();
}
```

`REGISTER_TILING_DEFAULT` 用于注册采用标准 C++ 定义的默认 TilingData 类型；`GET_TILING_DATA_WITH_STRUCT` 按指定结构取出数据。它们有正式的 Kernel Tiling 文档，支持范围和用法需要与工程版本匹配。[Kernel Tiling 接口][kernel-tiling]

Host 与 Kernel 必须对结构字段、类型、布局和 TilingKey 含义保持一致。Tiling 模板、默认结构注册与 Kernel 分支选择分别发生在不同位置，不能只因名字里都有“注册”就视为同一件事。

## 7. 编译部署：让调用方找到头文件、动态库和算子实现

完成原型、Host 和 Kernel 后，检查 `CMakePresets.json` 中的 CANN 路径、目标 SoC、厂商名与打包选项，再按所用模板执行编译。原文所用的 `.run` 包工程通常提供以下入口：

```bash
./build.sh
```

构建产物取决于配置：可能是安装包，也可能是动态库或静态库。对于 `.run` 包场景，用实际生成的文件名替换示例名称；以下命令以当前目录下的 `.local` 为安装根目录：

```bash
./add_custom_template.run --install-path="$(pwd)/.local"
```

指定安装路径后，算子通常位于 `<安装根目录>/vendors/<vendor_name>`。假设厂商名为默认的 `customize`，按安装包提供的脚本使其在当前终端生效：

```bash
source "$(pwd)/.local/vendors/customize/bin/set_env.bash"
```

该脚本配置自定义算子搜索路径。实际安装目录和厂商名应以产物为准；指定目录安装的布局及环境设置见官方说明。[算子包部署][deploy]

![左侧为算子安装后的目录，右侧为调用方引入安装路径的配置](/images/ascend-c/operator-call-path.png)

图左侧是安装后的目录，右侧是调用方引用该目录的配置。接入时需要同时关注三件事：

| 环节 | 需要接入什么 | 常见问题 |
| --- | --- | --- |
| 编译应用 | `op_api/include/aclnn_*.h` | 找不到头文件，或声明与已安装库不匹配。 |
| 链接和加载 | `op_api/lib/libcust_opapi.so` 及版本要求的运行时库 | 链接失败、符号缺失、运行时找不到 `.so`。 |
| 查找算子实现 | 自定义 OPP 路径、产品配置及 Kernel 产物 | 已找到 API 库，但找不到对应产品的算子实现。 |

例如，在调用方已有 CMake 目标 `execute_add_op` 的前提下，可以增加自定义 API 目录与库：

```cmake
# 示例绝对路径，替换成真实安装位置。
set(CUSTOM_OP_API_DIR "/absolute/install/root/vendors/customize/op_api")
target_include_directories(execute_add_op PRIVATE "${CUSTOM_OP_API_DIR}/include")
target_link_directories(execute_add_op PRIVATE "${CUSTOM_OP_API_DIR}/lib")
target_link_libraries(execute_add_op PRIVATE cust_opapi)
```

这只是自定义库的增量配置；AscendCL 头文件、运行时库及其搜索路径仍沿用对应 CANN 版本的调用示例。运行时还需通过环境脚本、RPATH 或库搜索路径找到这些动态库。[单算子 API 的编译配置][single-op]

## 8. 应用调用：准备 Tensor、申请 workspace、同步结果

调用方的完整顺序是：初始化 AscendCL、选择设备并创建 stream；准备输入输出 Device 内存与 `aclTensor`；完成两阶段调用；同步并取回结果；最后释放资源。

下面是已完成环境和 Tensor 准备后的核心片段。假设安装包实际生成了这些 `AddCustom` 接口，且 `CHECK_ACL`、`CHECK_ACLNN` 由应用实现，用于检查错误并进入统一清理路径：

```cpp
uint64_t workspaceSize = 0;
aclOpExecutor* executor = nullptr;
CHECK_ACLNN(aclnnAddCustomGetWorkspaceSize(
    x, y, out, &workspaceSize, &executor));

void* workspace = nullptr;
if (workspaceSize > 0) {
    CHECK_ACL(aclrtMalloc(&workspace, workspaceSize, ACL_MEM_MALLOC_HUGE_FIRST));
}

CHECK_ACLNN(aclnnAddCustom(workspace, workspaceSize, executor, stream));
CHECK_ACL(aclrtSynchronizeStream(stream));

// 同步成功后，将 out 对应的 Device buffer 拷回 Host 并校验结果。
// 任务不再使用后，释放 workspace、输入输出 buffer 和 Tensor 描述。
```

生成的算子名、输入参数顺序、输出声明可能不同，应直接查阅安装包中的头文件。`aclCreateTensor` 描述逻辑形状、步长、格式和已有数据地址，不能代替输入输出 buffer 的分配。Shape 与布局的关系可参考 [aclTensor 的 Shape、Stride 与 ND / NZ](/posts/ascend-c-acltensor-shape-layout/)。

### 哪些资源由谁管理

| 资源 | 管理要点 |
| --- | --- |
| 输入、输出 Device buffer | 应用分配；等待相关异步操作结束后释放。 |
| 应用创建的 `aclTensor` | 应用销毁描述对象；底层 buffer 需要独立管理。 |
| workspace | 应用按第一阶段返回的字节数分配；任务结束前保持有效。 |
| 执行器内部 Tensor | 由执行器管理，应用不应逐个释放。 |
| 普通非复用 `aclOpExecutor` | 框架在第二阶段调用时自动释放，不要在应用中无条件重复销毁。 |
| stream 与运行环境 | 在任务结束、资源清理后销毁 stream，再按应用生命周期释放设备与环境。 |

显式设置为可复用的执行器需要配套调用 `aclDestroyAclOpExecutor`，并遵循相应版本的复用协议。若第一阶段成功后应用提前退出、未进入正常第二阶段，也应按版本规定处理异常清理。[执行器生命周期][executor-lifetime]

`AbandonCache` 是关闭相关 ACLNN 缓存的框架接口，用于必须执行第一阶段逻辑的特定场景，不需要给每个简单算子都加上。它不等于调用方可以任意跳过第一阶段，也不等于所有执行器都可以重复运行。[AbandonCache][abandon-cache]

## 9. 按链路定位接入问题

| 现象 | 优先检查 |
| --- | --- |
| 编译时找不到接口 | 生成的头文件名、include 路径、CANN 版本和实际安装包。 |
| 运行时找不到库或算子 | `.so` 加载路径、自定义 OPP 环境、vendor、目标 SoC 与 Kernel 产物。 |
| 第一阶段返回错误 | 参数检查、Shape / Dtype / 格式约束、InferShape、任务准备与 Tiling 日志。 |
| workspace 为 0 | 可以是合法结果；按接口约定传参，不为了形式完整而强行分配。 |
| 第二阶段返回成功但数据未就绪 | 检查 stream 同步，以及输入输出和 workspace 是否被提前释放。 |
| 结果形状或数值异常 | 原型与属性顺序、视图步长、TilingData 布局、尾块处理和 Kernel 分支。 |

跟踪一次调用时，先找到对外的 `aclnnXxxGetWorkspaceSize`，再沿着 L0 任务、Host 注册与 Kernel 入口向下看。这样既能知道某个宏负责什么，也能找到它与编译产物、运行时参数之间的联系。

## 参考文档

本文保留原稿使用的 CANN 8.5.0.alpha002 框架接口链接，并补充工程生成、部署与 Kernel Tiling 文档。实际实现请切换到所安装版本及目标产品对应的文档。

- 工程与交付：[msOpGen][msopgen]、[算子包部署][deploy]、[单算子 API 调用][single-op]。
- L0 任务构建：[OP_TYPE_REGISTER][op-type]、[L0_DFX][l0-dfx]、[INFER_SHAPE][infer-shape]、[OP_INPUT][op-input]、[OP_OUTPUT][op-output]、[OP_ATTR][op-attr]、[ADD_TO_LAUNCHER_LIST_AICORE][launcher]。
- L2 入口：[L2_DFX_PHASE_1][l2-phase1]、[L2_DFX_PHASE_2][l2-phase2]、[DFX_IN][dfx-in]、[DFX_OUT][dfx-out]。
- 执行器：[CREATE_EXECUTOR][create-executor]、[AllocTensor][alloc-tensor]、[ConvertToTensor][convert-tensor]、[GetWorkspaceSize][workspace-size]、[ReleaseTo][release-to]、[CommonOpExecutorRun][executor-run]、[AbandonCache][abandon-cache]。
- Kernel：[GET_TILING_DATA_WITH_STRUCT 与 REGISTER_TILING_DEFAULT][kernel-tiling]。

[msopgen]: https://www.hiascend.com/doc_center/source/en/CANNCommunityEdition/850/devaids/optool/atlasopdev_16_0018.html
[deploy]: https://www.hiascend.com/doc_center/source/zh/canncommercial/850/opdevg/Ascendcopdevg/atlas_ascendc_10_0069.html
[single-op]: https://www.hiascend.com/document/detail/zh/CANNCommunityEdition/850alpha002/opdevg/Ascendcopdevg/atlas_ascendc_10_0070.html
[op-type]: https://www.hiascend.com/document/detail/zh/CANNCommunityEdition/850alpha002/API/aolapi/atlasascendc_api_07_1062.html
[l0-dfx]: https://www.hiascend.com/document/detail/zh/CANNCommunityEdition/850alpha002/API/aolapi/atlasascendc_api_07_1051.html
[infer-shape]: https://www.hiascend.com/document/detail/zh/CANNCommunityEdition/850alpha002/API/aolapi/atlasascendc_api_07_1050.html
[op-input]: https://www.hiascend.com/document/detail/zh/CANNCommunityEdition/850alpha002/API/aolapi/atlasascendc_api_07_1057.html
[op-output]: https://www.hiascend.com/document/detail/zh/CANNCommunityEdition/850alpha002/API/aolapi/atlasascendc_api_07_1059.html
[op-attr]: https://www.hiascend.com/document/detail/zh/CANNCommunityEdition/850alpha002/API/aolapi/atlasascendc_api_07_1054.html
[launcher]: https://www.hiascend.com/document/detail/zh/CANNCommunityEdition/850alpha002/API/aolapi/atlasascendc_api_07_1045.html
[create-executor]: https://www.hiascend.com/document/detail/zh/CANNCommunityEdition/850alpha002/API/aolapi/atlasascendc_api_07_1047.html
[dfx-in]: https://www.hiascend.com/document/detail/zh/CANNCommunityEdition/850alpha002/API/aolapi/atlasascendc_api_07_1048.html
[dfx-out]: https://www.hiascend.com/document/detail/zh/CANNCommunityEdition/850alpha002/API/aolapi/atlasascendc_api_07_1049.html
[l2-phase1]: https://www.hiascend.com/document/detail/zh/CANNCommunityEdition/850alpha002/API/aolapi/atlasascendc_api_07_1052.html
[l2-phase2]: https://www.hiascend.com/document/detail/zh/CANNCommunityEdition/850alpha002/API/aolapi/atlasascendc_api_07_1053.html
[alloc-tensor]: https://www.hiascend.com/document/detail/zh/CANNCommunityEdition/850alpha002/API/aolapi/atlasascendc_api_07_1120.html
[convert-tensor]: https://www.hiascend.com/document/detail/zh/CANNCommunityEdition/850alpha002/API/aolapi/atlasascendc_api_07_1128.html
[executor-run]: https://www.hiascend.com/document/detail/zh/CANNCommunityEdition/850alpha002/API/aolapi/atlasascendc_api_07_1129.html
[release-to]: https://www.hiascend.com/document/detail/zh/CANNCommunityEdition/850alpha002/API/aolapi/atlasascendc_api_07_1130.html
[workspace-size]: https://www.hiascend.com/document/detail/zh/CANNCommunityEdition/850alpha002/API/aolapi/atlasascendc_api_07_1131.html
[abandon-cache]: https://www.hiascend.com/document/detail/zh/CANNCommunityEdition/850alpha002/API/aolapi/atlasascendc_api_07_1132.html
[kernel-tiling]: https://www.hiascend.com/document/detail/zh/CANNCommunityEdition/82RC1/API/ascendcopapi/atlasascendc_api_07_0215.html
[op-definition]: https://www.hiascend.com/document/detail/zh/CANNCommunityEdition/850/opdevg/Ascendcopdevg/atlas_ascendc_10_0062.html
[tiling-phase]: https://www.hiascend.com/document/detail/en/CANNCommunityEdition/910/API/aolapi/context/ops-transformer/aclnnMlaProlog.md
[executor-lifetime]: https://www.hiascend.com/document/detail/zh/canncommercial/81RC1/apiref/aolapi/operatorlist_00021.html
