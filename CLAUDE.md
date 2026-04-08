# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

个人博客项目，仓库名 `artmzhou.github.io`，通过 GitHub Pages 托管，使用 GitHub Actions 自动部署。

## 技术栈

- **静态站点生成器：** Hugo
- **主题：** PaperMod（git submodule）
- **评论系统：** Giscus（基于 GitHub Discussions）
- **部署：** GitHub Actions → GitHub Pages

## 项目结构

```
artmzhou.github.io/
├── .github/workflows/
│   └── deploy.yml          # GitHub Actions 部署工作流
├── archetypes/
│   └── default.md          # 文章模板（frontmatter 预设）
├── content/
│   ├── posts/              # 博客文章目录
│   ├── archives.md         # 归档页
│   └── search.md           # 搜索页
├── layouts/partials/
│   └── comments.html       # Giscus 评论模板
├── static/
│   └── images/             # 图片资源
├── hugo.yaml               # Hugo 主配置文件
└── themes/
    └── PaperMod/           # PaperMod 主题（git submodule）
```

## 常用命令

```bash
# 本地预览
hugo server -D

# 创建新文章
hugo new posts/my-article.md

# 本地构建
hugo --minify
```

## 发布流程

1. 使用 `hugo new posts/文章名.md` 创建新文章
2. 编辑 `content/posts/文章名.md`，将 `draft: true` 改为 `draft: false`
3. Push 到 `main` 分支
4. GitHub Actions 自动构建并部署

## 配置 Giscus 评论（首次设置）

1. 在 GitHub 仓库 Settings → General → Features 中开启 Discussions
2. 访问 https://giscus.app，填写仓库信息，获取 `repoId` 和 `categoryId`
3. 更新 `hugo.yaml` 中的 `params.giscus` 配置

## 部署

- **目标平台：** GitHub Pages（`https://artmzhou.github.io`）
- **部署方式：** GitHub Actions 自动构建并发布
- **工作流文件：** `.github/workflows/deploy.yml`

## 约定

- 文档和注释优先使用中文
- 文章使用 Markdown 格式编写
- 图片资源放在 `static/images/` 目录下
