---
name: seismology-toolkit
description: 地震学分析工具箱：波形数据（MiniSEED/SEED/SAC）读取与质量控制、仪器响应（去响应/仿真）、震相拾取、事件定位、震级、震源机制、台阵处理、背景噪声与噪声成像、主动源监测。做地震学数据处理时使用。
whenToUse: 处理地震波形、事件定位、震相分析、台阵波束形成、背景噪声/PSD/噪声互相关、震源机制反演、主动源监测等任务时。
requires:
  python: ">=3.10,<3.13"
  conda: ["obspy>=1.4.2", "numpy>=1.26", "scipy>=1.11", "matplotlib>=3.7", "pyproj>=3.6", "segyio>=1.9.12", "gmt>=6.4", "pygmt>=0.11"]
  cli: ["sac"]
  tools: ["tool-bash", "tool-fs"]
  services:
    - "https://service.earthscope.org"
    - "https://earthquake.usgs.gov/fdsnws/event/1/"
    - "https://www.globalcmt.org/"
---

# 地震学工具箱（Seismology Toolkit）

面向天然地震学、台阵与背景噪声、主动源监测的地震数据处理协议。**软件版本与响应文件版本一律固定并记录到 envs/ 与实验 design.md**（默认规格 `envs/environment.yml`：ObsPy 下限 1.4.2、python 3.11）。

## 数据格式与读取

| 格式 | 说明 | 工具 |
| --- | --- | --- |
| MiniSEED | 波形最常用格式（连续记录/事件） | obspy.io.mseed / sac2mseed、rdseed（EarthScope 软件下载 https://ds.iris.edu/ds/nodes/dmc/software/downloads/ ） |
| SEED / dataless SEED | 波形+台站元数据（含仪器响应） | obspy.io.seed（resp/dataless） |
| StationXML | 现代台站元数据标准（含响应） | obspy.read_inventory（EarthScope FDSN：https://service.earthscope.org/fdsnws/station/1/ ） |
| SAC | 地震学传统格式（头段含事件/台站信息） | obspy.io.sac（读头段无需 SAC 可执行文件）/ SAC 命令需装 EarthScope 预编译包 —— conda-forge **没有** `sac` 包（`conda search sac` 实测无匹配） |
| SEG-Y | 主动源/勘探数据 | obspy.io.segy / segyio |

## 台站元数据与仪器响应

- 响应文件：SEED response（RESP 文件）、dataless SEED、StationXML 三种均可被 ObsPy 读取为 PAZ（poles/zeros）。
- 每次分析必须记录所用响应文件版本与来源（EarthScope FDSN 服务、本地 dataless、自测标定结果）。
- IRIS DMC 已并入 EarthScope：FDSN 新域 https://service.earthscope.org/fdsnws/ ，旧域 https://service.iris.edu/fdsnws/ 目前仍可解析；ObsPy ≥1.5.1 的默认服务映射为 EARTHSCOPE+USGS（dataselect/station 走 EarthScope，event 走 USGS）。
- 旧 `obspy.clients.iris` Web 服务客户端（evalresp 除外）已被 EarthScope 弃用并将在 2026 年内陆续退役，新代码统一用 `obspy.clients.fdsn`。
- 去仪器响应：`tr.remove_response(inventory=..., output="DISP"/"VEL"/"ACC", water_level=...)`；
  水位（water_level）越高对频带外噪声抑制越强，默认 60~100。**频带外去响应会放大噪声**，务必配合带通滤波。
- 仿真（把位移响应变为速度/加速度或其它传感器响应）：`tr.simulate()`（需另一传感器 PAZ）。

## 质量控制（任何分析之前）

1. 采样率一致性（同台站同通道各时段是否一致）；
2. 时间轴连续性：gap/overlap 检测（`st.get_gaps()`），时钟跳变（非整秒偏移）；
3. 毛刺/尖峰检测（差分阈值）、DC 偏移、削波（振幅达到满量程）；
4. 记录质量标记（quality 字段、错误/缺失块）；
5. 缺失元数据（无响应文件、无台站坐标）先补全再分析，绝不跳过。

## 预处理链（标准顺序）

去均值/去趋势 → 去尖峰（despike）→ 去仪器响应或仿真（若需）→ 带通滤波（零相位 filtfilt，注明频带与拐点阶数）→ 重采样（**先抗混叠滤波**，ObsPy 的 resample 内置 FIR 抗混叠）。每步命令与参数写入实验 log.md。

## 事件处理

- 事件目录：USGS 综合目录（FDSN event：https://earthquake.usgs.gov/fdsnws/event/1/ ，即原 NEIC 目录；`obspy.clients.neic` 域名已迁至 cwbp2.usgs.gov，新代码用 FDSN 客户端）、ISC（https://www.isc.ac.uk/ ）、GCMT/GlobalCMT（https://www.globalcmt.org/ ）、地方台网目录；记录目录版本与检索日期。
- 震相拾取：手动（SAC ppk / ObsPy 交互）或自动——经典 STA/LTA，或深度学习（PhaseNet 类模型，注意模型适用范围与训练数据）；拾取结果记录到时、质量、通道。
- 定位：Hypo71/HypoDD（双差）、NonLinLoc（非线性/贝叶斯）、Obspy 的 taup 走时表（iasp91/ak135 等速度模型）；记录速度模型与震相组合。
- 震级：地方震级 Ml（注意量规函数）、面波 Ms、体波 mb、矩震级 Mw（与震源机制关联）；记录量规/衰减公式。

## 震源机制

- 初动极性法（下半球投影）、P/S 振幅比、矩张量反演（gCAP、ISOLA、CMT 型反演）；记录速度模型、反演频带、网格搜索范围。
- 结果标注不确定性（方差降低、误差椭圆）；与目录（GCMT）交叉验证。

## 台阵处理

- 波束形成：延迟求和（time-domain beamforming）、FK 分析（频域），记录慢度网格与频带；
- 台阵响应函数计算（评估旁瓣/模糊）；backprojection 成像（粗网格震源扫描）。

## 背景噪声与噪声成像

- PSD：Welch 法分段谱平均（分段长度/重叠/窗函数固定），输出 dB 相对 (m/s²)²/Hz 或 (m/s)²/Hz；
- 噪声水平基准：与 Peterson（1993）NLNM/NHNM 对比，判断台站噪声等级；统计概率密度函数 PDF（McNamara & Buland 2004，参考 USGS 工具）；
- 噪声互相关：单台站分量互相关（ZZ/RR/TT）、归一化（one-bit / spectral whitening 选择要说明）、时窗滑动叠加；对称性检查（信号是否对称，非对称提示非平稳源）；
- 面波色散与成像：时频分析（FTAN/多滤波器）、频散曲线提取与误差、反演（surf96/geopsy）或直接层析；主动源（炮点/可控源）用 SEG-Y 与走时反演。
- 走时变化监测：coda wave interferometry（stretching / moving-window cross-spectral），用于速度变化监测（火山、断层带、水文）。

## 常见坑

- 时间标签错误（本地时 vs UTC、时区偏移、闰秒）——所有分析统一 UTC；
- 重采样前不抗混叠 → 高频混入；
- 去响应频带外噪声放大 → 先滤波再去响应或设水位；
- SAC 头段元数据（经纬度/事件参数）未填或填错；
- 相位命名与到达顺序（P/S/Lg/Rayleigh）混淆导致误拾取；
- 台站坐标系统（地理 vs UTM、WGS84 基准）不统一；
- 噪声互相关结果被强事件/仪器故障污染而未剔除；
- 谱估计参数（分段数、窗函数）不记录 → 结果不可比。

## 复现优先

每完成一个关键步骤，把命令、参数、软件与响应文件版本写入 log.md；最终结果（PSD/定位/机制/频散）用 artifact_save 归档（见 artifact-provenance）。
