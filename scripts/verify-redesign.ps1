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

function Assert-Matches {
  param(
    [string]$Content,
    [string]$Pattern,
    [string]$Label
  )

  if ($Content -notmatch $Pattern) {
    throw "Missing ${Label}: ${Pattern}"
  }
}

function Assert-NotMatches {
  param(
    [string]$Content,
    [string]$Pattern,
    [string]$Label
  )

  if ($Content -match $Pattern) {
    throw "Unexpected ${Label}: ${Pattern}"
  }
}

hugo --minify

$indexPath = Join-Path $Root 'public/index.html'
$postsPath = Join-Path $Root 'public/posts/index.html'
$archivesPath = Join-Path $Root 'public/archives/index.html'
$searchPath = Join-Path $Root 'public/search/index.html'
$tagsPath = Join-Path $Root 'public/tags/index.html'
$postPath = Join-Path $Root 'public/posts/claude-code-agent-teams/index.html'
$tocPostDir = Get-ChildItem (Join-Path $Root 'public/posts') -Directory | Where-Object { $_.Name -like 'agent*' } | Select-Object -First 1
if (-not $tocPostDir) {
  throw 'Expected generated Agent article directory missing.'
}
$tocPostPath = Join-Path $tocPostDir.FullName 'index.html'

foreach ($path in @($indexPath, $postsPath, $archivesPath, $searchPath, $tagsPath, $postPath, $tocPostPath)) {
  if (-not (Test-Path $path)) {
    throw "Expected generated file missing: $path"
  }
}

$index = Get-Content -Raw -Encoding UTF8 $indexPath
$post = Get-Content -Raw -Encoding UTF8 $postPath
$tocPost = Get-Content -Raw -Encoding UTF8 $tocPostPath

Assert-Contains $index 'class=brand-home' 'custom home wrapper'
Assert-Matches $index '\u4E0E AI \u5171\u5EFA\u7684\u5DE5\u7A0B\u5316\u7B14\u8BB0' 'hero headline'
Assert-Matches $index '\u80FD\u529B\u5730\u56FE' 'skills section'
Assert-Matches $index '\u4E13\u9898 / \u4F5C\u54C1' 'projects section'
Assert-Matches $index '\u6700\u65B0\u6587\u7AE0' 'latest posts section'
Assert-Matches $index '\u5DE5\u5177\u7BB1 / \u5B9E\u9A8C' 'toolbox section'
Assert-Matches $index '\u8054\u7CFB' 'contact section'
Assert-Matches $index 'RAG \u7CFB\u5217' 'RAG project'
Assert-Matches $index 'Claude Code \u5DE5\u4F5C\u6D41' 'Claude project'
Assert-Matches $index 'Agent \u8303\u5F0F' 'Agent project'
Assert-Contains $index 'assets/css/stylesheet' 'bundled stylesheet'
Assert-NotContains $index 'profile_inner' 'PaperMod profile home'
Assert-NotMatches $index '\u68E3\u682D' 'garbled home navigation'
Assert-NotMatches $index '\u6D93' 'garbled Chinese description'
Assert-Contains $post 'giscus.app/client.js' 'Giscus comments'
Assert-Contains $post 'Claude Code Agent Teams' 'existing article page'
Assert-Contains $tocPost 'Table of Contents' 'article table of contents'

Write-Host 'Redesign verification passed.'
