# Hugo 博客搭建实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 基于 Hugo + PaperMod 主题搭建个人技术博客，部署在 GitHub Pages，支持搜索、评论、代码高亮等功能。

**架构：** 使用 Hugo 作为静态站点生成器，PaperMod 主题通过 git submodule 引入，评论系统使用 Giscus（基于 GitHub Discussions），部署通过 GitHub Actions 自动构建并发布到 GitHub Pages。

**技术栈：** Hugo, PaperMod, Giscus, GitHub Actions, GitHub Pages

---

## 文件结构

| 文件/目录 | 用途 |
|-----------|------|
| `.github/workflows/deploy.yml` | GitHub Actions 部署工作流 |
| `archetypes/default.md` | 文章模板 |
| `content/posts/` | 博客文章目录 |
| `content/archives.md` | 归档页 |
| `content/search.md` | 搜索页 |
| `hugo.yaml` | Hugo 主配置文件 |
| `themes/PaperMod/` | PaperMod 主题（git submodule） |
| `static/images/` | 图片资源目录 |

---

### Task 1: 初始化 Hugo 项目

**Files:**
- Create: `hugo.yaml`
- Modify: `.gitignore`

**前置条件：** 确保已安装 Hugo（extended 版本），可通过 `hugo version` 检查

- [ ] **Step 1: 检查 Hugo 是否已安装**

```bash
hugo version
```

**预期输出：** 显示 Hugo 版本信息，例如 `hugo v0.x.x ...`

**如果未安装：** 需先安装 Hugo extended 版本（https://gohugo.io/installation/）

- [ ] **Step 2: 初始化 Hugo 站点（保留现有文件）**

```bash
# 如果仓库已有内容，手动创建 Hugo 所需目录
mkdir -p archetypes content/posts static/images themes
```

- [ ] **Step 3: 创建 hugo.yaml 基础配置**

```yaml
baseURL: 'https://artmzhou.github.io/'
languageCode: 'zh-cn'
title: '我的博客'
theme: 'PaperMod'

pagination:
  pagerSize: 5

enableRobotsTXT: true
enableGitInfo: true

minify:
  disableXML: true
  minifyOutput: true

params:
  env: production
  title: '我的博客'
  description: '个人技术博客，分享学习心得与技术文章'
  keywords: [Blog, Tech, 技术博客]
  author: 'artmzhou'

  defaultTheme: auto
  disableThemeToggle: false

  ShowReadingTime: true
  ShowShareButtons: false
  ShowPostNavLinks: true
  ShowBreadCrumbs: true
  ShowCodeCopyButtons: true
  ShowWordCount: true
  ShowRssButtonInSectionTermList: true
  UseHugoToc: true
  disableSpecial1stPost: false
  disableScrollToTop: false
  comments: true
  hidemeta: false
  hideSummary: false
  showtoc: true
  tocopen: false

  profileMode:
    enabled: true
    title: '我的博客'
    subtitle: '个人技术博客，分享学习心得与技术文章'
    imageUrl: ''
    imageWidth: 120
    imageHeight: 120
    buttons:
      - name: 文章
        url: posts
      - name: 标签
        url: tags

  homeInfoParams:
    Title: '欢迎来到我的博客'
    Content: '这里记录我的学习历程与技术分享'

  socialIcons:
    - name: github
      url: 'https://github.com/artmzhou'

menu:
  main:
    - identifier: home
      name: 首页
      url: /
      weight: 10
    - identifier: posts
      name: 文章
      url: /posts/
      weight: 20
    - identifier: archives
      name: 归档
      url: /archives/
      weight: 30
    - identifier: search
      name: 搜索
      url: /search/
      weight: 40
    - identifier: tags
      name: 标签
      url: /tags/
      weight: 50

outputs:
  home:
    - HTML
    - RSS
    - JSON

params:
  fuseOpts:
    isCaseSensitive: false
    shouldSort: true
    location: 0
    distance: 1000
    threshold: 0.4
    minMatchCharLength: 0
    keys: ["title", "permalink", "summary", "content"]
```

- [ ] **Step 4: 更新 .gitignore**

将以下内容追加到 `.gitignore`：

```
# Hugo
/public/
/resources/_gen/
/assets/jsconfig.json
hugo_stats.json
hugo.exe
hugo.darwin
hugo.linux
```

- [ ] **Step 5: 提交更改**

```bash
git add hugo.yaml .gitignore
git commit -m "$(cat <<'EOF'
chore: 初始化 Hugo 项目配置

- 添加 hugo.yaml 基础配置
- 更新 .gitignore 忽略 Hugo 生成文件

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: 添加 PaperMod 主题

**Files:**
- Create: `themes/PaperMod/` (git submodule)

- [ ] **Step 1: 添加 PaperMod 主题为 git submodule**

```bash
git submodule add --depth=1 https://github.com/adityatelange/hugo-PaperMod.git themes/PaperMod
```

**预期输出：** 显示添加 submodule 的信息

- [ ] **Step 2: 验证主题已添加**

```bash
ls themes/PaperMod/
```

**预期输出：** 显示主题的目录结构，如 `assets`, `layouts`, `static` 等

- [ ] **Step 3: 提交更改**

```bash
git add .gitmodules themes/PaperMod
git commit -m "$(cat <<'EOF'
feat: 添加 PaperMod 主题

通过 git submodule 引入 PaperMod 主题

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: 创建内容模板和页面

**Files:**
- Create: `archetypes/default.md`
- Create: `content/archives.md`
- Create: `content/search.md`

- [ ] **Step 1: 创建文章模板 archetypes/default.md**

```markdown
---
title: "{{ replace .File.ContentBaseName "-" " " | title }}"
date: {{ .Date }}
draft: true
tags: []
categories: []
summary: ""
---
```

- [ ] **Step 2: 创建归档页 content/archives.md**

```markdown
---
title: "归档"
layout: "archives"
url: "/archives/"
summary: "archives"
---
```

- [ ] **Step 3: 创建搜索页 content/search.md**

```markdown
---
title: "搜索"
layout: "search"
summary: "search"
placeholder: "输入关键词搜索..."
---
```

- [ ] **Step 4: 提交更改**

```bash
git add archetypes/default.md content/archives.md content/search.md
git commit -m "$(cat <<'EOF'
feat: 添加文章模板和基础页面

- 添加 archetypes/default.md 文章模板
- 添加归档页和搜索页

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: 创建示例文章

**Files:**
- Create: `content/posts/hello-world.md`

- [ ] **Step 1: 创建示例文章**

```markdown
---
title: "Hello World"
date: 2026-04-09T10:00:00+08:00
draft: false
tags: ["hugo", "blog"]
categories: ["技术"]
summary: "第一篇博客文章，测试 Hugo + PaperMod 部署"
---

## 欢迎使用 Hugo

这是我的第一篇博客文章！

### 特性展示

**代码高亮测试：**

```python
def hello():
    print("Hello, World!")
```

**列表测试：**

- 支持 Markdown 语法
- 自动代码高亮
- 响应式布局
- 暗色/亮色模式切换

> 这是一段引用文字。

感谢使用 PaperMod 主题！
```

- [ ] **Step 2: 提交更改**

```bash
git add content/posts/hello-world.md
git commit -m "$(cat <<'EOF'
feat: 添加示例文章

第一篇测试文章，展示 Markdown 语法和代码高亮

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: 本地构建测试

**Files:**
- 无新文件创建

- [ ] **Step 1: 本地构建站点**

```bash
hugo --minify
```

**预期输出：** 显示构建成功的信息，如 `Total in xxx ms` 或 `Built in xxx ms`

- [ ] **Step 2: 验证 public 目录已生成**

```bash
ls public/
```

**预期输出：** 显示 `index.html`, `posts/`, `archives/` 等文件和目录

- [ ] **Step 3: （可选）本地预览**

```bash
hugo server -D
```

然后访问 http://localhost:1313 查看效果。
按 Ctrl+C 停止预览服务器。

- [ ] **Step 4: 清理构建产物（不提交到仓库）**

```bash
rm -rf public/
```

---

### Task 6: 创建 GitHub Actions 部署工作流

**Files:**
- Create: `.github/workflows/deploy.yml`

**前置条件：** GitHub 仓库已开启 Pages 功能（Settings → Pages → Build and deployment → Source: GitHub Actions）

- [ ] **Step 1: 创建工作流目录**

```bash
mkdir -p .github/workflows
```

- [ ] **Step 2: 创建 deploy.yml**

```yaml
name: Deploy Hugo site to Pages

on:
  push:
    branches:
      - main
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: "pages"
  cancel-in-progress: false

defaults:
  run:
    shell: bash

jobs:
  build:
    runs-on: ubuntu-latest
    env:
      HUGO_VERSION: 0.145.0
    steps:
      - name: Install Hugo CLI
        run: |
          wget -O ${{ runner.temp }}/hugo.deb https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_linux-amd64.deb \
          && sudo dpkg -i ${{ runner.temp }}/hugo.deb
          
      - name: Install Dart Sass
        run: sudo snap install dart-sass
        
      - name: Checkout
        uses: actions/checkout@v4
        with:
          submodules: recursive
          fetch-depth: 0
          
      - name: Setup Pages
        id: pages
        uses: actions/configure-pages@v5
        
      - name: Install Node.js dependencies
        run: "[[ -f package-lock.json || -f npm-shrinkwrap.json ]] && npm ci || true"
        
      - name: Build with Hugo
        env:
          HUGO_CACHEDIR: ${{ runner.temp }}/hugo_cache
          HUGO_ENVIRONMENT: production
          TZ: Asia/Shanghai
        run: |
          hugo \
            --gc \
            --minify \
            --baseURL "${{ steps.pages.outputs.base_url }}/"
            
      - name: Upload artifact
        uses: actions/upload-pages-artifact@v3
        with:
          path: ./public

  deploy:
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    runs-on: ubuntu-latest
    needs: build
    steps:
      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v4
```

- [ ] **Step 3: 提交更改**

```bash
git add .github/workflows/deploy.yml
git commit -m "$(cat <<'EOF'
ci: 添加 GitHub Actions 部署工作流

自动构建 Hugo 站点并部署到 GitHub Pages

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: 集成 Giscus 评论系统

**Files:**
- Create: `layouts/partials/comments.html`
- Modify: `hugo.yaml`（添加 Giscus 配置）

**前置条件：** GitHub 仓库已开启 Discussions 功能，且已安装 Giscus GitHub App

- [ ] **Step 1: 创建评论模板文件**

```bash
mkdir -p layouts/partials
```

创建 `layouts/partials/comments.html`：

```html
{{ if and .Site.Params.giscus.repo .Site.Params.comments }}
<script src="https://giscus.app/client.js"
        data-repo="{{ .Site.Params.giscus.repo }}"
        data-repo-id="{{ .Site.Params.giscus.repoId }}"
        data-category="{{ .Site.Params.giscus.category }}"
        data-category-id="{{ .Site.Params.giscus.categoryId }}"
        data-mapping="pathname"
        data-strict="0"
        data-reactions-enabled="1"
        data-emit-metadata="0"
        data-input-position="bottom"
        data-theme="preferred_color_scheme"
        data-lang="zh-CN"
        crossorigin="anonymous"
        async>
</script>
{{ end }}
```

- [ ] **Step 2: 在 hugo.yaml 中添加 Giscus 配置占位**

在 `hugo.yaml` 的 `params:` 部分添加：

```yaml
  giscus:
    repo: "artmzhou/artmzhou.github.io"
    repoId: "YOUR_REPO_ID"
    category: "Announcements"
    categoryId: "YOUR_CATEGORY_ID"
```

**注意：** `repoId` 和 `categoryId` 需要在配置 Giscus 后获取（访问 https://giscus.app 生成配置）

- [ ] **Step 3: 提交更改**

```bash
git add layouts/partials/comments.html hugo.yaml
git commit -m "$(cat <<'EOF'
feat: 集成 Giscus 评论系统

- 添加评论模板文件
- 在配置中添加 Giscus 占位配置

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

---

### Task 8: 更新 CLAUDE.md 文档

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: 更新项目概述**

将 `CLAUDE.md` 更新为：

```markdown
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
```

- [ ] **Step 2: 提交更改**

```bash
git add CLAUDE.md
git commit -m "$(cat <<'EOF'
docs: 更新 CLAUDE.md 项目文档

添加技术栈、项目结构、常用命令和发布流程说明

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

---

### Task 9: Push 到 GitHub 并验证部署

**Files:**
- 无新文件创建

- [ ] **Step 1: 推送所有更改到 GitHub**

```bash
git push origin main
```

**预期输出：** 显示推送成功的信息

- [ ] **Step 2: 检查 GitHub Actions 运行状态**

访问 `https://github.com/artmzhou/artmzhou.github.io/actions`，确认工作流运行成功。

- [ ] **Step 3: 验证网站部署**

访问 `https://artmzhou.github.io`，确认博客页面正常显示。

---

## 实现后检查清单

- [ ] Hugo 配置文件 `hugo.yaml` 正确无误
- [ ] PaperMod 主题通过 git submodule 成功引入
- [ ] 归档页和搜索页可正常访问
- [ ] 示例文章显示正常，代码高亮生效
- [ ] 暗色/亮色模式切换正常
- [ ] 搜索功能可正常使用
- [ ] GitHub Actions 工作流运行成功
- [ ] 网站在 `https://artmzhou.github.io` 可访问
- [ ] （可选）Giscus 评论系统已配置并可用
