# artmzhou.github.io 重塑设计文档

## 背景

当前站点是基于 Hugo + PaperMod 的个人技术博客，已经具备文章、归档、搜索、标签、RSS、Giscus 评论和 GitHub Pages 自动部署能力。现有问题是首页仍停留在 PaperMod profile 模式，站点第一屏无法表达个人技术定位；同时 `hugo.yaml` 中部分中文配置出现乱码，需要在重塑中一并修复。

参考项目 `ttttstc/ttttstc.github.io` 是一个偏个人品牌门户的静态站。它的核心价值不在具体技术栈，而在清晰的编辑型首页、暖色视觉系统、能力地图、作品展示、博客入口、工具箱和教程分区。本站重塑应借鉴这些信息架构和视觉规则，同时保留 Hugo 内容管理能力。

## 目标

1. 保留 Hugo + PaperMod + GitHub Pages 的基础架构，不迁移为纯 HTML 站点。
2. 将首页从默认 profile 改造成个人品牌门户，突出 AI、Agent、RAG、Claude Code、工程实践等主题。
3. 借鉴参考站的暖米色画布、serif 标题、mono 元信息、橙色点睛和编辑型排版。
4. 修复站点配置中的中文乱码，统一导航、描述、首页文案和 SEO 文案。
5. 保留现有文章、搜索、归档、标签、RSS、Giscus 评论和自动部署。
6. 不直接复制参考站的文案、图片、个人身份和项目资产。

## 非目标

1. 不重写为 React、Vue、Next.js 或纯手写 HTML。
2. 不修改 `themes/PaperMod` submodule 内部文件。
3. 不删除现有文章、图片或评论配置。
4. 不引入需要后端服务、数据库或登录态的功能。
5. 不在本轮创建完整作品详情系统；作品区先作为首页精选入口。

## 信息架构

### 首页

首页是本次重塑的中心。结构如下：

1. 顶部导航：品牌标识、首页、文章、专题、归档、搜索、GitHub。
2. Hero：显示 `artmzhou` 或 `embers` 的品牌名称，一句个人技术定位，两枚行动按钮。
3. 关于我：用短段落介绍站点主人正在围绕 AI 工程化、Agent、RAG 和 Claude Code 做学习与实践。
4. 能力地图：四个方向，建议为 AI Agent、RAG/向量检索、Claude Code 工作流、模型微调与工程化。
5. 专题/作品：把现有文章聚合成项目式入口，例如 RAG 系列、Agent 范式、Claude Code Agent Teams、Vibe Coding。
6. 最新文章：自动展示最近文章，保持 Hugo 内容驱动。
7. 工具箱/实验：预留给 prompt、skills、workflow、demo 等未来内容；本轮可先作为轻量 section，不新增复杂内容模型。
8. 联系：GitHub 和站点 RSS/搜索入口。

### 文章页

文章页继续使用当前 PaperMod 派生模板，保留：

1. 面包屑、标题、日期、阅读时间、字数。
2. 目录、代码复制、文章前后导航。
3. Giscus 评论。

文章页只做必要的视觉统一，不在本轮重写阅读版式。

### 列表页

文章列表、归档、搜索、标签页继续使用 PaperMod 默认能力。可以通过全局 CSS 让颜色、字体和卡片状态与首页协调，但不改变数据流和路由。

## 视觉系统

视觉借鉴参考站 `brand-spec.md`，但转化为本站自己的主题。

### 色彩

使用暖色编辑型站点配色：

- 页面背景：暖米色 `#ece4d9`
- 区块背景：浅暖灰 `#f4f0ea`
- 卡片背景：暖白 `#fffbf5`
- 正文墨色：`#4f483e`
- 次级文字：`#8a7d6b`
- 细边框：`#e2d8cb`
- 主强调色：橙红 `#f54001`
- 柔和强调底色：`#ffc198`

橙色只用于眉标、主按钮、active 状态和少量链接，不铺满页面。避免紫色渐变、大面积深蓝、纯白背景和过度装饰。

### 字体

通过 Google Fonts 引入：

- 标题：Playfair Display，fallback 为 Georgia 和中文 serif 字体。
- 正文与 UI：Inter，fallback 为系统无衬线字体。
- 日期、标签、编号：JetBrains Mono，fallback 为系统等宽字体。

如果字体加载失败，站点仍应使用系统字体正常显示。

### 布局

1. 内容最大宽度约 1180px，文章正文维持较窄阅读宽度。
2. 首页采用大标题、短段落、分区式编辑节奏。
3. 卡片圆角控制在 10-16px，阴影柔和，边框轻。
4. 移动端导航折叠为简单菜单，首页各网格降为单列。
5. 不使用纯装饰性的渐变球、SVG 插画或营销式空泛 hero。

## Hugo 实现设计

### 配置

重写 `hugo.yaml` 中乱码内容，保留现有关键配置：

- `baseURL`
- `languageCode`
- `theme: PaperMod`
- 搜索输出 JSON
- Giscus 配置
- PaperMod 的阅读时间、字数、目录、代码复制等参数

调整内容：

- 关闭或绕开 `profileMode` 对首页的主导展示。
- 设置中文站点描述、关键词、导航名称。
- 增加首页所需的 `params.home` 或类似结构，承载 Hero、能力地图、专题卡片、工具箱文案。

### 模板

新增或覆盖 Hugo 首页模板：

- `layouts/index.html` 负责首页结构。
- 首页从 `.Site.Params` 和 `.Site.RegularPages` 读取内容。
- 最新文章从 `content/posts` 自动取最近若干篇。
- 专题/作品可以先在配置中声明标题、描述、标签和链接。

继续使用现有：

- `layouts/_default/single.html`
- `layouts/partials/comments.html`

### 样式

新增：

- `assets/css/extended/brand.css`

PaperMod 会自动加载 `assets/css/extended/` 下的扩展样式。该文件承载：

- CSS tokens
- 首页布局
- 全局字体
- 导航、按钮、卡片、文章列表的视觉统一
- 移动端响应式规则

不直接编辑 `themes/PaperMod/assets`。

## 内容映射

首页内容应基于当前文章资产，而不是虚构项目。

建议映射：

- RAG 系列：`RAG数据准备.md`、`RAG向量数据库.md`、`RAG-SemanticChunker.md`
- Agent 系列：`agent范式.md`、`claude-code-agent-teams.md`
- Claude Code 工作流：`vibe-coding.md`、`mattpocock-skills尝鲜案例.md`、`superpowers.md`
- 模型实践：`使用llamafactory浅尝Finetuning.md`

`hello-world.md` 是初始化测试文章，可保留但不作为首页精选。

## 错误处理与降级

1. 首页配置缺失时，模板应显示合理默认文案，不构建失败。
2. 没有足够文章时，最新文章区显示已有文章数量，不创建空卡片。
3. 外部字体加载失败时使用 fallback 字体。
4. Giscus 配置不完整时评论区不渲染脚本。
5. 图片资源缺失时首页不依赖大图完成布局。

## 验证方式

实施后需要验证：

1. `hugo --minify` 构建成功。
2. 首页生成后包含 Hero、关于我、能力地图、专题/作品、最新文章、工具箱/实验、联系。
3. `/posts/`、`/archives/`、`/search/`、`/tags/` 仍可访问。
4. 至少一篇文章页仍显示正文、目录、元信息和 Giscus 评论脚本。
5. `public/index.html` 不再呈现 PaperMod profile 首页结构。
6. 中文导航和描述不再乱码。
7. 移动端布局不会出现明显文字重叠或横向溢出。

## 实施顺序

1. 修复 `hugo.yaml`，整理站点参数和中文文案。
2. 新增首页模板 `layouts/index.html`。
3. 新增扩展样式 `assets/css/extended/brand.css`。
4. 运行 Hugo 构建，修复模板或配置错误。
5. 启动本地预览并检查首页、列表页、文章页。
6. 根据渲染结果微调样式。

## 设计自检

- 没有未决占位符；本轮范围限定为首页、配置和全局视觉，不包含完整作品系统。
- 架构与目标一致：保留 Hugo/PaperMod 能力，同时通过自定义首页和扩展 CSS 达到参考站式门户效果。
- 范围可在一个实施计划中完成，不需要拆成多个独立项目。
- 对“模仿”的解释已明确：借鉴信息架构和视觉系统，不复制身份、文案与素材。
