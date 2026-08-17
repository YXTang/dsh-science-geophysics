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
