# dsh-science-geophysics Windows 安装脚本（PowerShell）
# 用法：powershell -ExecutionPolicy Bypass -File scripts/install.ps1 [-Profile web] [-SkillsOnly] [-PresetOnly]
#  - 安装「地球物理模式」agent preset -> 装 bundle 到指定 profile（npm pack + dsh plugin add）。
#    现行机制（dsh 0.2.1-rc.2 起）：preset 不是目录，而是 bundle patch 里的一条
#    @deepseek-ai/dsh-agent-preset 声明行；旧的 $DSH_HOME/.agent-presets/<id>/ 目录已无人读取，
#    因此这里不再写任何 preset 目录。
#  - 安装 12 个技能 -> <DSH_HOME>/skills（遵循 $env:DSH_HOME，缺省 $HOME/.dsh）
#  - 安装前探测已装 dsh 版本（逻辑未改动）；低于 package.json 的 peerDependencies 下限时警告并要求确认。
#    stdin 被重定向（CI / 管道）时只警告、不退出、不阻塞。
# 参数：-Profile      目标 profile（默认 web）
#       -SkillsOnly   只装技能；-PresetOnly 只装 bundle（不装技能）
# 环境变量：DSH_SKIP_VERSION_CHECK=1 跳过 DSH 版本探测
param(
  [string]$Profile = "web",
  [switch]$SkillsOnly,
  [switch]$PresetOnly
)
$ErrorActionPreference = "Stop"
$SRC = Resolve-Path (Join-Path $PSScriptRoot "..")
$DSH_HOME_DIR = if ($env:DSH_HOME) { $env:DSH_HOME } else { Join-Path $HOME ".dsh" }

# ── 前置：已装 DSH 版本探测（peerDependencies 声明的下限）────────────────
# 语义比较（含 prerelease 如 0.2.1-rc.2）交给 node；只按声明值当下界比较。
$semverJs = @'
const installed = process.argv[1], range = process.argv[2];
const p = (v) => {
  const m = String(v || '').trim().match(/^[v=~^><= ]*(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?/);
  return m ? { main: [+m[1], +m[2], +m[3]], pre: m[4] ? m[4].split('.') : null } : null;
};
const cmpPre = (a, b) => {
  if (!a && !b) return 0;
  if (!a) return 1;
  if (!b) return -1;
  const n = Math.max(a.length, b.length);
  for (let i = 0; i < n; i++) {
    const x = a[i], y = b[i];
    if (x === undefined) return -1;
    if (y === undefined) return 1;
    const nx = /^\d+$/.test(x), ny = /^\d+$/.test(y);
    if (nx && ny) { if (+x !== +y) return +x > +y ? 1 : -1; continue; }
    if (nx !== ny) return nx ? -1 : 1;
    if (x !== y) return x > y ? 1 : -1;
  }
  return 0;
};
const I = p(installed), R = p(range);
if (!I || !R) { console.log('unknown'); process.exit(0); }
let c = 0;
for (let i = 0; i < 3; i++) { if (I.main[i] !== R.main[i]) { c = I.main[i] > R.main[i] ? 1 : -1; break; } }
if (c === 0) c = cmpPre(I.pre, R.pre);
console.log(c >= 0 ? 'ok' : 'low');
'@

$peer = $null
try { $peer = (Get-Content (Join-Path $SRC "package.json") -Raw | ConvertFrom-Json).peerDependencies.'@deepseek-ai/dsh' } catch { $peer = $null }
$peerHint = if ($peer) { ($peer -replace '^[v=~^><= ]*', '') } else { $peer }

$installed = $null
if (Get-Command dsh -ErrorAction SilentlyContinue) {
  $v = (& dsh --version 2>$null | Select-Object -First 1)
  if ($v -and ($v -match '[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?')) { $installed = $Matches[0] }
}

if ($env:DSH_SKIP_VERSION_CHECK -eq "1") {
  Write-Host "已按 DSH_SKIP_VERSION_CHECK=1 跳过 DSH 版本探测。"
} elseif (-not $peer) {
  Write-Host "提示：package.json 未声明 @deepseek-ai/dsh 的 peerDependencies，跳过版本探测。"
} elseif (-not $installed) {
  Write-Warning "PATH 上探测不到 dsh，无法校验版本；本包要求 @deepseek-ai/dsh $peer。"
  Write-Host "      若尚未安装：npm i -g @deepseek-ai/dsh@latest"
} else {
  $verdict = "unknown"
  try { $verdict = (& node -e $semverJs $installed $peer 2>$null | Select-Object -First 1) } catch { $verdict = "unknown" }
  if ($verdict -eq "ok") {
    Write-Host "✔ 已装 DSH $installed 满足要求（peerDependencies: @deepseek-ai/dsh $peer）"
  } elseif ($verdict -eq "low") {
    Write-Host ""
    Write-Warning "已装 DSH $installed 低于本包要求 @deepseek-ai/dsh $peer。"
    Write-Host "  低于该版本的 DSH 可能缺少 preset / 隔离补丁引用的插件行"
    Write-Host "  （如 dsh-workflow-ptc、dsh-client-ui-workspace），装完 preset 可能加载失败。"
    Write-Host "  建议先升级：npm i -g @deepseek-ai/dsh@$peerHint"
    if (-not [Console]::IsInputRedirected) {
      $ans = Read-Host "仍要继续安装？[y/N]"
      if ($ans -notmatch '^(y|Y|yes|YES)$') {
        Write-Host "已取消安装。请升级 DSH 后重试。" -ForegroundColor Yellow
        exit 2
      }
      Write-Host "已确认，继续安装。"
    } else {
      Write-Host "非交互环境：只警告，继续安装（可用 DSH_SKIP_VERSION_CHECK=1 静默）。"
    }
  } else {
    Write-Warning "无法比较 DSH 版本（$installed vs $peer，可能缺 node），继续安装。"
  }
}

if (-not $SkillsOnly) {
  Write-Host ""
  Write-Host "按真源重新生成 cordis.patch.yml（真源：preset/agent.cordis.yml + preset/preset.yml）…"
  & node (Join-Path $SRC "scripts\build-bundle-patch.mjs")
  if ($LASTEXITCODE -ne 0) { throw "cordis.patch.yml 生成失败" }

  if (-not (Get-Command npm -ErrorAction SilentlyContinue)) { throw "需要 npm（npm pack 打 tgz）" }
  if (-not (Get-Command dsh -ErrorAction SilentlyContinue)) { throw "PATH 上找不到 dsh（dsh plugin add 需要它）" }

  $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("dsh-sgp-install-" + [Guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Path $tmp -Force | Out-Null
  try {
    Write-Host ""
    Write-Host "打包本仓库（npm pack）…"
    Push-Location $SRC
    & npm pack --pack-destination $tmp | Out-Null
    $packCode = $LASTEXITCODE
    Pop-Location
    if ($packCode -ne 0) { throw "npm pack 失败（检查 package.json 的 files 段）" }
    $tgz = Get-ChildItem -Path $tmp -Filter *.tgz | Select-Object -First 1
    if (-not $tgz) { throw "npm pack 没有产出 tgz" }
    Write-Host "  tarball：$($tgz.Name)（$($tgz.Length) 字节）"

    Write-Host ""
    Write-Host "安装前，确认本包当前还没进 profile '$Profile' 的层栈："
    Write-Host "  dsh plugin --profile $Profile list"
    Write-Host "  dsh --profile $Profile --dump-config | Select-String preset-geophysics    # 期望无输出"
    Write-Host ""
    Write-Host "安装到 profile '$Profile'（dsh plugin --profile $Profile add <tgz>）…"
    & dsh plugin --profile $Profile add $tgz.FullName
    if ($LASTEXITCODE -ne 0) { throw "dsh plugin add 失败" }
  } finally {
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
  }
}

if (-not $PresetOnly) {
  $dstSkills = Join-Path $DSH_HOME_DIR "skills"
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
Write-Host "✔ 安装完成。安装后逐条确认："
Write-Host "  1. dsh plugin --profile $Profile list"
Write-Host "     → 列表里应出现 dsh-science-geophysics（bundles 层栈已收本包）"
Write-Host "  2. dsh --profile $Profile --dump-config | Select-String 'preset-geophysics|science-research-loop|science-artifact-registry'"
Write-Host "     → 应看到 preset-geophysics 声明行与两条 dsh-science-geophysics/engines/*.mjs 引擎行"
Write-Host "  3. 重启 profile（或刷新 Web GUI）后新建会话 —— preset 选择器里应能选到「地球物理模式」"
Write-Host "     （人格 + 引擎按 agent 作用域生效；未选该 preset 的会话不受影响）"
Write-Host ""
Write-Host "接下来："
Write-Host "  1. 新会话中调用 research_init 初始化科研项目（技能 seismology-toolkit / geomagnetism-toolkit / instrument-dev）。"
Write-Host "  2. 技能单独安装：powershell -ExecutionPolicy Bypass -File scripts/install.ps1 -SkillsOnly"

# 安装时同步更新全局文档（使用说明 + 版本说明）
& (Join-Path $PSScriptRoot "update-docs.ps1") -Kind install -Note "install.ps1 安装 bundle（profile: $Profile）"
