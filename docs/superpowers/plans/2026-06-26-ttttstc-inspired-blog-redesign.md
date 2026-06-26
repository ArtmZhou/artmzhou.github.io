# ttttstc-Inspired Blog Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rework `artmzhou.github.io` into a ttttstc-inspired Hugo personal brand portal while preserving the existing blog, search, comments, RSS, and GitHub Pages deployment.

**Architecture:** Keep PaperMod as the base theme and add project-local overrides only. The redesign is driven by `hugo.yaml`, a new home template at `layouts/index.html`, a PaperMod extended stylesheet at `assets/css/extended/brand.css`, and a repeatable smoke verifier at `scripts/verify-redesign.ps1`.

**Tech Stack:** Hugo 0.146+, PaperMod, Hugo templates, YAML configuration, CSS, PowerShell verification.

---

## File Structure

- Create `scripts/verify-redesign.ps1`: builds the site and asserts the generated HTML proves the redesign requirements.
- Modify `hugo.yaml`: repair garbled Chinese text, define home sections, update navigation, keep PaperMod/Giscus/search settings.
- Create `layouts/index.html`: render the new editorial home page from site params and recent posts.
- Create `assets/css/extended/brand.css`: define the warm editorial visual system and responsive layout.
- Use existing `layouts/_default/single.html` and `layouts/partials/comments.html`: preserve article rendering and Giscus.

## Task 1: Add Failing Redesign Verifier

**Files:**
- Create: `scripts/verify-redesign.ps1`

- [ ] **Step 1: Add verifier script**

Create `scripts/verify-redesign.ps1` with checks that run after `hugo --minify`. It must fail on the current PaperMod profile home because the required custom sections and CSS do not exist yet.

```powershell
param(
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$ErrorActionPreference = 'Stop'
Set-Location $Root

function Assert-Contains {
  param(
    [string]$Content,
    [string]$Needle,
    [string]$Label
  )
  if (-not $Content.Contains($Needle)) {
    throw "Missing ${Label}: ${Needle}"
  }
}

function Assert-NotContains {
  param(
    [string]$Content,
    [string]$Needle,
    [string]$Label
  )
  if ($Content.Contains($Needle)) {
    throw "Unexpected ${Label}: ${Needle}"
  }
}

hugo --minify

$indexPath = Join-Path $Root 'public/index.html'
$postsPath = Join-Path $Root 'public/posts/index.html'
$archivesPath = Join-Path $Root 'public/archives/index.html'
$searchPath = Join-Path $Root 'public/search/index.html'
$tagsPath = Join-Path $Root 'public/tags/index.html'
$postPath = Join-Path $Root 'public/posts/claude-code-agent-teams/index.html'

foreach ($path in @($indexPath, $postsPath, $archivesPath, $searchPath, $tagsPath, $postPath)) {
  if (-not (Test-Path $path)) {
    throw "Expected generated file missing: $path"
  }
}

$index = Get-Content -Raw -Encoding UTF8 $indexPath
$post = Get-Content -Raw -Encoding UTF8 $postPath

Assert-Contains $index 'class="brand-home"' 'custom home wrapper'
Assert-Contains $index '与 AI 共建的工程化笔记' 'hero headline'
Assert-Contains $index '能力地图' 'skills section'
Assert-Contains $index '专题 / 作品' 'projects section'
Assert-Contains $index '最新文章' 'latest posts section'
Assert-Contains $index '工具箱 / 实验' 'toolbox section'
Assert-Contains $index '联系' 'contact section'
Assert-Contains $index 'RAG 系列' 'RAG project'
Assert-Contains $index 'Claude Code 工作流' 'Claude project'
Assert-Contains $index 'Agent 范式' 'Agent project'
Assert-Contains $index 'assets/css/stylesheet' 'bundled stylesheet'
Assert-NotContains $index 'profile_inner' 'PaperMod profile home'
Assert-NotContains $index '棣栭〉' 'garbled home navigation'
Assert-NotContains $index '涓汉' 'garbled Chinese description'
Assert-Contains $post 'giscus.app/client.js' 'Giscus comments'
Assert-Contains $post 'Claude Code Agent Teams' 'existing article page'

Write-Host 'Redesign verification passed.'
```

- [ ] **Step 2: Run verifier and confirm RED**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-redesign.ps1
```

Expected: `hugo --minify` may pass, then the verifier fails with `Missing custom home wrapper`.

- [ ] **Step 3: Commit verifier**

```powershell
git add -- scripts/verify-redesign.ps1
git commit -m "test: add redesign smoke verifier"
```

## Task 2: Repair Hugo Configuration

**Files:**
- Modify: `hugo.yaml`

- [ ] **Step 1: Replace garbled configuration with UTF-8 Chinese content**

Rewrite `hugo.yaml` to keep the existing Hugo/PaperMod behavior while adding `params.home` data for the new homepage. Preserve the existing Giscus identifiers exactly.

- [ ] **Step 2: Run verifier**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-redesign.ps1
```

Expected: still fails because `layouts/index.html` and `brand.css` are not implemented, but no YAML parse errors occur.

- [ ] **Step 3: Commit configuration**

```powershell
git add -- hugo.yaml
git commit -m "config: prepare blog redesign content"
```

## Task 3: Build Custom Home Template

**Files:**
- Create: `layouts/index.html`

- [ ] **Step 1: Add homepage template**

Create a Hugo template that defines `main`, wraps all content in `class="brand-home"`, renders the hero/about/skills/projects/latest/toolbox/contact sections, reads section data from `site.Params.home`, and pulls recent posts from `.Site.RegularPages`.

- [ ] **Step 2: Run verifier**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-redesign.ps1
```

Expected: fails only on visual/CSS-related or remaining content assertions, not on missing `brand-home`.

- [ ] **Step 3: Commit template**

```powershell
git add -- layouts/index.html
git commit -m "feat: add editorial home template"
```

## Task 4: Add Brand Styles

**Files:**
- Create: `assets/css/extended/brand.css`

- [ ] **Step 1: Add PaperMod extended CSS**

Create CSS tokens and responsive styles for the warm editorial brand. Include selectors for `body`, `.header`, `.brand-home`, `.brand-hero`, `.brand-section`, `.brand-card`, `.brand-project`, `.brand-article`, `.brand-toolbox`, and `.brand-contact`.

- [ ] **Step 2: Run verifier**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-redesign.ps1
```

Expected: verifier passes.

- [ ] **Step 3: Commit styles**

```powershell
git add -- assets/css/extended/brand.css
git commit -m "style: add warm editorial blog theme"
```

## Task 5: Render Check And Final Polish

**Files:**
- Modify if needed: `hugo.yaml`
- Modify if needed: `layouts/index.html`
- Modify if needed: `assets/css/extended/brand.css`

- [ ] **Step 1: Start local Hugo server**

Run:

```powershell
hugo server -D --bind 127.0.0.1 --port 1313
```

Expected: server reports a local URL at `http://127.0.0.1:1313/`.

- [ ] **Step 2: Inspect key generated pages**

Check:

```text
http://127.0.0.1:1313/
http://127.0.0.1:1313/posts/
http://127.0.0.1:1313/archives/
http://127.0.0.1:1313/search/
http://127.0.0.1:1313/posts/claude-code-agent-teams/
```

Expected: homepage is the new portal, lists still work, article pages still show comments.

- [ ] **Step 3: Run final verifier**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-redesign.ps1
git status --short
```

Expected: verifier passes. Git status should only show intentional uncommitted polish, plus any pre-existing untracked `AGENTS.md`.

- [ ] **Step 4: Commit polish**

```powershell
git add -- hugo.yaml layouts/index.html assets/css/extended/brand.css scripts/verify-redesign.ps1
git commit -m "polish: verify redesigned blog experience"
```

Skip the final commit if there are no changes since previous task commits.

## Self-Review

- Spec coverage: the plan covers configuration repair, custom homepage, visual system, preservation of posts/search/archive/tags/comments, and repeatable verification.
- Placeholder scan: no unresolved placeholders or future-only implementation steps remain.
- Type consistency: the verifier checks strings that the template/config will emit, and the CSS class names are shared by the template and stylesheet tasks.
