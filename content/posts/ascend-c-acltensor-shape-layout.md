---
title: "Ascend C 张量布局：理解 aclTensor 的 Shape、Stride 与 ND / NZ"
date: 2026-10-10T10:00:00+08:00
draft: false
tags: ["Ascend C", "aclTensor", "ND", "FRACTAL_NZ"]
categories: ["Ascend C 算子开发"]
summary: "结合原始手绘图，从一个 2×3 矩阵的转置视图出发，区分 ViewShape、ViewStrides、StorageShape 与 OriginalShape，再用 INT8 示例理解 NZ 分块、对齐与物理容量。"
showtoc: true
tocopen: true
---

开发 Ascend C 算子时，一个 Tensor 往往带着不止一种 Shape。逻辑矩阵是 `[K, N]`，底层存储却可能是四维；同一块内存，也可以通过不同的 Shape 和 Stride 被读成不同方向的矩阵。

这篇笔记整理自 2026 年 10 月 10 日的手绘图，围绕三个问题展开：**算子怎样看数据，数据在内存里怎样排布，以及格式转换前它代表什么形状。** 原图保留原有标注，正文补充尺寸对齐和转置相关的适用条件。

## 原始手绘图

[![aclTensor 的 ViewShape、ViewStrides、StorageShape、StorageFormat 与 OriginalShape 原始手绘图](/images/ascend-c/acltensor-shape-layout.png)](/images/ascend-c/acltensor-shape-layout.png)

[打开完整原图（PNG）](/images/ascend-c/acltensor-shape-layout.png) · [Obsidian 原稿与引用笔记（ZIP）](/images/ascend-c/acltensor-shape-layout-sources.zip) · [原始 Markdown](/images/ascend-c/acltensor-shape-layout.excalidraw.md) · [Excalidraw 场景文件](/images/ascend-c/acltensor-shape-layout.excalidraw)

图中嵌入了三段 Markdown 笔记，因此使用 Obsidian 的完整截图导出，保留嵌入内容。需要继续编辑时，建议下载 ZIP，将其中的 `Excalidraw` 文件夹放入启用了 Excalidraw 插件的 Obsidian 仓库；单独打开场景文件不会自动带上这些引用笔记。

## 1. 先把几种描述分开

| 属性 | 关注的问题 | 阅读时要注意什么 |
| --- | --- | --- |
| `ViewShape` | 当前视图的逻辑维度是什么 | 描述算子所见的张量形状 |
| `ViewStrides` | 沿某一维前进一步，偏移多少元素 | 普通 strided 视图需结合 Shape、offset 理解 |
| `StorageFormat` | 底层采用哪种存储格式 | 例如 ND、FRACTAL_NZ |
| `StorageShape` | 底层存储的形状是什么 | 可能包含分块维度与对齐填充 |
| `OriginalShape` | 格式转换前的逻辑形状是什么 | 不能仅凭当前视图机械地交换维度推导 |

这几项共同描述一个张量。看到两个 Tensor 的 `ViewShape` 相同，还不足以判断它们能否交给同一段搬运代码：Stride、物理格式和对齐条件也可能不同。

## 2. ViewShape 与 ViewStrides：同一块内存的两种读法

先看一个普通 ND 张量，假设底层内存依次存放六个元素，且起始 offset 为 0：

```text
内存：a0  a1  a2  a3  a4  a5

ViewShape   = [2, 3]
ViewStrides = [3, 1]

视图：a0  a1  a2
      a3  a4  a5
```

第一维前进一步跨过三个元素，第二维前进一步跨过一个元素。因此逻辑坐标 `(i, j)` 对应：

```text
element_offset(i, j) = i × 3 + j × 1
```

如果只构造一个转置视图，交换 Shape 和 Stride 对应的维度：

```text
ViewShape   = [3, 2]
ViewStrides = [1, 3]

视图：a0  a3
      a1  a4
      a2  a5

element_offset(i, j) = i × 1 + j × 3
```

此时底层六个元素的顺序没有改变。例如新视图的 `(1, 0)` 仍然访问 `a1`，只是它在逻辑矩阵中的位置变了。官方 `aclCreateTensor` 示例也展示了复用相同数据与 `storageDims`、改变 `viewDims` 和 `stride` 的转置视图。[aclCreateTensor 接口与示例](https://www.hiascend.com/document/detail/en/canncommercial/800/apiref/aolapi/operatorlist_00019.html)

对于这类普通 strided 视图，可以推广为：

```text
element_offset = offset + Σ(index[d] × stride[d])
byte_offset    = element_offset × sizeof(dtype)
```

这里的 Stride 和 offset 以**元素**为单位。该式帮助理解普通视图的访问，不能直接当作 NZ 分块内存的物理寻址公式。具体算子是否接受非连续视图，也要查看它的接口约束。

## 3. ND：逻辑形状和存储形状何时相同

原图中的 ND 示意对应一个简单场景：新建连续矩阵，没有额外视图变换。

```text
ViewShape     = [K, N]
ViewStrides   = [N, 1]
StorageShape  = [K, N]
StorageFormat = ND
```

在这个场景中，两种 Shape 一致。但 **ND 本身不保证 `ViewShape == StorageShape`**。上一节的转置视图仍可使用原来的存储形状 `[2, 3]`，同时以 `[3, 2]` 的逻辑形状和 `[1, 3]` 的步长访问数据。

排查问题时，应把 Shape、Stride、offset 和存储信息一起看。只检查维度乘积相等，无法发现矩阵方向或访问步长出错。

## 4. NZ：逻辑二维矩阵为什么变成四维存储

FRACTAL_NZ 将矩阵最低两维补齐、拆成小块，再按照规定顺序排列。以下沿用原图的 `16 × C0` 分形约定，逻辑矩阵为 `[K, N]`：

```text
K1 = ceil_div(K, 16)
N1 = ceil_div(N, C0)

StorageShape = [N1, K1, 16, C0]

ceil_div(x, y) = (x + y - 1) // y    # x、y 为正整数
```

前两维描述有多少块，后两维描述块内大小。若有 batch 等前置维度，这些维度保留在前面。官方数据排布说明给出的转换顺序也是“填充 → 拆分 → 维度重排”。[数据排布格式：FRACTAL_NZ](https://www.hiascend.com/doc_center/source/zh/CANNCommunityEdition/850/opdevg/Ascendcopdevg/atlas_ascendc_10_0099.html)

原图写的是整除形式，**仅在两个方向已经对齐时才能直接使用**。未对齐的矩阵需要向上取整，不能丢掉尾块。

### C0 的大小要连同存储位置一起看

在上述常见 L1 NZ 分形约定下，`C0 = 32 字节 / sizeof(dtype)`：

| 数据类型 | 每元素字节数 | C0 | 分形大小 |
| --- | --- | --- | --- |
| INT8 | 1 | 32 | 16 × 32 |
| FP16 / BF16 | 2 | 16 | 16 × 16 |
| FP32 | 4 | 8 | 16 × 8 |

这张表有明确的场景边界。官方说明中，L0C 用于保存矩阵乘结果的 NZ 分形通常为 `16 × 16`；L1 中的 NZ 分形则采用上面的规则。因此不能看到 FP32，就把任何位置的 NZ 都解释成 `16 × 8`。具体设备、算子与格式转换接口的支持范围仍应以对应版本文档为准。[L0C 与 L1 的 NZ 分形说明](https://www.hiascend.com/doc_center/source/zh/CANNCommunityEdition/850/opdevg/Ascendcopdevg/atlas_ascendc_10_0099.html)

### 一个带尾块的 INT8 例子

假设要将逻辑形状 `[30, 50]` 按 `16 × 32` 分形保存：

```text
K1 = ceil_div(30, 16) = 2
N1 = ceil_div(50, 32) = 2

StorageShape = [2, 2, 16, 32]
有效元素数   = 30 × 50 = 1500
物理存储容量 = 2 × 2 × 16 × 32 = 2048 个元素
```

因为 INT8 每元素占 1 字节，这个存储形状对应 2048 字节。Padding 补足了分形边界，逻辑矩阵仍是 `[30, 50]`。如果分配内存时只计算 `30 × 50`，就容纳不了这个 NZ 布局；如果计算有效输出时把 padding 也算进去，又会扩大真正的计算范围。

## 5. OriginalShape：保留格式转换前的逻辑形状

`OriginalShape` 记录 Tensor 经过 transdata 节点之前的原始逻辑形状。官方将它解释为张量形状的数学描述。[GetOriginalShape](https://www.hiascend.com/doc_center/source/en/canncommercial/800/apiref/ascendcopapi/atlasascendc_api_07_1070.html)

例如，直接把一个 `[K, N]` 矩阵转换为上一节的 NZ 格式，可以同时理解两组信息：

```text
OriginalShape = [K, N]
StorageShape  = [ceil_div(N, C0), ceil_div(K, 16), 16, C0]
```

前者保留有效的逻辑矩阵尺寸，后者描述分块后的存储。Padding 与分形维度不会把原来的二维矩阵变成一个具有四个业务维度的矩阵。

原图中“转置时 `OriginalShape = swapDim(ViewShape)`”应当放回具体的张量构造流程理解，不能作为所有张量的赋值规则。仅知道发生过“转置”，还不足以推导所有 Shape 字段。

## 6. 遇到“转置”，先确认是哪一种操作

| 操作 | 数据层面发生什么 | 应怎样理解 |
| --- | --- | --- |
| 构造转置视图 | 可以复用同一块内存 | Shape 与 Stride 一起改变，访问方式改变 |
| 真正生成转置后的数据 | 元素被重新排布到输出存储 | 需要按照目标布局生成相应的数据 |
| 设置 Matmul 的 transpose 属性 | 指定乘法中的逻辑矩阵方向 | 是否伴随内部转换取决于具体实现 |

如果先把逻辑矩阵 `[K, N]` 真正转置为 `[N, K]`，再按相同的 INT8 NZ 规则编码，那么新存储形状为：

```text
[ceil_div(K, 32), ceil_div(N, 16), 16, 32]
```

这个式子解释了原图“转置”一栏的一个适用场景。它并不意味着可以直接交换已有 NZ 张量的几个维度，就得到正确的转置数据。格式标签和 Shape 必须与 buffer 中实际排列的元素一致。

## 7. 写算子前，把这些信息对齐

沿着 Host 构造 Tensor、Tiling 计算、Kernel 搬运这条路径，可以依次检查：

1. **逻辑尺寸与矩阵方向**：真正的 M、N、K 是多少，转置属性如何解释输入。
2. **视图信息**：`ViewShape`、`ViewStrides`、offset 是否一致，接口是否支持该视图。
3. **物理布局**：buffer 是 ND 还是 NZ，分形大小与 dtype、存储位置是否匹配。
4. **容量与尾块**：分配按物理存储容量计算，有效计算范围按逻辑尺寸控制。
5. **转换过程**：哪一步改变视图，哪一步重排数据，`OriginalShape` 记录的是哪次格式转换之前的形状。

弄清这些信息后，再读 Tiling 参数和 GM、L1、L0 之间的搬运代码，就更容易判断一段代码处理的是有效矩阵、对齐后的存储，还是其中一个分形块。相关的分层计算过程可接着阅读 [Ascend C Matmul 分层计算：从多核划分到 GM、L1 与 L0 搬运](/posts/ascend-c-matmul-memory-hierarchy/)。
