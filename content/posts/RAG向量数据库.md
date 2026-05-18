---
title: "[3]RAG向量数据库"
date: 2026-05-18T22:10:57+08:00
draft: true
tags: [RAG]
categories: []
summary: ""
---
# 1. 作用
检索嵌入模型通过转化文本、图像等非结构化数据形成高维向量，向量数据库用来存储、检索这些向量。
向量数据库的核心价值在于其高效处理海量高维向量的能力。其主要功能可以概括为以下几点：
- **高效的相似性搜索**：这是向量数据库最重要的功能。它利用专门的索引技术（如 HNSW, IVF），能够在数十亿级别的向量中实现毫秒级的近似最近邻（ANN）查询，快速找到与给定查询最相似的数据。
- **高维数据存储与管理**：专门为存储高维向量（通常维度成百上千）而优化，支持对向量数据进行增、删、改、查等基本操作。
- **丰富的查询能力**：除了基本的相似性搜索，还支持按标量字段过滤查询（例如，在搜索相似图片的同时，指定`年份 > 2023`）、范围查询和聚类分析等，满足复杂业务需求。
- **可扩展与高可用**：现代向量数据库通常采用分布式架构，具备良好的水平扩展能力和容错性，能够通过增加节点来应对数据量的增长，并确保服务的稳定可靠。
- **数据与模型生态集成**：与主流的 AI 框架（如 LangChain, LlamaIndex）和机器学习工作流无缝集成，简化了从模型训练到向量检索的应用开发流程。 

向量数据库与传统数据库的主要差异如下：

|**维度**|**向量数据库**|**传统数据库 (RDBMS)**|
|:--|:--|:--|
|**核心数据类型**|高维向量 (Embeddings)|结构化数据 (文本、数字、日期)|
|**查询方式**|**相似性搜索** (ANN)|**精确匹配**|
|**索引机制**|HNSW, IVF, LSH 等 ANN 索引|B-Tree, Hash Index|
|**主要应用场景**|AI 应用、RAG、推荐系统、图像/语音识别|业务系统 (ERP, CRM)、金融交易、数据报表|
|**数据规模**|轻松应对千亿级向量|通常在千万到亿级行数据，更大规模需复杂分库分表|
|**性能特点**|高维数据检索性能极高，计算密集型|结构化数据查询快，高维数据查询性能呈指数级下降|
|**一致性**|通常为最终一致性|强一致性 (ACID 事务)|
# 2.常用向量数据库介绍与使用

## 2.1 本地向量数据库 (llamaindex+内置向量存储)
该方式非常适合本地化demo验证。
持久化之后会在本地目录下形成一系列的json文件。

```python
from llama_index.core import VectorStoreIndex, Document, Settings  
from llama_index.embeddings.huggingface import HuggingFaceEmbedding  
  
# 1. 配置全局嵌入模型  
local_model_path = "../../models/bge-small-zh-v1.5"  
Settings.embed_model = HuggingFaceEmbedding(local_model_path)  
  
# 2. 创建示例文档  
texts = [  
    "张三是法外狂徒",  
    "LlamaIndex是一个用于构建和查询私有或领域特定数据的框架。",  
    "它提供了数据连接、索引和查询接口等工具。"  
]  
docs = [Document(text=t) for t in texts]  
  
# 3. 创建索引并持久化到本地  
index = VectorStoreIndex.from_documents(docs)  
persist_path = "./llamaindex_index_store"  
index.storage_context.persist(persist_dir=persist_path)  
print(f"LlamaIndex 索引已保存至: {persist_path}")
```

使用索引：
```python
from llama_index.core import VectorStoreIndex, StorageContext, Settings  
from llama_index.core import load_index_from_storage  
from llama_index.embeddings.huggingface import HuggingFaceEmbedding  
  
# 1. 配置全局嵌入模型（必须与构建索引时一致）  
local_model_path = "../../models/bge-small-zh-v1.5"  
Settings.embed_model = HuggingFaceEmbedding(local_model_path)  
  
# 2. 从本地加载索引  
persist_path = "./llamaindex_index_store"  
storage_context = StorageContext.from_defaults(persist_dir=persist_path)  
index = load_index_from_storage(storage_context)  
  
# 3. 构建检索引擎并执行相似性搜索  
retriever = index.as_retriever(similarity_top_k=2)  
  
query = "LlamaIndex是什么?"  
nodes = retriever.retrieve(query)  
  
print(f"查询: {query}\n")  
for i, node in enumerate(nodes, 1):  
    print(f"结果 {i}:")  
    print(f"  文本: {node.text}")  
    print(f"  相似度分数: {node.score:.4f}")  
    print()
```
## 2.2 本地向量数据库 （langchain+FAISS）
该数据库非常适合本地化项目，适合demo验证以及小型化项目。
它运行之后会在本地目录下形成一个`.faiss`索引文件和一个`.pkl`映射文件。
示例（使用FAISS+langchain）：
```python
from langchain_community.vectorstores import FAISS  
from langchain_huggingface import HuggingFaceEmbeddings  
from langchain_core.documents import Document  
  
# 1. 示例文本和嵌入模型  
texts = [  
    "张三是法外狂徒",  
    "FAISS是一个用于高效相似性搜索和密集向量聚类的库。",  
    "LangChain是一个用于开发由语言模型驱动的应用程序的框架。"  
]  
docs = [Document(page_content=t) for t in texts]  
local_model_path = "../../models/bge-small-zh-v1.5"  
embeddings = HuggingFaceEmbeddings(  
    model_name=local_model_path,  
    model_kwargs={'device': 'cpu'},  
    encode_kwargs={'normalize_embeddings': True}  
)  
  
# 2. 创建向量存储并保存到本地  
vectorstore = FAISS.from_documents(docs, embeddings)  
  
local_faiss_path = "./faiss_index_store"  
vectorstore.save_local(local_faiss_path)  
  
print(f"FAISS index has been saved to {local_faiss_path}")  
  
# 3. 加载索引并执行查询  
# 加载时需指定相同的嵌入模型，并允许反序列化  
loaded_vectorstore = FAISS.load_local(  
    local_faiss_path,  
    embeddings,  
    allow_dangerous_deserialization=True  
)  
  
# 执行相似性搜索  
query = "FAISS是做什么的？"  
results = loaded_vectorstore.similarity_search(query, k=1)  
  
print(f"\n查询: '{query}'")  
print("相似度最高的文档:")  
for doc in results:  
    print(f"- {doc.page_content}")

```

当然llamaindex框架也支持对接FAISS，详情可以去看下他们的文档，这里面不仅仅是FAISS，包含了llamaindex支持对接的所有的向量存储媒介。[llamaindex, using vector stores](https://developers.llamaindex.ai/python/framework/community/integrations/vector_stores/)
langchain同理，可以参考[langchain, select vector stores](https://docs.langchain.com/oss/python/langchain/rag#faiss)

## 2.3 生产级向量数据库 Milvus

### 核心组件介绍
- **Collection (集合)**: 相当于一个**图书馆**，是所有数据的顶层容器。一个 Collection 可以包含多个 Partition，每个 Partition 可以包含多个 Entity。
- **Partition (分区)**: 相当于图书馆里的**不同区域**（如“小说区”、“科技区”），将数据物理隔离，让检索更高效。
- **Schema (模式)**: 相当于图书馆的**图书卡片规则**，定义了每本书（数据）必须登记哪些信息（字段）。
- **Entity (实体)**: 相当于**一本具体的书**，是数据本身。
- **Alias (别名)**: 相当于一个**动态的推荐书单**（如“本周精选”），它可以指向某个具体的 Collection，方便应用层调用，实现数据更新时的无缝切换。
### 主要向量索引类型介绍
- **FLAT (精确查找)**
    - **原理**：暴力搜索（Brute-force Search）。它会计算查询向量与集合中所有向量之间的实际距离，返回最精确的结果。
    - **优点**：100% 的召回率，结果最准确。
    - **缺点**：速度慢，内存占用大，不适合海量数据。
    - **适用场景**：对精度要求极高，且数据规模较小（百万级以内）的场景。
- **IVF 系列 (倒排文件索引)**
    - **原理**：类似于书籍的目录。它首先通过聚类将所有向量分成多个“桶”(`nlist`)，查询时，先找到最相似的几个“桶”，然后只在这几个桶内进行精确搜索。`IVF_FLAT`、`IVF_SQ8`、`IVF_PQ` 是其不同变体，主要区别在于是否对桶内向量进行了压缩（量化）。
    - **优点**：通过缩小搜索范围，极大地提升了检索速度，是性能和效果之间很好的平衡。
    - **缺点**：召回率不是100%，因为相关向量可能被分到了未被搜索的桶中。
    - **适用场景**：通用场景，尤其适合需要高吞吐量的大规模数据集。
- **HNSW (基于图的索引)**
    - **原理**：构建一个多层的邻近图。查询时从最上层的稀疏图开始，快速定位到目标区域，然后在下层的密集图中进行精确搜索。
    - **优点**：检索速度极快，召回率高，尤其擅长处理高维数据和低延迟查询。
    - **缺点**：内存占用非常大，构建索引的时间也较长。
    - **适用场景**：对查询延迟有严格要求（如实时推荐、在线搜索）的场景。
- **DiskANN (基于磁盘的索引)**
    - **原理**：一种为在 SSD 等高速磁盘上运行而优化的图索引。
    - **优点**：支持远超内存容量的海量数据集（十亿级甚至更多），同时保持较低的查询延迟。
    - **缺点**：相比纯内存索引，延迟稍高。
    - **适用场景**：数据规模巨大，无法全部加载到内存的场景。
### 检索类型介绍
- **基础类型检索 (ANN Search)**
	拥有了数据容器 (Collection) 和检索引擎 (Index) 后，最后一步就是从海量数据中高效地检索信息。这是 Milvus 的核心功能之一，**近似最近邻 (Approximate Nearest Neighbor, ANN) 检索**。与需要计算全部数据的暴力检索（Brute-force Search）不同，ANN 检索利用预先构建好的索引，能够极速地从海量数据中找到与查询向量最相似的 Top-K 个结果。这是一种在速度和精度之间取得极致平衡的策略。
- **增强检索**
	- 过滤检索
		根据提供的过滤表达式 (`filter`) 筛选出符合条件的实体，然后仅在这个子集内执行 ANN 检索。这极大地提高了查询的精准度。
	- 范围检索
		范围检索允许定义一个距离（或相似度）的阈值范围。Milvus 会返回所有与查询向量的距离落在这个范围内的实体。
	- 多向量混合检索
		1. 应用针对不同的向量字段（如一个用于文本语义的密集向量，一个用于关键词匹配的稀疏向量，一个用于图像内容的多模态向量）分别发起 ANN 检索请求。
		2. 结果融合 (Rerank)：Milvus 使用一个重排策略（Reranker）将来自不同检索流的结果合并成一个统一的、更高质量的排序列表。常用的策略有 `RRFRanker`（平衡各方结果）和 `WeightedRanker`（可为特定字段结果加权）。
	- 分组检索
		分组检索允许指定一个字段（如 `document_id`）对结果进行分组。Milvus 会在检索后，确保返回的结果中每个组（每个 `document_id`）只出现一次（或指定的次数），且返回的是该组内与查询最相似的那个实体。