# 个人博客设计文档

## 概述

基于 Hugo + PaperMod 主题搭建个人技术博客，部署在 GitHub Pages（`https://artmzhou.github.io`）。主题风格简洁，参考 Claude 官方文档页的留白与排版。支持全文搜索、评论系统、标签分类、代码高亮等功能。

## 技术选型

- 静态站点生成器：Hugo
- 主题：PaperMod（git submodule 引入）
- 评论系统：Giscus（基于 GitHub Discussions）
- 搜索：Fuse.js（PaperMod 内置）
- 代码高亮：Chroma（Hugo 内置）
- 部署：GitHub Actions → GitHub Pages

## 项目结构

```
artmzhou.github.io/
├── .github/workflows/
│   └── deploy.yml          # GitHub Actions 部署工作流
├── archetypes/
│   └── default.md          # 文章模板（frontmatter 预设）
├── content/
│   ├── posts/              # 博客文章目录
│   │   └── hello-world.md  # 示例文章
│   ├── archives.md         # 归档页
│   └── search.md           # 搜索页
├── static/
│   └── images/             # 图片资源
├── hugo.yaml               # Hugo 主配置文件
└── themes/
    └── PaperMod/           # git submodule
```

## Hugo 配置（hugo.yaml）

### 基本信息

- `baseURL`: `https://artmzhou.github.io/`
- `languageCode`: `zh-cn`
- `title`: 站点标题
- `theme`: `PaperMod`

### 主题参数

- 首页模式：`ProfileMode`（头像 + 简介 + 社交链接）
- 启用：面包屑导航、文章阅读时间估算、代码复制按钮
- 暗色/亮色模式切换

### 搜索

- 启用 Fuse.js 全文搜索
- `outputs.home` 包含 JSON 格式，生成搜索索引

### 代码高亮

- 使用 Hugo 内置 Chroma 引擎
- 启用行号显示
- 高亮主题风格与博客主题协调

### 菜单栏

- 首页、归档、搜索、标签、分类

## 评论系统

- 使用 Giscus，基于 GitHub Discussions
- 前置条件：
  - 在 GitHub 仓库开启 Discussions 功能
  - 安装 Giscus GitHub App 并授权给 `artmzhou.github.io` 仓库
- 配置项：`repo`、`repoId`、`category`、`categoryId`
- 通过覆盖 `layouts/partials/comments.html` 模板注入 Giscus 脚本
- 评论区跟随博客暗色/亮色主题切换

## GitHub Actions 部署

- 触发条件：push 到 `main` 分支
- 构建流程：
  1. Checkout 代码（含 submodule）
  2. 安装 Hugo（extended 版本）
  3. `hugo --minify` 构建静态文件
  4. 使用 `actions/deploy-pages` 部署到 GitHub Pages
- 仓库 Settings 中 Pages Source 设为 "GitHub Actions"

## 文章模板（archetypes/default.md）

```yaml
---
title: "文章标题"
date: 创建时间
draft: true
tags: []
categories: []
summary: ""
---
```

- `hugo new posts/my-article.md` 自动填充模板
- `draft: true` 默认草稿，发布时改为 `false`
- `tags` 和 `categories` 支持多值

## 发布流程

1. 运行 `hugo new posts/文章名.md`
2. 编辑 Markdown 内容
3. 将 `draft` 改为 `false`
4. Push 到 `main` 分支
5. GitHub Actions 自动构建部署
