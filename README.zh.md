# dsh-science-geophysics

**面向 [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) 的地球物理科研工作台** —— 面向地震学 / 地磁学 / 观测仪器研发项目。基于 [dsh-science](https://github.com/biociao/dsh-science) 的领域无关引擎改造（引擎零依赖、与上游同步），人格与技能完全本地化为地球物理。

> 一句话介绍：**dsh-science-geophysics** —— Claude Science 式地球物理科研工作台：ReAct 研究循环引擎（research_* 工具）、带溯源的版本化工件（artifact_* 工具），以及面向地震学/地磁学/仪器研发的 12 个科研技能。

- **ReAct 研究循环引擎** —— `research_init` / `research_state` / `research_hypothesis` / `research_experiment` / `research_findings` / `research_phase` / `research_review` / `research_report`，状态持久化在 `research-manifest.json`（提问 → 假设 → 实验 → 观察 → 分析 → 结论 → 下一问题）。
- **版本化工件与溯源** —— `artifact_save` / `artifact_list` / `artifact_show` / `artifact_diff` / `artifact_verify` / `artifact_deprecate` / `artifact_reproduce`：结果存为 `artifacts/<name>/v<N>/`，附每文件 SHA-256、`artifact.json` 溯源（命令/输入/环境/envFile）与追加式 `provenance.md`。
- **12 个科研技能** —— research-loop、science-project-setup、artifact-provenance、scientific-reviewer、literature-connector、parallel-delegation、manuscript-writing、**seismology-toolkit（地震学）**、**geomagnetism-toolkit（地磁学）**、**instrument-dev（仪器研发）**、conda-environments、data-inventory。

两个引擎插件**零第三方依赖**（只用 Node 内置模块，共享 `engines/core.mjs`），注册标准 cordis 工具。
安装一次就够：`dsh plugin add` 装进 profile 后，本包携带的 preset 声明行让 DSH 新建会话时出现可选 preset
「地球物理模式」（dsh 0.2.1-rc.2 起 preset 不再是目录 —— 旧的 `$DSH_HOME/.agent-presets/<id>/` 机制已废弃）。

**已验证 DSH 版本：0.2.1-rc.2**（`peerDependencies: {"@deepseek-ai/dsh": ">=0.2.1-rc.2"}`）。
安装脚本（`scripts/install.sh` / `scripts/install.ps1`）先探测已装 `dsh` 版本：低于该下限时给出明确警告并要求确认，
非交互环境（CI / 管道）只警告、不阻塞、不退出。

### 相对上游的改造（fork patch）

- **人格**：科研人格改为地球物理（地震学/地磁学/仪器研发），会话协议保留；
- **技能**：bioinformatics-toolkit 替换为 seismology-toolkit / geomagnetism-toolkit / instrument-dev；literature-connector 权威源改为 AGU/SSA/GJI/EPSL/IEEE 与 IRIS/ISC/INTERMAGNET；其余通用技能示例本地化；
- **骨架**：init-project.sh 生成 `data/stations.csv`（台站清单）与 `data/devices.tsv`（设备/标定清单）；
- **加固**：`engines/core.mjs` 项目根自动探测增加主目录边界与深度上限（修复根探测逃逸到 `~/.dsh` 所在主目录的问题）；测试脚本修复 Windows ESM 路径（pathToFileURL）。

## 安装

一个 bundle 同时带来 profile 层引擎与 agent preset（无需再单独装 preset 目录）：

```bash
bash scripts/install.sh              # 按真源重生成 cordis.patch.yml -> npm pack -> dsh plugin --profile web add <tgz>
bash scripts/install.sh myprofile    # 装到指定 profile（或 DSH_PROFILE=myprofile）
```

手动等价（不想跑脚本时）：

```bash
node scripts/build-bundle-patch.mjs
npm pack
dsh plugin --profile web add ./dsh-science-geophysics-0.2.0.tgz
```

**装完怎么确认**（install.sh 会在安装前后都打印这三条）：

```bash
dsh plugin --profile web list                              # ① 应出现 dsh-science-geophysics
dsh --profile web --dump-config | grep -E 'preset-geophysics|dsh-science-geophysics/engines/'
                                                           # ② 应看到 preset-geophysics 声明行 + 两条引擎行
```

③ 重启 profile（或刷新 Web GUI）后新建会话，preset 选择器里应能选到 **地球物理模式**：
人格 + 引擎都在这条 preset 声明行里，按 agent 作用域隔离（未选该 preset 的会话不受影响）；
两条引擎 insert 行同时插进 profile 层栈，所以同 profile 的其他会话也能用 `research_*` / `artifact_*`。

> **机制背景**：dsh 0.2.1-rc.2 起 preset 不是目录，而是 bundle patch（`cordis.patch.yml`）里的一条
> `@deepseek-ai/dsh-agent-preset` 声明行（官方 skill 原文：*Nothing reads that directory any more.*）。
> `cordis.patch.yml` 是生成物：由 `scripts/build-bundle-patch.mjs`（`npm run build:patch`）从真源
> `preset/agent.cordis.yml` + `preset/preset.yml` 生成，幂等、勿手改。

### 技能

12 个技能由项目根 `.dsh/skills/` 自动发现（把本仓库 `skills/` 放进你的项目即可），
或全机安装：

```bash
bash scripts/install-skills.sh          # -> ~/.dsh/skills（遵循 $DSH_HOME）
```

每个 `SKILL.md` 的 frontmatter 带 `requires:` 段，声明 python / conda / pip / cli / tools / services 六类依赖
（`tools` 只填 preset 里真实存在的 `tool-*` id）；可复现环境规格见 `envs/environment.yml`
（由 `scripts/init-project.sh` 幂等生成：obspy / pygmt / ppigrf …）。`npm run check` 会校验 frontmatter 与 preset 的一致性。

## 快速开始（首个会话）

1. `research_init` —— 创建 `research-manifest.json` 与项目骨架（`experiments/ literature/ artifacts/ analyses/ figures/ manuscript/ reviews/ data/ envs/`）。
2. 每次会话先 `research_state`；循环状态跨会话持续。
3. 跑循环：`research_hypothesis`（H1/H2/…）→ `research_experiment`（E01/…）→ 写代码跑分析（波形去响应、PSD、定位、指数计算…）→ `research_findings`（追加 log.md、更新假设状态）→ 值得引用/复现的结果 `artifact_save`。
4. 关键论断：提取论断 → 评审子代理对照执行记录核查（scientific-reviewer）→ `research_review` 归档。
5. 领域细节见技能：波形/事件/台阵/噪声见 seismology-toolkit；地磁/指数/磁暴见 geomagnetism-toolkit；标定/采集/部署见 instrument-dev。

## 验证

```bash
npm run check                   # 聚合入口：smoke-test + verify-bundle（以下五类全绿才通过）
bash test/verify-bundle.sh      # 单独跑五类真校验（默认，约 3 秒，零网络）
VERIFY_E2E=1 bash test/verify-bundle.sh   # 追加端到端 bundle 安装验证（需 pnpm / dsh / 网络）

node scripts/smoke-test.mjs     # 引擎逻辑 + 端到端循环 + 错误码 + 迁移（62 项）
node scripts/stability-test.mjs # 并发 / 原子性 / 锁 / 压力稳定性检查（25 项）
```

`test/verify-bundle.sh` 是发布前的真校验，五类各自给出结论行：

1. **引用名解析** —— `package.json` / `cordis.patch.yml` / `preset/agent.cordis.yml` / `scripts/*.mjs` 里出现的每个
   `@deepseek-ai/dsh-*` 名称都必须在已装 DSH 里真实存在（`@deepseek-ai/dsh` 宿主自身豁免）；缺失逐个列出并以非 0 退出。
2. **技能 frontmatter** —— 12 个 `skills/*/SKILL.md` 的 frontmatter 可解析；`requires` 键名 ⊆ python/conda/pip/cli/tools/services；
   `requires.tools` 里每个 id 都能在 `preset/agent.cordis.yml` 找到对应行。
3. **envs/environment.yml** —— 合法 YAML 且含 name / channels / dependencies。
4. **smoke-test** —— `node scripts/smoke-test.mjs` 失败计数非 0 即判失败。
5. **cordis.patch.yml preset 声明** —— 必须能被 YAML 解析；含 preset 声明行
   （loader 行 id `preset-<config.id>`）且 `config.id` / `config.plugins` 齐备；`config.plugins`
   与 `preset/agent.cordis.yml` 顶层行逐行对齐；`plugins[].name` 里的每个 `@deepseek-ai/*` 都在已装目录中存在，
   每个 `dsh-science-geophysics/*` 子路径都对应仓库里真实存在的文件；两条 profile 引擎行必须是包子路径。

YAML 解析优先用 DSH 自带的 `yaml` 包，找不到时降级为内置极简解析并在输出里说明走了哪条路径。
全部测试脚本只写临时/指定工作区，不改已装 DSH、不联网，可在 CI 安全运行。

## 仓库结构

```
dsh-science-geophysics/
├── package.json          # dsh.bundle.patch -> ./cordis.patch.yml（含 exports）
├── cordis.patch.yml      # bundle patch（生成物，勿手改）：两条引擎 insert 行 + preset 声明行
├── engines/              # 引擎源（bundle 形态，领域无关，与上游 dsh-science 同步）
│   ├── core.mjs          #   共享核心：锁/原子写/错误码/流式哈希/结构化工具/审计（含 fork 加固）
│   ├── research-loop.mjs
│   └── artifact-registry.mjs
├── preset/               # preset 真源（cordis.patch.yml 由它生成）
│   ├── agent.cordis.yml  #   插件行真源：地球物理科研人格 + 引擎
│   ├── preset.yml        #   preset 的 name / description（「地球物理模式」）
│   └── engines/          #   镜像 —— 保持同步：bash scripts/sync-engines.sh
├── skills/               # 12 个 SKILL.md 技能（含 3 个地球物理领域技能）
├── scripts/
│   ├── build-bundle-patch.mjs # 由 preset/ 真源生成 cordis.patch.yml（幂等）
│   ├── install.sh        # npm pack -> dsh plugin --profile web add <tgz>
│   ├── install-skills.sh # 安装技能 -> ~/.dsh/skills
│   ├── sync-engines.sh   # 镜像 engines/ -> preset/engines/
│   ├── init-project.sh   # 项目骨架（台站/设备清单模板）
│   ├── smoke-test.mjs    # 62 项检查（临时工作区，node >= 18）
│   └── stability-test.mjs# 25 项并发/原子性/压力检查
├── envs/environment.yml  # conda 环境规格（init-project.sh 幂等生成，npm run check 校验）
├── test/verify-bundle.sh # 发布前五类真校验（引用名 / frontmatter / envs / smoke / patch preset 声明）
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
