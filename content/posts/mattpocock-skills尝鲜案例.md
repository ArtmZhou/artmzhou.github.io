---
title: "Mattpocock Skills尝鲜案例"
date: 2026-05-13T00:13:18+08:00
draft: false
tags: ["RAG", "Claude Code", "skills"]
categories: []
summary: ""
---
# Mattpocock Skill 使用案例：RAG 知识库功能从零到交付

skill下载地址：https://github.com/mattpocock/skills.git

> 记录本次对话中使用的 6 个 Matt Pocock 工程 skill 及其效果，作为后续团队的参考案例。

## 背景

在 Cat Agent Platform (猫猫多Agent协同系统) 上新增 RAG 知识库功能。用户需求：支持搭建知识库，Agent 能选择知识库以增强回复质量。

整个流程从配置到交付耗时约 2 小时，53 测试全绿，42 个文件变更，PR #20 已开。

---

## Skill 使用流程

### 1. `/setup-matt-pocock-skills` — 基础设施配置

**做了什么**：
- 检测到 GitHub 仓库 `ArtmZhou/cat-cat-cooperations`
- 确认 CLAUDE.md 存在，在末尾追加 `## Agent skills` 区块
- 创建 `docs/agents/` 下三个配置文件：
  - `issue-tracker.md` — GitHub Issues (主) + 本地 markdown (备)
  - `triage-labels.md` — 五阶段 triage 标签映射
  - `domain.md` — 单上下文布局
- 确定项目无 CONTEXT.md、无 ADR、无现有 agent skill 配置

**效果**：后续所有 skill 都能找到 issue tracker、标签词汇表和领域文档位置。一次性 setup，全链路共享。

---

### 2. `/grill-with-docs` — 需求设计深度访谈

**做了什么**：
- 先用 Agent 全面探索代码库（实体、Service、Controller、前端路由、存储模式、API 约定）
- 逐条提问 25 个决策点，覆盖：
  - 知识库类型、绑定关系、分块策略、嵌入模型、向量存储
  - 检索时机、注入格式、Token 预算、Provider 架构
  - 权限模型、群组绑定、级联删除、文件限制
  - 前端入口、API 端点设计
- 每个决策给出推荐方案和理由
- 实时创建 `CONTEXT.md`（9 个 RAG 领域术语 + 关系 + 歧义说明）
- 创建 `docs/adr/0001-rag-provider-interfaces.md`（接口抽象 vs 条件 Bean 的架构决策）

**效果**：25 个决策全部敲定，没有反复。CONTEXT.md 和 ADR 成为后续 skill 的"共同语言"。

---

### 3. `/to-issues` — 方案拆分为可执行 Issue

**做了什么**：
- 将 RAG 方案按 tracer bullet 原则拆为 7 个垂直切片：

| # | Issue | 依赖 |
|---|-------|------|
| 1 | 知识库 CRUD 生命周期 | — |
| 2 | 最小端到端检索链路 | #1 |
| 3 | 多格式文件支持 | #2 |
| 4 | Agent 知识库绑定与检索注入 | #2 |
| 5 | 群组知识库绑定与合并检索 | #4 |
| 6 | 本地/国产嵌入模型支持 | #2 |
| 7 | Qdrant 外置向量库支持 | #2 |

- 先发布到本地 `.scratch/`，安装 gh CLI 后发布到 GitHub Issues (#12~#18)
- 全部标记 `ready-for-agent`
- 创建了对应的 triage labels

**效果**：7 个独立可验证的 AFK issue，有明确的依赖关系和验收标准。

---

### 4. `/tdd` — 测试驱动实现

**做了什么**：
- 按推荐顺序 #12 → #13 → #14/#15/#16/#17 (并行) → #18 逐一实现
- 每步遵循 RED → GREEN 循环
- Tracer bullet: 先写 `create + get` 测试 → 实现 entity + store + service → 7 个测试全绿
- 后续增量：分页、更新、级联删除
- 最终 53/53 测试全绿（46 原有 + 7 新增）

**效果**：每步都先写测试再写代码，避免过度设计和不可验证的实现。

---

### 5. `/to-prd` — 生成 PRD 文档

**做了什么**：
- 从对话上下文中提取所有决策，合成 PRD 发布为 [#19](https://github.com/ArtmZhou/cat-cat-cooperations/issues/19)
- 包含：问题陈述、19 条用户故事、完整实现决策、测试策略、范围外说明

**效果**：一份结构化的功能规格书，可供后续维护者或新成员快速理解功能全貌。

---

### 6. `/triage` — Issue 收尾管理

**做了什么**：
- 检出 3 个未标记的老 issue（#1、#4、#5）
- 用户确认关闭 #12~#19，批量关闭并添加 closing comment

**效果**：Issue 看板干净，所有 RAG 相关 issue 已归档。

---

## 关键经验

1. **按顺序来**：setup → grill → issues → tdd → prd → triage 的链条是自然的工作流，前后依赖清晰
2. **grill 越彻底，实现越顺畅**：25 个决策点看似多，但全部敲定后在 TDD 阶段几乎不需要回头改设计
3. **垂直切片优于水平分层**：/#13 作为 tracer bullet 走通了 TXT → 嵌入 → 检索 → 前端全链路，后续 issue 只需扩展而非重构
4. **CONTEXT.md 是桥梁**：grill 阶段产出的术语表在后续 skill 中被自动引用，保证了词汇一致性
5. **gh CLI 备用路径**：当 gh 未安装或未认证时，本地 markdown 作为 fallback 保证了流程不中断
