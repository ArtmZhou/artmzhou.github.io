---
title: "RAG SemanticChunker"
date: 2026-05-11T19:49:07+08:00
draft: false
tags: [RAG]
categories: []
summary: "语义分块理解"
---



# SemanticChunker 语义分块原理解析

> 本文档记录了关于 `code/C2/04_semantic_chunker.py` 中语义分块的完整讨论过程。

---

## 讨论背景

在 RAG 学习项目中，用户注意到 `04_semantic_chunker.py` 使用 embedding 模型来进行文本分块，提出了一个疑问：

> *"RAG 系统本身就是先分块，再使用 embedding 存储到向量数据库或查询。这里提前用 embedding 分块，是不是多此一举？"*

---

## 讨论过程

### 第一轮：语义分块 vs 传统分块的定位差异

**用户的困惑：** 语义分块用了 embedding，后续检索还要用 embedding，感觉是重复工作。

**解答：** 这是两个阶段，目的不同：

- **传统分块**（RecursiveCharacterTextSplitter）→ 按字符数硬切，目的是把大文档切成 LLM 能处理的片段
- **语义分块**（SemanticChunker）→ 用 embedding 检测语义变化点，目的是在语义边界处切分，保证 chunk 的语义完整性

两个阶段各司其职：分块阶段用 embedding 做质量控制（保证切得准），检索阶段用 embedding 做语义匹配（保证查得准）。

### 第二轮：语义分块是否做了"两次分块"？

**用户的进一步质疑：** 语义分块之前是否还需要先用其他方式分块？如果做了两次分块再 embedding，会影响效率。

**解答：** 通过阅读 SemanticChunker 源码，澄清了其内部流程：

```
原始文本
  │
  ├─ ① 正则拆句（纯字符串操作，无 embedding）
  ├─ ② 对每句话构建 3 句滑动窗口上下文
  ├─ ③ 对所有滑动窗口做一次 batch embedding
  ├─ ④ 计算相邻窗口的余弦距离
  └─ ⑤ 在语义距离突变的位置合并句子 → 得到最终 chunks
```

**关键澄清：**
- 第一步拆句是正则匹配（re.split），**不是分块**，没有 embedding
- embedding 只做了一次 batch 调用，用于"判断在哪里切"，不是"先分一次块再 embedding"
- 切完后的 chunks 入库时还需要一次 embedding，这是 RAG 流程本身需要的

**开销对比：**

| 方式            | Embedding 次数                                |
| --------------- | --------------------------------------------- |
| 传统分块 → 入库 | N（N = chunk 数）                             |
| 语义分块 → 入库 | M（判断断点）+ N（入库）≈ 总句子数 + chunk 数 |

语义分块确实多了 M 次 embedding 的开销（一次 batch 调用），换来的是 chunk 语义完整性的保证。

### 第三轮：合并视角的理解

**用户提出的理解：** *"语义分块是不是在已切分的句子上做相似度合并，合并成对应的待 embedding 的 chunk？"*

**确认：** 这个理解完全正确。语义分块的本质就是 **"先拆散，再合并"**：

1. 先用正则把文档拆成句子
2. 计算相邻句子的语义距离
3. 把语义相近的连续句子合并成一个 chunk

"在断点处切分"和"把断点之间的句子合并"是一回事，但**"合并"视角更直观**。

---

## 核心概念提炼

### 什么是语义分块？

语义分块（Semantic Chunking）是一种在文本分块过程中引入语义信息的分块策略。它不依赖固定的字符数或分隔符，而是通过分析文本中句子级别的语义变化来确定分块边界。

### 与 RAG 流程的关系

```
语义分块流程:
文本 → 拆句 → 计算句子间语义距离 → 合并语义相近的句子(得到chunks) → embedding入库 → 检索

传统分块流程:
文本 → 按字符数硬切(得到chunks) → embedding入库 → 检索
```

两者的区别仅在"如何得到 chunks"这一步，后续的 embedding 入库和检索流程完全一致。

### 已知局限

- **无 chunk 大小上限**：语义连续的段落可能合并成一个很长的 chunk
- **依赖标点拆句**：默认按 `[.?!]` 切句，中文需要调整
- **额外开销**：多了一次句子级 embedding（batch 调用）

### 实践建议：混合策略

```python
# 先用语义分块保证语义完整性
semantic_chunks = semantic_splitter.split_documents(docs)

# 对超长 chunk 用传统分块兜底
final_chunks = []
for chunk in semantic_chunks:
    if len(chunk.page_content) > MAX_CHUNK_SIZE:
        final_chunks.extend(recursive_splitter.split_documents([chunk]))
    else:
        final_chunks.append(chunk)
```

---

## 参考脚本

`code/C2/04_semantic_chunker.py` — 使用 SemanticChunker 进行语义分块的示例，包含四种断点阈值策略：percentile（默认）、standard_deviation、interquartile、gradient。



## 项目来源
[https://github.com/datawhalechina/all-in-rag.git](https://github.com/datawhalechina/all-in-rag.git)

