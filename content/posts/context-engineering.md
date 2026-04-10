---
title: "上下文工程：AI应用开发的核心技术路线"
date: 2026-04-10T15:00:00+08:00
draft: false
tags: ["AI", "LLM", "Context Engineering", "RAG", "Agent"]
categories: ["技术"]
summary: "深入解析上下文工程的四大技术路线：保存、选择、压缩与隔离，探讨当前业界的实现方式与最佳实践"
---

## 引言

随着大语言模型（LLM）能力的不断提升，如何有效管理和利用上下文（Context）已成为 AI 应用开发的核心挑战。上下文工程（Context Engineering）作为一门新兴技术领域，聚焦于如何高效地处理、存储和传递上下文信息，以最大化 LLM 的性能和实用性。本文将系统性地介绍上下文工程的四大技术路线及其业界实现方式。

## 一、保存上下文（Context Preservation）

### 核心概念

保存上下文的本质是将对话历史、用户偏好、任务状态等信息筛选、总结并持久化，形成 AI 系统的"记忆能力"。这解决了 LLM 无状态特性和有限上下文窗口带来的挑战。

### 技术实现方式

| 实现方式 | 代表产品/技术 | 特点 |
|---------|-------------|------|
| **数据库存储** | PostgreSQL + pgvector, MongoDB | 结构化存储，支持向量检索 |
| **内存数据库** | Redis, Memcached | 高速读写，适合短期记忆 |
| **文件系统** | Markdown, JSON 文件 | 简单直观，易于版本控制 |
| **专用记忆层** | MemGPT, Zep AI | 专为 LLM 设计的记忆管理系统 |

### 业界实践

- **Claude Code**: 使用 `.claude/` 目录存储项目记忆，支持跨会话持久化
- **LangChain Memory**: 提供 ConversationBufferMemory、ConversationSummaryMemory 等多种记忆组件
- **OpenAI Assistants API**: 内置线程管理，自动保存对话历史

## 二、选择上下文（Context Selection）

### 核心概念

由于 LLM 上下文窗口有限，不可能将所有信息都输入模型。上下文选择的目标是从海量信息中筛选出与当前任务最相关的内容。

### 2.1 静态选择（Static Selection）

静态选择采用预定义规则或模板来确定输入内容，不随查询动态变化。

**典型实现：**

- **系统级 Prompt 文件**：
  - Cursor 的 `.cursorrules` 文件
  - Claude Code 的 `CLAUDE.md` 文件
  - GitHub Copilot 的个性化指令

- **结构化模板**：
  ```markdown
  ## 项目背景
  [固定项目信息]

  ## 编码规范
  [团队规范文档]

  ## 用户问题
  [当前查询]
  ```

### 2.2 动态选择（Dynamic Selection）

动态选择根据用户查询实时检索最相关的上下文内容。

**核心技术：RAG（Retrieval-Augmented Generation）**

```
用户查询 → 向量化 → 向量检索 → 相关性排序 → Top-K 选取 → 注入 Prompt
```

**RAG 技术栈对比：**

| 组件 | 开源方案 | 云服务 |
|-----|---------|-------|
| 向量化模型 | BGE, GTE, Jina | OpenAI Embedding, Cohere |
| 向量数据库 | Milvus, Pinecone, Weaviate, Qdrant | Azure AI Search, Amazon Kendra |
| 重排序 | Cross-Encoder, BGE-Reranker | Cohere Rerank |

**进阶技术：**

- **多路召回**：结合向量检索 + 关键词检索 + 图谱检索
- **查询重写**：使用 LLM 优化用户查询，提升检索准确率
- **上下文压缩**：检索后再精炼，只保留最相关片段

## 三、压缩上下文（Context Compression）

### 核心概念

当上下文超过模型限制或成本过高时，需要对信息进行压缩。模型输出和工具执行结果是最需要压缩的内容，因为它们往往体积庞大且包含大量冗余信息。

### 技术实现方式

#### 3.1 Auto-Compact 自动压缩

```
上下文长度 > 阈值 → 触发 LLM 总结 → 生成阶段性摘要 → 替换原始内容
```

**关键参数：**
- 触发阈值：如达到 80% 上下文窗口
- 压缩率：保留核心信息的百分比
- 摘要策略：按主题、时间或重要性分段总结

#### 3.2 选择性丢弃

根据信息时效性和重要性设定保留策略：

| 策略 | 说明 | 适用场景 |
|-----|------|---------|
| **FIFO** | 先进先出，丢弃最早内容 | 流式对话 |
| **重要性评分** | 保留关键决策点，丢弃闲聊 | 任务型对话 |
| **滑动窗口** | 只保留最近 N 轮对话 | 实时性要求高的场景 |

#### 3.3 结构化压缩

- **思维链压缩**：将推理过程总结为结论
- **工具结果压缩**：将 JSON/XML 输出转为自然语言摘要
- **代码片段压缩**：保留 API 签名，去除实现细节

### 业界案例

- **Claude 3 200K 上下文**：支持整本书输入，但仍需智能压缩策略
- **Gemini 1.5 Pro 1M 上下文**：原生长上下文，但成本优化仍需压缩
- **Anthropic 的 Context Caching**：缓存重复上下文，降低成本

## 四、隔离上下文（Context Isolation）

### 核心概念

在多 Agent 系统中，隔离上下文确保不同 Agent 只访问其所需信息，避免信息污染和干扰，提升系统安全性和模块化程度。

### 4.1 Sub-Agent（子代理）模式

```
主 Agent
├── Sub-Agent A（专注任务 X）
├── Sub-Agent B（专注任务 Y）
└── Sub-Agent C（专注任务 Z）
```

**隔离机制：**
- 每个子代理拥有独立的上下文窗口
- 父代理只传递必要信息给子代理
- 子代理结果汇总后返回父代理

**典型应用：**
- **代码审查**：不同子代理分别负责安全性、性能、风格检查
- **数据处理**：并行处理不同数据批次
- **多语言翻译**：每种语言一个子代理

### 4.2 Agent Team（代理团队）模式

更复杂的协作结构，多个专业 Agent 协同工作：

| 角色 | 职责 | 上下文范围 |
|-----|------|-----------|
| **Planner** | 任务分解与规划 | 全局目标 + 可用资源 |
| **Executor** | 执行具体任务 | 当前子任务指令 |
| **Reviewer** | 质量检查与反馈 | 执行结果 + 质量标准 |
| **Memory Keeper** | 管理长期记忆 | 完整历史记录 |

**协作协议：**
- 消息总线：标准化通信格式
- 状态同步：共享关键状态，隔离内部细节
- 权限控制：基于角色的上下文访问限制

### 实现框架

- **AutoGen**: Microsoft 的多 Agent 对话框架
- **CrewAI**: 用于编排角色扮演 Agent 的框架
- **LangGraph**: 构建复杂多 Agent 工作流
- **OpenAI Assistants**: 线程级别的上下文隔离

## 五、技术选型指南

### 场景匹配建议

```
单用户对话应用 → 保存 + 动态选择
企业知识库问答 → 动态选择（RAG）+ 压缩
复杂任务自动化 → 隔离（Sub-Agent）+ 保存
长文档处理 → 压缩 + 动态选择
```

### 关键决策点

1. **何时使用静态选择？**
   - 项目规范、编码风格等固定信息
   - 对响应速度要求高的场景
   - 成本敏感型应用

2. **何时使用动态选择？**
   - 大规模知识库场景
   - 用户问题多样化
   - 信息频繁更新的场景

3. **压缩的权衡**
   - 压缩率 vs 信息保真度
   - 压缩成本 vs 推理成本
   - 延迟敏感度

## 六、未来发展趋势

1. **原生长上下文支持**：Gemini 1.5 Pro 已支持 1M+ token，压缩需求可能降低
2. **智能上下文管理**：LLM 自动决定何时保存、丢弃或压缩
3. **分层记忆架构**：类似人类记忆的工作记忆-短期记忆-长期记忆三层结构
4. **跨模态上下文**：统一处理文本、图像、音频、视频的上下文工程
5. **个性化上下文**：基于用户画像自动优化上下文选择策略

## 结语

上下文工程是构建 production-ready AI 应用的关键技术。四大路线——保存、选择、压缩、隔离——各有其适用场景，往往需要组合使用。随着技术的演进，我们期待看到更智能、更自动化的上下文管理方案，让开发者能更专注于业务逻辑而非底层细节。

---

**参考资源：**

- [LangChain Memory Documentation](https://python.langchain.com/docs/modules/memory/)
- [RAG Survey Paper](https://arxiv.org/abs/2312.10997)
- [MemGPT: Towards LLMs as Operating Systems](https://arxiv.org/abs/2310.08560)
- [Anthropic Context Caching](https://docs.anthropic.com/en/docs/build-with-claude/prompt-caching)
- [Microsoft AutoGen Documentation](https://microsoft.github.io/autogen/)
