# dsh-science-geophysics 文档维护脚本（Windows PowerShell）
# 在插件安装/更新后运行：把使用说明与版本说明写入全局可读位置
#   <DSH_HOME>/plugin-docs/dsh-science-geophysics/  （DSH_HOME 缺省 ~/.dsh）
# 生成：USAGE.md（使用说明）、CHANGELOG.md（版本说明）、meta.json（安装/更新事件记录）
# 用法：
#   powershell -ExecutionPolicy Bypass -File scripts/update-docs.ps1
#   powershell -ExecutionPolicy Bypass -File scripts/update-docs.ps1 -Kind update -Note "dsh plugin update"
param(
  [ValidateSet("install", "update", "auto")] [string]$Kind = "auto",
  [string]$Note = ""
)

$ErrorActionPreference = "Stop"
$SRC = Resolve-Path (Join-Path $PSScriptRoot "..")
$DSH_HOME = if ($env:DSH_HOME) { $env:DSH_HOME } else { Join-Path $HOME ".dsh" }
$docsDir = Join-Path $DSH_HOME "plugin-docs\dsh-science-geophysics"
New-Item -ItemType Directory -Path $docsDir -Force | Out-Null

$pkg = Get-Content (Join-Path $SRC "package.json") -Raw | ConvertFrom-Json
$version = $pkg.version
$source = $pkg.repository.url -replace "^git\+", ""

# 1) 使用说明 + 版本说明
Copy-Item (Join-Path $SRC "USAGE.md") (Join-Path $docsDir "USAGE.md") -Force
Copy-Item (Join-Path $SRC "CHANGELOG.md") (Join-Path $docsDir "CHANGELOG.md") -Force

# 2) 安装/更新事件记录（追加式）
$metaPath = Join-Path $docsDir "meta.json"
$existing = Test-Path $metaPath
$meta = if ($existing) { try { Get-Content $metaPath -Raw | ConvertFrom-Json } catch { $null } } else { $null }
if ($null -eq $meta -or $null -eq $meta.events) {
  $kind = if ($Kind -eq "auto") { "install" } else { $Kind }
  $meta = [pscustomobject]@{
    name = $pkg.name
    version = $version
    source = $source
    docsDir = $docsDir
    events = @()
  }
} else {
  $kind = if ($Kind -eq "auto") { "update" } else { $Kind }
}
$evt = [pscustomobject]@{ at = (Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz"); kind = $kind; version = $version; note = $Note }
$meta.events = @($meta.events) + @($evt)
$meta.version = $version
$now = Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz"
if ($meta.PSObject.Properties.Name -notcontains "updatedAt") {
  $meta | Add-Member -NotePropertyName updatedAt -NotePropertyValue $now
} else {
  $meta.updatedAt = $now
}
$meta | ConvertTo-Json -Depth 6 | Set-Content $metaPath -Encoding UTF8

Write-Host ""
Write-Host "✔ 文档已更新（全局可读）：$docsDir"
Write-Host "  - USAGE.md    使用说明"
Write-Host "  - CHANGELOG.md 版本说明"
Write-Host "  - meta.json   安装/更新事件记录（最近一次：$kind v$version $Note）"
