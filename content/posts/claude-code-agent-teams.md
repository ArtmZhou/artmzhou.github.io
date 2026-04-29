---
title: "Claude Code Agent Teams：多智能体协作实践"
date: 2026-04-29T20:00:00+08:00
draft: false
tags: ["AI", "Claude Code", "Agent", "Multi-Agent"]
categories: ["技术"]
summary: "探索Claude Code的Agent Teams功能，了解如何通过多智能体协作提升开发效率"
---

我最近在用Claude Code干活的时候碰到一个挺烦的事：手头一个大需求，拆开来看其实好几块互相不挡路，但Claude Code一次只能干一件事，你只能眼睁睁看着它一个接一个地串行处理。重构三个独立模块？排队。前端改UI后端加API？还是排队。

后来发现Claude Code有个Agent Teams功能，简单说就是能拉一个"施工队"，多个agent同时开工，各管各的，最后汇总。试了一下，确实有点意思。

## 核心概念

Agent Teams的模型不复杂，三个关键词就能概括：团队、任务、通信。

**团队** 就是个协作容器。`TeamCreate`一调用，就建好了一个团队，成员共享任务列表，互相能发消息。

**任务** 是最小工作单元。`TaskCreate`建任务，`TaskUpdate`改状态，还能设依赖——"B等A做完再开始"这种。

**通信** 靠`SendMessage`，agent之间可以直接喊话，汇报进度、请求支援都行。

## 工作流程

一个典型的流程大概是这样的：

```
1. TeamCreate 创建团队
2. TaskCreate 拆分任务，设置依赖关系
3. Agent 派生子agent，分配到团队
4. 各agent并行执行各自的任务
5. 通过 SendMessage 协调进度
6. 任务完成后 TaskUpdate 标记状态
7. 所有任务完成，团队解散
```

实际在Claude Code里用起来，对话大概长这样：

```
你：帮我重构 auth、payment、notification 三个模块

Claude Code：
  → TeamCreate("refactor-team")
  → TaskCreate("重构auth模块")
  → TaskCreate("重构payment模块") 
  → TaskCreate("重构notification模块")
  → Agent("auth-worker", 负责auth模块)
  → Agent("payment-worker", 负责payment模块)
  → Agent("notification-worker", 负责notification模块)
  → 三个agent并行工作...
  → 汇总结果
```

## 哪些场景适合用

### 并行重构

项目里有几个独立模块要从JavaScript迁到TypeScript，单agent得一个一个来，开了团队直接三路并进，互不干扰。实测下来确实快不少。

### 前后端同时搞

加个新功能，前端改组件后端加API，接口约定好了其实没啥依赖：

```
TaskCreate("实现后端API /api/users/export")
TaskCreate("实现前端导出按钮和下载逻辑")
→ 两个agent同时开工
```

### 写代码的同时写测试

一个agent撸实现，另一个照着需求文档写测试。两边完事儿跑一遍，看看能不能对上。

### 内容创作 + 审核（本文的真实案例）

这篇博客本身就是用Agent Teams写的，下面是完整的过程记录。

我给Claude Code下了一个指令："创建一个agent team来完成这个任务，一个成员用来撰写博客内容，一个成员用来审核博客内容并去除其中的AI味道。"

Claude Code随即开始组建团队：

```
→ TeamCreate("blog-agent-teams")
→ TaskCreate("撰写博客初稿")           # 任务1，分配给writer
→ TaskCreate("审核并去除AI味道")        # 任务2，分配给reviewer
→ TaskUpdate(task2, blocked_by=[task1]) # 审核等初稿完成
→ Agent("writer", 负责撰写初稿)         # 派生writer agent
```

![建团队和分配任务](/images/agent-teams-setup.png)

团队建好了，任务也分配了，依赖关系也设了。看起来一切就绪。

然后writer agent就...idle了。啥也没干。

![writer agent idle](/images/agent-teams-writer-idle.png)

我让team lead发消息催它："文件还没创建出来，请立即撰写。"writer收到消息后又idle了。还是啥也没干。

![催促writer](/images/agent-teams-remind-writer.png)

没办法，team lead自己上手写了初稿。然后派出reviewer agent来审核：

```
→ TaskUpdate(task1, status="completed")
→ Agent("reviewer", 负责审核润色)
```

reviewer agent也idle了。一个字没改。

![reviewer也idle了](/images/agent-teams-reviewer-idle.png)

最后team lead又自己做了审核润色，把AI味道重的句子一个个改掉。两个agent全程摸鱼，所有活儿都是team lead（主agent）干的。

甚至到最后想用`TeamDelete`解散团队，两个agent连shutdown请求都不响应，团队都散不掉。

**为什么会这样？**

最可能的原因是权限问题。子agent作为团队成员异步运行时，写文件、编辑文件这些操作会触发权限确认，但这些确认提示在子agent的异步上下文中没法被用户看到和批准。agent拿不到权限，就只能干等着，最后idle。

这其实暴露了Agent Teams目前的一个现实问题：**子agent的权限模型和主agent不一致**。主agent可以直接跟用户交互拿授权，子agent不行。对于纯读取、纯推理的任务可能没问题，但涉及文件操作的任务就容易卡住。

## 工具速查

| 工具 | 干嘛的 | 什么时候用 |
|------|--------|-----------|
| `TeamCreate` | 建团队，附带共享任务列表 | 开始协作时 |
| `TaskCreate` | 建任务 | 拆分工作 |
| `TaskUpdate` | 改状态、设依赖 | 任务开始/完成/阻塞时 |
| `Agent` | 派agent加入团队 | 分配活儿 |
| `SendMessage` | agent间发消息 | 协调、汇报 |
| `TaskList` | 看所有任务状态 | 查进度 |
| `TeamDelete` | 解散团队 | 收工 |

## 跟单Agent比有啥好处

一个agent干所有活，上下文全挤在一个窗口里，串行执行。简单任务没毛病，但活儿一多就顶不住了：

- 上下文窗口塞满了各种任务的代码和思考过程，关键信息容易被冲掉
- 独立的任务也得排队，白白浪费时间
- 一个agent又写又审，等于自己review自己，效果打折

开了团队之后：

**上下文隔离** 每个agent有自己的上下文窗口，专心干自己的事，不会被别的任务干扰。

**并行执行** 独立任务同时跑，总耗时≈最慢那个任务的耗时，不是加在一起。

**职责分离** 写代码的写代码，做review的做review，各管各的。

## 踩过的坑

1. **别啥都开团队**。任务简单或者前后依赖很强的，单agent反而利索，省得协调来协调去。

2. **任务拆分有讲究**。太细了通信成本高，太粗了并行不起来。按模块或功能边界拆，一般比较靠谱。

3. **依赖关系别忘设**。`TaskUpdate`的`addBlockedBy`能保证执行顺序，不然审核agent可能在初稿还没写完就冲上去了。

4. **prompt要写详细**。子agent看不到主对话的上下文，你得在派生的时候把背景、风格、约束都交代清楚，不然它两眼一抹黑。

5. **注意权限问题**。子agent异步运行时，文件读写操作可能因为权限确认机制卡住。如果任务涉及文件操作，留意agent是不是idle了没动静，必要时team lead得准备兜底。

## 最后

Agent Teams的思路是好的——把大任务拆开，多个agent并行干活，各司其职。但从这次实践来看，它还不够成熟，至少在涉及文件操作的场景下，子agent的权限问题是个硬伤。

不过话说回来，这次"翻车"本身也挺有价值的。它让我搞清楚了Agent Teams的能力边界在哪，也让这篇文章多了一个真实的案例而不是一堆理想化的描述。

等权限模型完善了，Agent Teams应该会是个很实用的功能。在那之前，简单任务还是单agent省心，复杂任务可以试试团队模式，但记得给team lead留个兜底方案。
