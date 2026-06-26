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
