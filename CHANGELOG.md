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
