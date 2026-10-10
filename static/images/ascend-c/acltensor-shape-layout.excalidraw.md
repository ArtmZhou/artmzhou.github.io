---

excalidraw-plugin: parsed
tags: [excalidraw]

---
==⚠  Switch to EXCALIDRAW VIEW in the MORE OPTIONS menu of this document. ⚠== You can decompress Drawing data with the command palette: 'Decompress current Excalidraw file'. For more info check in plugin settings under 'Saving'
# storeageshape && storeageformat
ND:
```txt
逻辑 [K,N]         物理 [K,N]
┌────────┐        ┌────────┐
│  K×N   │  ==    │  K×N   │     StorageShape = [K, N]
└────────┘        └────────┘     StorageFormat  = ND

```

NZ 的分形块是 `16 × C0`：

- 固定的是 16（分形高度）；
- `C0 = 32 字节 / 元素字节数`，随 dtype 变：

| dtype       | 元素字节 | C0  | 块大小   |
| ----------- | ---- | --- | ----- |
| int8        | 1    | 32  | 16×32 |
| fp16 / bf16 | 2    | 16  | 16×16 |
| fp32        | 4    | 8   | 16×8  |
```txt
StorageShape = [ D1 // C0 , D0 // 16 , 16 , C0 ]
                 └─第二维块数┘└─第一维块数┘└块内D0┘└块内D1┘
```
示例：
```txt
逻辑矩阵 [K,N]                        物理存储（NZ 分块）
   ┌───────────────┐                  ┌─────┐┌─────┐┌─────┐
K  │               │                  │blk00││blk01││blk02│   每个小块 = 16×32 (假设INT8)
↑  │    K × N      │  ──切块重排──→    ├─────┼─────┼─────┤
   │               │                  │blk10││blk11││blk12│
   └───────────────┘                  └─────┘└─────┘└─────┘
    ───────────→ N
                                       非转置
                                       StorageShape  = [n/32, k/16, 16, 32]  (4 维!)
                                       StorageFormat = FORMAT_FRACTAL_NZ
                                       转置
                                       StorageShape  = [k/32, n/16, 16, 32]  (4 维!)
                                       StorageFormat = FORMAT_FRACTAL_NZ

```
# originalshape

```txt
OriginalShape = 未分块前的原始逻辑形状，例如 [K, N] 或 [N, K]
                ↓
             告诉 kernel / tiling：这块分块内存，逻辑上代表哪个矩阵、什么方向
             
一般未转置 originalshape=viewshape
转置情况下 originalshape=swapDim(viewshape)
```

# Excalidraw Data

## Text Elements
        ┌─────────────────────────────────────────────┐
        │ ViewShape     逻辑形状（算子看到的维度）      │
        │ ViewStrides   逻辑坐标 → 内存偏移 的步长       │   ── 怎么看
        ├─────────────────────────────────────────────┤
        │ StorageFormat 物理格式（ND / NZ / ...）        │
        │ StorageShape  物理排布形状                     │   ── 怎么摆
        ├─────────────────────────────────────────────┤
        │ OriginalShape 未分块前的原始逻辑形状           │   ── 代表的哪个矩阵
        └─────────────────────────────────────────────┘
 ^V8WjhVCJ

acltensor的一些基本概念
这些将在算子开发中非常重要，因为不同的soc对于输入的tensor布局是有要求的 ^VETYWDxf

viewshape && viewstrides理解 ^JEKwgsG8

storeageshape && storeageformat ^W2SSPDRj

originalshape
 ^VVlt6jBh

## Element Links
4CWk3NkX: [[Excalidraw/Drawing 2026-10-09 09.41.16.excalidraw.md#viewshape && viewstrides]]

FdzcaWLp: [[Excalidraw/Drawing 2026-10-10 09.43.22.excalidraw.md#storeageshape && storeageformat]]

VswuHU0t: [[Excalidraw/Drawing 2026-10-10 09.43.22.excalidraw.md#originalshape]]

%%
## Drawing
```compressed-json
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

hgkAA===
```
%%