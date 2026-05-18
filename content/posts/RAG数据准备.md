---
title: "[2]RAG数据准备"
date: 2026-05-18T22:08:16+08:00
draft: false
tags: [RAG]
categories: []
summary: ""
---
# 1. 数据加载
## 功能
RAG 系统中，**数据加载**是整个系统开始的第一步。文档加载器负责将各种格式的非结构化文档（如PDF、Word、Markdown、HTML等）转换为程序可以处理的结构化数据。数据加载的质量会直接影响后续的索引构建、检索效果和最终的生成质量。
 **数据加载**
 1. 解析不同格式的原始文档
 2. 提取文档来源、页码等关键信息作为文本的元数据
 3. 将文本与元数据整合，为后续的分块、向量化做准备
## 当前主流RAG文档加载器

| 工具名称                | 特点                      | 适用场景           | 性能表现                |
| ------------------- | ----------------------- | -------------- | ------------------- |
| **PyMuPDF4LLM**     | PDF→Markdown转换，OCR+表格识别 | 科研文献、技术手册      | 开源免费，GPU加速          |
| **TextLoader**      | 基础文本文件加载                | 纯文本处理          | 轻量高效                |
| **DirectoryLoader** | 批量目录文件处理                | 混合格式文档库        | 支持多格式扩展             |
| **Unstructured**    | 多格式文档解析                 | PDF、Word、HTML等 | 统一接口，智能解析           |
| **FireCrawlLoader** | 网页内容抓取                  | 在线文档、新闻        | 实时内容获取              |
| **LlamaParse**      | 深度PDF结构解析               | 法律合同、学术论文      | 解析精度高，商业API         |
| **Docling**         | 模块化企业级解析                | 企业合同、报告        | IBM生态兼容             |
| **Marker**          | PDF→Markdown，GPU加速      | 科研文献、书籍        | 专注PDF转换             |
| **MinerU**          | 多模态集成解析                 | 学术文献、财务报表      | 集成LayoutLMv3+YOLOv8 |
# 2. 文本分块
## why 为什么需要进行文本分块

1. embedding模型对输入有长度要求。它负责将文本向量化，对于超过其输入限制的文本将被截断，导致向量化的过程中丢失信息，生成的向量也无法表征原本的信息。
2. 文本生成模型（LLM）同样具有上下文窗口限制（这个比embedding模型的限制大的多）。但llm的上下文需要放置各类信息，如系统prompt，用户输入，用户提示等等；如果单个chunk过大，会导致只能放置少数信息，会限制llm的输出质量。
3. 嵌入模型生成的向量是有维度限制的，有限的维度所能表示的语义也是有限的，过大的文本会导致生成的向量承载的语义被稀释。
4. 文本块不能过大，有研究表明，当LLM处理非常长的、充满大量信息的上下文时，它倾向于更好地记住开头和结尾的信息，而忽略中间部分的内容。
5. 文本需要聚焦主题，如果一个块包含太多不相关的主题，它的语义就会被稀释，导致在检索时无法被精确匹配。
## how 分块策略
### 1.固定大小分块-`CharacterTextSplitter`
a. **按段落分割**：`CharacterTextSplitter` 采用默认分隔符 `"\n\n"`，使用正则表达式将文本按段落进行分割，通过 `_split_text_with_regex` 函数处理。

b.**智能合并**：调用继承自父类的 `_merge_splits` 方法，将分割后的段落依次合并。该方法会监控累积长度，当超过 `chunk_size` 时形成新块，并通过重叠机制（`chunk_overlap`）保持上下文连续性，同时在必要时发出超长块的警告。

```python
from langchain.text_splitter import CharacterTextSplitter
from langchain_community.document_loaders import TextLoader

loader = TextLoader("../../data/C2/txt/蜂医.txt")
docs = loader.load()

text_splitter = CharacterTextSplitter(
    chunk_size=200,    # 每个块的目标大小为100个字符
    chunk_overlap=10   # 每个块之间重叠10个字符，以缓解语义割裂
)

chunks = text_splitter.split_documents(docs)

print(f"文本被切分为 {len(chunks)} 个块。\n")
print("--- 前5个块内容示例 ---")
for i, chunk in enumerate(chunks[:5]):
    print("=" * 60)
    # chunk 是一个 Document 对象，需要访问它的 .page_content 属性来获取文本
    print(f'块 {i+1} (长度: {len(chunk.page_content)}): "{chunk.page_content}"')
```

这种方法的主要优势在于实现简单、处理速度快且计算开销小。劣势在于可能会在语义边界处切断文本，影响内容的完整性和连贯性。实际的固定大小分块实现（如LangChain的 `CharacterTextSplitter`）通常会结合分隔符来减少这种问题，在段落边界处优先切分，只有在必要时才会强制按大小切断。因此，这种方法在日志分析、数据预处理等场景中仍有其应用价值。

### 2.递归字符分块-`RecursiveCharacterTextSplitter`
基本流程如下：
![递归分块](/images/deepseek_mermaid_20260518_1f90d3.png)

递归字符分块的原理是采用一组有层次结构的分隔符（如段落、句子、单词）进行递归分割，旨在有效平衡语义完整性与块大小控制。在 `RecursiveCharacterTextSplitter` 的实现中，该分块器首先尝试使用最高优先级的分隔符（如段落标记）来切分文本。如果切分后的块仍然过大，会继续对这个大块应用下一优先级分隔符（如句号），如此循环往复，直到块满足大小限制。这种分层处理的机制，能够在尽可能保持高级语义结构完整性的同时，有效控制块大小。
### 3.语义分块-`SemanticChunker`

该分块策略主要是依托embedding模型，将句子按照语义进行合并。有点类似于使用RAG的召回来做合并判断。

`SemanticChunker` 的工作流程可以概括为以下几个步骤：

（1）**句子分割 (Sentence Splitting)**：首先，使用标准的句子分割规则（例如，基于句号、问号、感叹号）将输入文本拆分成一个句子列表。

（2）**上下文感知嵌入 (Context-Aware Embedding)**：这是 `SemanticChunker` 的一个关键设计。该分块器不是对每个句子独立进行嵌入，而是通过 `buffer_size` 参数（默认为1）来捕捉上下文信息。对于列表中的每一个句子，这种方法会将其与前后各 `buffer_size` 个句子组合起来，然后对这个临时的、更长的组合文本进行嵌入。这样，每个句子最终得到的嵌入向量就融入了其上下文的语义。

（3）**计算语义距离 (Distance Calculation)**：计算每对**相邻**句子的嵌入向量之间的余弦距离。这个距离值量化了两个句子之间的语义差异——距离越大，表示语义关联越弱，跳跃越明显。

（4）**识别断点 (Breakpoint Identification)**：`SemanticChunker` 会分析所有计算出的距离值，并根据一个统计方法（默认为 `percentile`）来确定一个动态阈值。例如，它可能会将所有距离中第95百分位的值作为切分阈值。所有距离大于此阈值的点，都被识别为语义上的“断点”。

（5）**合并成块 (Merging into Chunks)**：最后，根据识别出的所有断点位置，将原始的句子序列进行切分，并将每个切分后的部分内的所有句子合并起来，形成一个最终的、语义连贯的文本块。

### 4.文档结构分块
此分块策略针对的是具有明显结构标记的文本，如html，markdown等。

### 5.others
其他的一些开源框架中也有提供相应的分块策略，如`Unstructured`，`LlamaIndex`
