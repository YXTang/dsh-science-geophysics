# dsh-science-geophysics 文档维护脚本（Windows PowerShell）
# 在插件安装/更新后运行：把使用说明与版本说明写入 DSH 全局目录
#   <DSH_HOME>/plugin-docs/dsh-science-geophysics/  （DSH_HOME 缺省 ~/.dsh）
# 生成：USAGE.md（使用说明）、CHANGELOG.md（版本说明=版本历史+安装/更新记录）、meta.json（事件记录）
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

# ── 使用说明（模板；改动时与本脚本内其它语言副本同步）──
$USAGE = @'
# dsh-science-geophysics 使用说明

**地球物理科研工作台**（DeepSeek Harness 插件）—— 面向地震学 / 地磁学 / 观测仪器研发。
基于 [dsh-science](https://github.com/biociao/dsh-science) 改造：引擎零依赖、与上游同步，人格与技能本地化为地球物理。

## 一、安装

| 形态 | 命令 | 说明 |
| --- | --- | --- |
| Profile bundle（引擎工具） | `dsh plugin --profile web add "github:YXTang/dsh-science-geophysics"` | 注册 `research_*` / `artifact_*` 工具到 profile 层栈，**重启 profile 生效** |
| Agent preset（地球物理模式） | `bash scripts/install.sh` 或 `powershell -File scripts/install.ps1` | 完整科研人格 + 引擎，按 agent 隔离 |
| 技能（12 个） | `bash scripts/install-skills.sh` 或 install.ps1（默认含） | 装入 `~/.dsh/skills`，新会话生效 |

升级：`dsh plugin --profile web update`（bundle）；`git pull` 后重跑 install 脚本（preset/技能）。

## 二、快速开始（首个会话）

1. 新建会话 → 选择预设 **「地球物理模式」**（或直接在任意会话使用 `research_*` 工具）。
2. `research_init` —— 创建研究清单 `research-manifest.json` 与项目骨架（experiments/ literature/ artifacts/ analyses/ figures/ manuscript/ reviews/ data/ envs/）。
3. 每次会话先 `research_state`；研究循环状态跨会话持续。
4. 跑循环：`research_hypothesis`（H1/…）→ `research_experiment`（E01/…）→ 写代码跑分析 → `research_findings`（记录发现、更新假设状态）→ 重要结果 `artifact_save` 归档。
5. 关键论断：`research_review` 归档评审；论文按 manuscript-writing 技能成稿。

## 三、工具清单

**研究循环（8 个）**：`research_init` `research_state` `research_hypothesis` `research_experiment` `research_findings` `research_phase` `research_review` `research_report`

**工件与溯源（7 个）**：`artifact_save` `artifact_list` `artifact_show` `artifact_diff` `artifact_verify` `artifact_deprecate` `artifact_reproduce`

**领域技能（12 个）**：research-loop · science-project-setup · artifact-provenance · scientific-reviewer · literature-connector · parallel-delegation · manuscript-writing · **seismology-toolkit（地震学）** · **geomagnetism-toolkit（地磁学）** · **instrument-dev（仪器研发）** · conda-environments · data-inventory

## 四、项目目录约定

| 目录 | 内容 | 入 git |
| --- | --- | --- |
| experiments/<id>/ | 实验：design.md / log.md / code/ / results/ | 代码入 |
| literature/ | 文献笔记 + references.bib | 入 |
| artifacts/<name>/ | 版本化工件：v<N>/ + artifact.json + provenance.md | 小文件入 |
| analyses/ · figures/ · manuscript/ · reviews/ · envs/ | 分析脚本/图表/论文/评审/环境 | 入 |
| data/ | 原始观测数据（波形/地磁分钟值） | **不入**，用 data-inventory 登记 |
| data/stations.csv | 台站清单（观测元数据唯一事实来源） | 入（元数据） |
| data/devices.tsv | 仪器/标定/固件清单 | 入 |

## 五、观测数据纪律（摘要）

- 波形（MiniSEED/SEED/SAC）与地磁（IAGA-2002）先做质量检查（元数据/采样率/时间轴/尖峰/台阶），再去仪器响应或正常场，再分析。
- 时间统一 UTC；台站/设备清单是唯一事实来源，元数据缺失先补全。
- 仪器测试（标定/温漂/噪声本底）记录环境条件 + 序列号 + 固件版本。
- 详见图谱：seismology-toolkit / geomagnetism-toolkit / instrument-dev。

## 六、常见问题

- **入口产物校验失败（broken）**：包已声明 `main` / `exports["."]`（index.mjs）。若旧版本仍报错，执行 `dsh plugin --profile web update` 拉取修复（≥ commit 56e2b72）后重启。
- **装了工具没出现**：bundle 层栈在启动时组合——**重启 profile**（`dsh --profile web`）生效。
- **项目根自动探测**：`research_init` 向上找 `.dsh`/`.git` 标记定位项目根（已加固：主目录边界 + 深度上限）。项目在 git 仓库内 → 根 = 仓库根。
- **安全审查门**：引擎零依赖、纯文件操作，可放心放行。

## 七、维护

- 上游同步：`git remote add upstream https://github.com/biociao/dsh-science.git` → fetch → 更新 engines/ → `bash scripts/sync-engines.sh`（core.mjs fork 补丁需重打）。
- 本说明文档的全局副本：`$DSH_HOME/plugin-docs/dsh-science-geophysics/`（由 scripts/update-docs.* 维护）。

'@

# ── 版本说明·静态部分（版本历史；改动时与其它语言副本同步）──
$CHANGELOG_BASE = @'
# dsh-science-geophysics 版本说明（CHANGELOG）

所有版本均为本 fork 的独立演进记录；引擎层（engines/）与上游 dsh-science 同步。

## 版本时间线

### v0.1.1 · fork 首版（2026-08-17）
基于 dsh-science v0.1.1 的地球物理化改造。

**新增**
- 地球物理科研人格「地球物理模式」（中文）：地震学/地磁学/仪器研发 + 观测数据纪律（台站清单、UTC、去响应、仪器测试记录）。
- 领域技能 3 个（替换 bioinformatics-toolkit）：
  - `seismology-toolkit`：波形（MiniSEED/SEED/SAC）、质量控制、去仪器响应/仿真、震相拾取、定位、震级、震源机制、台阵、背景噪声/PSD/噪声成像、主动源监测；
  - `geomagnetism-toolkit`：IAGA-2002/INTERMAGNET、质量检查、地磁指数（Kp/Dst/SYM-H/AE）、磁暴分析、IGRF、日变化 Sq、数据源清单；
  - `instrument-dev`：标定（灵敏度/频率响应/线性度）、环境测试（温漂）、DAQ（ADC/抗混叠/时钟）、时间同步、野外部署、仪器对比、固件版本管理。
- 通用技能本地化：literature-connector（AGU/SSA/GJI/EPSL/IEEE + IRIS/ISC/INTERMAGNET 数据服务）、conda-environments（conda-forge + obspy）、artifact-provenance / data-inventory / parallel-delegation / science-project-setup 示例改写。
- 项目骨架：`init-project.sh` 生成台站清单 `data/stations.csv` 与设备清单 `data/devices.tsv`。
- 安装脚本：`install.ps1`（Windows PowerShell）+ `install.sh`（bash）。

**修复（fork 加固，相对上游）**
- 项目根自动探测：增加**主目录边界**与**上溯深度上限**，修复 `~/.dsh` 存在时根被错误定位到用户主目录的问题（实测复现）。
- Windows 原子写：`rename` 遇到并发读方 EPERM 竞态时小退避重试（5 次）。
- 测试脚本 Windows 兼容：ESM 动态导入改用 `pathToFileURL`（修复 `ERR_UNSUPPORTED_ESM_URL_SCHEME`）。
- 测试演示本地化：端到端演练改为「台阵背景噪声与地磁日变化相关性」示例。

**行为变化**
- `release.yml` npm publish 默认禁用（fork 只创建 GitHub Release；如需发布 npm 见文件内注释）。
- 引擎领域默认值：`life-science` → `geophysics`。

**测试**：冒烟 62/62、稳定性 25/25 全部通过。

### v0.1.1 · 入口产物修复（2026-08-17，commit 56e2b72）
**修复**
- 声明包入口 `main: ./index.mjs` 与 `exports["."]`，新增 `index.mjs`（re-export 两引擎 apply 与共享核心）。
- 修复 dshmarket 安装校验报「声明的入口产物缺失（broken，下次启动失败）」：此前包仅有子路径导出、无主入口，校验回退查 `index.js` 不存在。

**影响**：需要 `dsh plugin --profile web update` 后重启 profile 生效。

'@

# ── 安装/更新事件记录（追加式，meta.json 为事实来源）──
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

# ── 写入全局文档 ──
Set-Content (Join-Path $docsDir "USAGE.md") $USAGE -Encoding UTF8
$lines = @($CHANGELOG_BASE, "", "---", "", "## 安装/更新记录", "")
foreach ($e in $meta.events) {
  $lines += ("- {0}  [{1}]  v{2}  {3}" -f $e.at, $e.kind, $e.version, $e.note)
}
($lines -join "`n") | Set-Content (Join-Path $docsDir "CHANGELOG.md") -Encoding UTF8

Write-Host ""
Write-Host "✔ 文档已写入 DSH 全局目录：$docsDir"
Write-Host "  - USAGE.md     使用说明"
Write-Host "  - CHANGELOG.md 版本说明（含安装/更新记录）"
Write-Host "  - meta.json    事件记录（最近：$kind v$version $Note）"