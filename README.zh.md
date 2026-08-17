# dsh-science-geophysics

**面向 [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) 的地球物理科研工作台** —— 面向地震学 / 地磁学 / 观测仪器研发项目。基于 [dsh-science](https://github.com/biociao/dsh-science) 的领域无关引擎改造（引擎零依赖、与上游同步），人格与技能完全本地化为地球物理。

> 一句话介绍：**dsh-science-geophysics** —— Claude Science 式地球物理科研工作台：ReAct 研究循环引擎（research_* 工具）、带溯源的版本化工件（artifact_* 工具），以及面向地震学/地磁学/仪器研发的 12 个科研技能。

- **ReAct 研究循环引擎** —— `research_init` / `research_state` / `research_hypothesis` / `research_experiment` / `research_findings` / `research_phase` / `research_review` / `research_report`，状态持久化在 `research-manifest.json`（提问 → 假设 → 实验 → 观察 → 分析 → 结论 → 下一问题）。
- **版本化工件与溯源** —— `artifact_save` / `artifact_list` / `artifact_show` / `artifact_diff` / `artifact_verify` / `artifact_deprecate` / `artifact_reproduce`：结果存为 `artifacts/<name>/v<N>/`，附每文件 SHA-256、`artifact.json` 溯源（命令/输入/环境/envFile）与追加式 `provenance.md`。
- **12 个科研技能** —— research-loop、science-project-setup、artifact-provenance、scientific-reviewer、literature-connector、parallel-delegation、manuscript-writing、**seismology-toolkit（地震学）**、**geomagnetism-toolkit（地磁学）**、**instrument-dev（仪器研发）**、conda-environments、data-inventory。

两个引擎插件**零第三方依赖**（只用 Node 内置模块，共享 `engines/core.mjs`），注册标准 cordis 工具。
既可作 profile bundle 安装（`dsh plugin add`），也可作 agent preset（「地球物理模式」）安装。

### 相对上游的改造（fork patch）

- **人格**：科研人格改为地球物理（地震学/地磁学/仪器研发），会话协议保留；
- **技能**：bioinformatics-toolkit 替换为 seismology-toolkit / geomagnetism-toolkit / instrument-dev；literature-connector 权威源改为 AGU/SSA/GJI/EPSL/IEEE 与 IRIS/ISC/INTERMAGNET；其余通用技能示例本地化；
- **骨架**：init-project.sh 生成 `data/stations.csv`（台站清单）与 `data/devices.tsv`（设备/标定清单）；
- **加固**：`engines/core.mjs` 项目根自动探测增加主目录边界与深度上限（修复根探测逃逸到 `~/.dsh` 所在主目录的问题）；测试脚本修复 Windows ESM 路径（pathToFileURL）。

## 安装

### 方式 A —— profile bundle（社区标准）

```bash
# 从本地目录或 GitHub：
dsh plugin --profile web add "github:YXTang/dsh-science-geophysics"
# 或 npm 发布后：dsh plugin --profile web add dsh-science-geophysics
```

重启 profile（或刷新 Web GUI）。bundle 会把两个引擎插入 profile 层栈，
该 profile 上所有 agent 都能用 `research_*` / `artifact_*` 工具。

### 方式 B —— agent preset（完整「地球物理模式」，按 agent 隔离）

```bash
git clone <你的仓库> ~/.dsh/.agent-presets/geophysics
# 或本地安装：bash scripts/install.sh（或 bash scripts/install.sh link）
```

在 DSH Web 新建会话并选择 **地球物理模式** preset —— preset 自带科研人格 + 引擎，按 agent 作用域隔离。

### 技能

12 个技能由项目根 `.dsh/skills/` 自动发现（把本仓库 `skills/` 放进你的项目即可），
或全机安装：

```bash
bash scripts/install-skills.sh          # -> ~/.dsh/skills（遵循 $DSH_HOME）
```

## 快速开始（首个会话）

1. `research_init` —— 创建 `research-manifest.json` 与项目骨架（`experiments/ literature/ artifacts/ analyses/ figures/ manuscript/ reviews/ data/ envs/`）。
2. 每次会话先 `research_state`；循环状态跨会话持续。
3. 跑循环：`research_hypothesis`（H1/H2/…）→ `research_experiment`（E01/…）→ 写代码跑分析（波形去响应、PSD、定位、指数计算…）→ `research_findings`（追加 log.md、更新假设状态）→ 值得引用/复现的结果 `artifact_save`。
4. 关键论断：提取论断 → 评审子代理对照执行记录核查（scientific-reviewer）→ `research_review` 归档。
5. 领域细节见技能：波形/事件/台阵/噪声见 seismology-toolkit；地磁/指数/磁暴见 geomagnetism-toolkit；标定/采集/部署见 instrument-dev。

## 验证

```bash
node scripts/smoke-test.mjs     # 引擎逻辑 + 端到端循环 + 错误码 + 迁移（62 项）
node scripts/stability-test.mjs # 并发 / 原子性 / 锁 / 压力稳定性检查（25 项）
```

两个测试脚本只写临时/指定工作区，可在 CI 安全运行。

## 仓库结构

```
dsh-science-geophysics/
├── package.json          # dsh.bundle.patch -> ./cordis.patch.yml（含 exports）
├── cordis.patch.yml      # bundle patch：按子路径导出插入两个引擎
├── engines/              # 引擎源（bundle 形态，领域无关，与上游 dsh-science 同步）
│   ├── core.mjs          #   共享核心：锁/原子写/错误码/流式哈希/结构化工具/审计（含 fork 加固）
│   ├── research-loop.mjs
│   └── artifact-registry.mjs
├── preset/               # agent-preset 形态（engines 镜像，用 sync-engines.sh 同步）
│   ├── agent.cordis.yml  #   地球物理科研人格 + 引擎（相对路径挂载）
│   ├── preset.yml        #   「地球物理模式」
│   └── engines/          #   镜像 —— 保持同步：bash scripts/sync-engines.sh
├── skills/               # 12 个 SKILL.md 技能（含 3 个地球物理领域技能）
├── scripts/
│   ├── install.sh        # 安装 preset -> ~/.dsh/.agent-presets/geophysics
│   ├── install-skills.sh # 安装技能 -> ~/.dsh/skills
│   ├── sync-engines.sh   # 镜像 engines/ -> preset/engines/
│   ├── init-project.sh   # 项目骨架（台站/设备清单模板）
│   ├── smoke-test.mjs    # 62 项检查（临时工作区，node >= 18）
│   └── stability-test.mjs# 25 项并发/原子性/压力检查
└── docs/workspace-isolation.md  # DSH Web 会话隔离补丁说明（可选）
```

## 文档（全局可读）

插件使用说明与版本说明维护在 **DSH 全局目录**（非插件目录内）：

- `<DSH_HOME>/plugin-docs/dsh-science-geophysics/` —— USAGE.md（使用说明）、CHANGELOG.md（版本说明 + 安装/更新记录）、meta.json（事件记录）
- 安装/更新后运行 `scripts/update-docs.ps1`（Windows）或 `scripts/update-docs.sh`（bash）即刷新全局文档；`install.ps1`/`install.sh` 已自动调用。
- 每次运行追加一条安装/更新事件到 meta.json 与 CHANGELOG 的「安装/更新记录」节。

## 上游同步

引擎层与 [dsh-science](https://github.com/biociao/dsh-science) 保持一致：
```bash
git remote add upstream https://github.com/biociao/dsh-science.git
git fetch upstream && git checkout upstream/main -- engines/ && bash scripts/sync-engines.sh
```
注意：上游同步会覆盖 `engines/core.mjs`，需重打 fork 加固补丁（见文件内注释）。

## 许可

MIT —— 见 [LICENSE](LICENSE)。
