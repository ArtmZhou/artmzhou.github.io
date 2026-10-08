---
title: "Ascend C 流水同步：读懂 MTE2、Vector 与 MTE3 的 SetFlag / WaitFlag"
date: 2026-10-08T16:00:00+08:00
draft: false
tags: ["Ascend C", "流水同步", "SetFlag", "WaitFlag"]
categories: ["Ascend C 算子开发"]
summary: "从一张三流水手绘图出发，区分数据就绪与缓冲复用两类依赖，理解 MTE2_V、V_MTE3、V_MTE2 和 MTE3_V 的方向与作用。"
showtoc: true
tocopen: true
---

一个向量算子经常可以拆成三步：搬入数据、执行计算、搬出结果。代码中这三步依次写下，并不足以说明不同硬件流水之间的数据依赖已经得到正确处理。

2026 年 9 月 24 日的这张手绘图，把 MTE2、Vector 和 MTE3 三条流水，以及它们之间的事件同步画在了一起。读图时需要同时关注两件事：本轮的数据是否就绪，以及下一轮能否复用同一块缓冲。

## 原始手绘图

[![MTE2、Vector 与 MTE3 流水及 SetFlag、WaitFlag 关系原图](/images/ascend-c/pipeline-sync.svg)](/images/ascend-c/pipeline-sync.svg)

[打开原图放大查看（SVG）](/images/ascend-c/pipeline-sync.svg) · [PNG 原图](/images/ascend-c/pipeline-sync.png) · [可编辑 Excalidraw 文件](/images/ascend-c/pipeline-sync.excalidraw) · [原始 Obsidian 文档](/images/ascend-c/pipeline-sync.excalidraw.md)

原图保留了原来的节点与箭头。它是依赖关系草图，没有完整展开循环，也没有画出所有事件的配对端点，不能直接当成一份可执行时序。

## 1. 三条流水各自负责什么

在本文讨论的 GM 与 UB 之间的向量计算场景中，可以按下面的分工读图：

| 流水 | 图中的工作 | 数据流向 |
| --- | --- | --- |
| MTE2 | 第一个 DataCopy | 把输入从 GM 搬入片上 UB |
| Vector（V） | Calculate | 读取本地输入，计算本地输出 |
| MTE3 | 第二个 DataCopy | 把输出从 UB 搬回 GM |

三条流水具备独立执行的能力，因此需要约束有依赖的操作。核内跨流水的同步使用 `SetFlag / WaitFlag`；事件名中的前半部分是源流水，后半部分是目标流水。例如 `MTE2_V` 表示 Vector 等待 MTE2。[SetFlag / WaitFlag 官方说明](https://www.hiascend.com/doc_center/source/en/canncommercial/800/apiref/ascendcopapi/atlasascendc_api_07_0270.html)

## 2. 正向依赖：本轮数据准备好了吗

图中央的第一条连接是 `MTE2_V`。

MTE2 把输入搬入 UB 后，通过 SetFlag 表示对应工作完成。Vector 在读取这份输入之前执行匹配的 WaitFlag，满足条件后才继续计算。它要保护的是“计算读到的确实是本轮输入”。

第二条连接是 `V_MTE3`。Vector 计算完本地输出后发出通知，MTE3 在搬出该输出前等待。它保护的是“搬出的确实是已经完成计算的结果”。

```text
输入搬入完成 ── MTE2_V ──> 允许 Vector 读取输入
输出计算完成 ── V_MTE3 ──> 允许 MTE3 读取输出
```

只看一轮计算，图中间的这两条依赖已经覆盖了从输入到输出的主要顺序。

## 3. 反向依赖：旧缓冲可以重新写入了吗

图顶部的 `V_MTE2` 和底部的 `MTE3_V`，需要放到缓冲复用的上下文里理解。这里假设输入和输出使用不同的本地缓冲。

当下一轮 MTE2 想覆盖同一个输入槽位时，必须确认上一轮 Vector 已经读完这份输入。于是需要 **Vector → MTE2** 的通知，即 `V_MTE2`。

同样，当下一轮 Vector 想覆盖同一个输出槽位时，必须确认上一轮 MTE3 已经把旧结果读走。于是需要 **MTE3 → Vector** 的通知，即 `MTE3_V`。

| 事件 | 谁等待谁 | 保护的条件 |
| --- | --- | --- |
| MTE2_V | V 等待 MTE2 | 输入已经搬入 |
| V_MTE3 | MTE3 等待 V | 输出已经算好 |
| V_MTE2 | MTE2 等待 V | 旧输入已经读完，可以覆盖 |
| MTE3_V | V 等待 MTE3 | 旧输出已经搬走，可以覆盖 |

前两项保证数据就绪，后两项保证缓冲可以复用。这里的“上一轮”准确地说，是**上一次使用同一槽位的迭代**。如果有两个槽位交替使用，它不一定是紧邻的上一轮。

## 4. 把一张局部草图补成循环思路

下面只是依赖伪代码，不包含事件分配、槽位索引和完整 API 参数：

```text
复用输入槽位之前：等待该槽位对应的 V_MTE2
MTE2：搬入本轮输入
MTE2：通知 MTE2_V

V：等待 MTE2_V
复用输出槽位之前：等待该槽位对应的 MTE3_V
V：计算本轮输出
V：通知 V_MTE2，允许之后覆盖旧输入
V：通知 V_MTE3，允许搬出本轮输出

MTE3：等待 V_MTE3
MTE3：搬出本轮输出
MTE3：通知 MTE3_V，允许之后覆盖旧输出
```

首次使用一个空闲槽位时，并不存在“上次使用完成”的事件。循环实现必须处理启动阶段，例如区分首次使用与后续复用，不能从第一轮就无条件等待尚未产生的通知。结束阶段也要完成必要的等待与事件收尾。

原图顶部画出了 `V_MTE2` 的等待侧，却没有展开对应的生产侧；底部画出了 `MTE3_V` 的 SetFlag，却没有继续画到下一次 Vector 覆盖输出前的 WaitFlag。理解这个省略，才能把图中的箭头接回循环。

## 5. SetFlag 与 WaitFlag 怎样配对

一对同步需要匹配相同的事件方向和 event ID。SetFlag 表示源流水在满足前置完成条件后发出通知；WaitFlag 在目标流水上等待该通知。它们约束的是指定流水之间的依赖，并不等于所有流水都停下来。

例如，搬入输入与计算读取之间的最小同步片段可以写成：

```cpp
// 示意片段：放在输入 DataCopy 之后、依赖它的 Vector 操作之前。
// 完整 Kernel 还需要负责张量、数据搬运和缓冲生命周期。
int32_t eventId = static_cast<int32_t>(
    AscendC::GetTPipePtr()->FetchEventID(AscendC::HardEvent::MTE2_V));
AscendC::SetFlag<AscendC::HardEvent::MTE2_V>(eventId);
AscendC::WaitFlag<AscendC::HardEvent::MTE2_V>(eventId);
```

事件 ID 的申请、使用与释放应遵循所用 CANN 版本的接口规范，避免与框架管理的事件冲突。这段代码只演示一条正向依赖，不是完整的循环同步实现。[接口约束与示例](https://www.hiascend.com/doc_center/source/en/canncommercial/800/apiref/ascendcopapi/atlasascendc_api_07_0270.html)

## 6. 双缓冲不会让依赖消失

双缓冲让两个槽位交替承担工作。例如一个槽位供当前计算读取，另一个槽位供下一份输入搬入；这为流水重叠提供了空间。

但每个槽位仍需满足自己的生命周期：读之前等待写完成，再写之前等待旧读取完成。只有跟踪清楚“哪个事件对应哪个槽位”，才能避免把尚未消费的数据覆盖掉。

使用 TPipe / TQue 编程范式时，框架会帮助管理常见的同步和缓冲流转。应先弄清现有队列操作已经保证了哪些依赖，再判断是否需要手工补充。官方开发指南也建议优先使用编程模型，而将手工同步用于确有需要的场景。[Ascend C 开发指南中的同步机制](https://www.hiascend.com/doc_center/source/zh/CANNCommunityEdition/800alpha002/devguide/opdevg/ascendcopdevg/CANN%E7%A4%BE%E5%8C%BA%E7%89%88%208.0.0.alpha002%20Ascend%20C%E8%87%AA%E5%AE%9A%E4%B9%89%E7%AE%97%E5%AD%90%E5%BC%80%E5%8F%91%E6%8C%87%E5%8D%97%2001.pdf)

读同步图时，先找出每块缓冲的写入者和读取者，再把“数据就绪”与“允许覆盖”两类箭头分别接上。这比只背 `MTE2_V` 或 `V_MTE3` 的名称，更容易发现循环中的遗漏。
