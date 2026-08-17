# dsh-science-geophysics Windows 安装脚本（PowerShell）
# 用法：powershell -ExecutionPolicy Bypass -File scripts/install.ps1
#  - 安装「地球物理模式」agent preset -> <DSH_HOME>/.agent-presets/geophysics
#  - 安装 12 个技能 -> <DSH_HOME>/skills（遵循 $env:DSH_HOME，缺省 $HOME/.dsh）
# 参数：-Mode copy|link（默认 copy；link 用符号链接，仓库即真身，改技能即时生效）
#       -SkillsOnly 只装技能；-PresetOnly 只装 preset
param(
  [ValidateSet("copy", "link")] [string]$Mode = "copy",
  [switch]$SkillsOnly,
  [switch]$PresetOnly
)

$ErrorActionPreference = "Stop"
$SRC = Resolve-Path (Join-Path $PSScriptRoot "..")
$DSH_HOME = if ($env:DSH_HOME) { $env:DSH_HOME } else { Join-Path $HOME ".dsh" }

if (-not $SkillsOnly) {
  $dstPreset = Join-Path $DSH_HOME ".agent-presets\geophysics"
  $srcPreset = Join-Path $SRC "preset"
  if (-not (Test-Path (Join-Path $srcPreset "agent.cordis.yml"))) { throw "preset/agent.cordis.yml 不存在：$srcPreset" }
  if (-not (Test-Path (Join-Path $srcPreset "engines\research-loop.mjs"))) { throw "preset/engines/ 缺失（先运行 bash scripts/sync-engines.sh）" }
  New-Item -ItemType Directory -Path (Join-Path $DSH_HOME ".agent-presets") -Force | Out-Null
  if (Test-Path $dstPreset) { Write-Host "警告：已存在 $dstPreset，正在移除（如有自定义请先备份）"; Remove-Item $dstPreset -Recurse -Force }
  if ($Mode -eq "link") {
    New-Item -ItemType SymbolicLink -Path $dstPreset -Target $srcPreset | Out-Null
    Write-Host "已符号链接：$dstPreset -> $srcPreset"
  } else {
    Copy-Item $srcPreset $dstPreset -Recurse -Force
    Write-Host "已复制：$srcPreset -> $dstPreset"
  }
}

if (-not $PresetOnly) {
  $dstSkills = Join-Path $DSH_HOME "skills"
  New-Item -ItemType Directory -Path $dstSkills -Force | Out-Null
  $count = 0
  foreach ($d in Get-ChildItem (Join-Path $SRC "skills") -Directory) {
    $skillMd = Join-Path $d.FullName "SKILL.md"
    if (Test-Path $skillMd) {
      $target = Join-Path $dstSkills $d.Name
      if (Test-Path $target) { Remove-Item $target -Recurse -Force }
      Copy-Item $d.FullName $target -Recurse -Force
      $count++
    }
  }
  Write-Host "已安装 $count 个技能到 $dstSkills"
}

Write-Host ""
Write-Host "✔ 安装完成。接下来："
Write-Host "  1. 在 DSH Web 新建会话，选择「地球物理模式」preset（或把默认 preset 设为 geophysics）。"
Write-Host "  2. 新会话中调用 research_init 初始化科研项目（技能 seismology-toolkit / geomagnetism-toolkit / instrument-dev）。"

# 安装时同步更新全局文档（使用说明 + 版本说明）
& (Join-Path $PSScriptRoot "update-docs.ps1") -Kind install -Note "install.ps1 安装 preset/技能"
