---
name: geomagnetism-toolkit
description: 地磁学数据分析工具箱：IAGA-2002/INTERMAGNET 数据读取与质量控制、地磁指数（Kp/Dst/SYM-H/AE）、磁暴事件分析、IGRF 正常场与磁异常、日变化 Sq、台站数据预处理。做地磁数据处理与空间天气分析时使用。
whenToUse: 处理地磁台站数据（分钟值/秒值）、计算或分析地磁指数、磁暴事件识别与分析、IGRF 计算、日变化分析、地磁仪器数据对比时。
requires:
  python: ">=3.10,<3.13"
  conda: ["numpy>=1.26", "scipy>=1.11", "pandas>=2.0", "matplotlib>=3.7", "ppigrf>=2.0"]
  tools: ["tool-bash", "tool-fs"]
  services:
    - "https://intermagnet.org/data_download.html"
    - "https://imag-data.bgs.ac.uk/GIN_V1/"
    - "https://wdc.kugi.kyoto-u.ac.jp/"
    - "https://isgi.unistra.fr/"
    - "https://kp.gfz.de/"
    - "https://www.ncei.noaa.gov/products/international-geomagnetic-reference-field"
---

# 地磁学工具箱（Geomagnetism Toolkit）

面向地磁台站观测、磁暴与空间天气、地磁仪器数据的地磁分析协议。

## 数据格式与读取

| 格式 | 说明 | 来源/工具 |
| --- | --- | --- |
| IAGA-2002 | 地磁台站标准文本格式（分钟值，固定宽度列 XYZF/D/H/I） | INTERMAGNET/WDC；用自研解析（固定列宽：日期时间 + 3~4 分量） |
| IAGA-2002 秒值 | 高采样台站数据 | 台站/数据中心 |
| INTERMAGNET definitive/quasi-definitive/variational | 级别标注（D 终值/Q 准终值/V 变化值） | INTERMAGNET 数据下载（https://intermagnet.org/data_download.html）、GIN 检索服务（https://imag-data.bgs.ac.uk/GIN_V1/） |
| 指数数据 | Dst/SYM-H/AE/Kp/Ap 时间序列 | WDC Kyoto、ISGI（EOST）、NOAA/NCEI（地址见"数据源清单"） |

- IAGA-2002 头段：固定格式（DATA FORMAT IAGA-2002、站名、纬度/经度/高程、仪器说明、注释行）；数据列固定宽度，缺测用 99999.0（或 9999.0 秒值）。解析时严格按列宽，不要用空格分词。
- 分量约定：X（北）、Y（东）、Z（下）、H（水平强度）、F（总强度）、D（磁偏角，**单位角分**）、I（磁倾角）；记录单位（nT/deg）。

## 质量控制（任何分析之前）

1. 缺测与异常值：99999.0 缺测标记、超出物理范围（|X|>10^5 nT 等）剔除；
2. 尖峰检测（差分阈值）与去尖峰——**记录剔除清单**，不要静默修改；
3. 台阶（step）：仪器变更/传感器旋转/重启导致的基线跳变——对照台站注释（station remarks）标注，分段处理；
4. 日变检查：连续多日同一台站日变化形态是否合理（平滑的 Sq 形态）；
5. 基线漂移：长期趋势是否与仪器漂移一致；与绝对观测（baseline）记录核对；
6. 时间轴：连续、无重复/缺失时段；秒值数据注意时间标签（UTC）。

## 地磁指数

- **K 指数**：由 3 小时段地磁活动计算（去 Sq 后的最大扰动幅度 → 分级 0-9，台站间阈值不同）；从本站数据算 K 需先去掉 Sq 日变化（以磁静日平均为基线）。
- **Kp**：全球行星 K 指数（多台站合成），官方来源 GFZ：https://kp.gfz.de/ （旧域 kp.gfz-potsdam.de 现重定向至此）；WDC Kyoto 亦有存档。
- **Dst/SYM-H**：赤道环电流指数（Dst 为小时值，SYM-H 为分钟值），磁暴主相负偏；来源 WDC Kyoto（Dst 终值 https://wdc.kugi.kyoto-u.ac.jp/dst_final/ ）与 ISGI（SYM-H，https://isgi.unistra.fr/data_download.php ）。
- **AE/AL/AU/AO**：极光电集流指数（分钟值），来源 WDC Kyoto（https://wdc.kugi.kyoto-u.ac.jp/dstae/ ）与 ISGI（https://isgi.unistra.fr/ ）。
- 指数下载命令与版本记录到 log.md；论文引用指数来源与日期。

## 磁暴分析

- 事件挑选：Dst ≤ -30 nT（弱磁暴）/-50（中等）/-100（强）/≤-200（特大）为常用分级；或 SYM-H ≤ -50 nT 持续阈值；
- 相位识别：初相（SSC/SI 急始）、主相（Dst 下降）、恢复相（回升至平静水平）；主相持续时间、最小 Dst 值与时刻；
- 与行星际条件关联：太阳风速度、IMF Bz 南向（ACE/DSCOVR L1 数据）、CME/CIR 源；
- 亚暴分析：AE 指数增强事件、极光区电流体系变化；
- 统计：磁暴目录（NOAA SWPC）、太阳活动周相位（太阳黑子数 SSN）、季节变化（罗素-麦克弗伦效应）。

## IGRF 正常场与磁异常

- IGRF-14（2025.0 起生效；上一代 IGRF-13 仍可查到）系数表：球谐系数 g/h、年变率；官方页面与官方软件包见 https://www.ncei.noaa.gov/products/international-geomagnetic-reference-field （IGRF14_0.zip / IGRF14_Windows.zip），Python 侧可直接用 `ppigrf`（conda-forge 与 PyPI 均有，≥2.0）；计算正常场（地心/地固坐标、海拔修正）；
- 台站观测减去 IGRF 正常场 → 地磁异常（区域异常/剩磁）；
- 注意：IGRF 用于扣除**地球内部主磁场**，不扣除外部场（磁层/电离层）；研究外部场用指数与太阳风数据。
- 长期变化（secular variation）：多年均值变化趋势，与 IGRF 年变率对比。

## 日变化 Sq 与扰动场

- Sq（太阳静日变化）：磁静日（Kp ≤ 1-2）同季节多日平均的日变化形态，随纬度/季节变化；
- 扰动场 = 观测 - Sq - IGRF（或 - 台站基线）；不同分量（X/Y/Z）扰动形态不同（电离层电流体系）；
- 夜间时段（当地 22-06 时）扰动较小，适合基线/本底评估。

## 数据源清单

- INTERMAGNET：https://intermagnet.org/data_download.html （definitive/quasi-definitive 数据下载）、GIN 检索服务 https://imag-data.bgs.ac.uk/GIN_V1/ 、格式说明 https://intermagnet.org/data_formats.html 、数据检查工具 https://intermagnet.org/data_checkers.html
- WDC Kyoto（京都地磁数据中心）：https://wdc.kugi.kyoto-u.ac.jp/ （Dst/AE/Kp 指数与台站数据；Dst 终值 https://wdc.kugi.kyoto-u.ac.jp/dst_final/ ）
- ISGI（EOST/Strasbourg，原 CETP）：https://isgi.unistra.fr/data_download.php （SYM-H/ASY/AE 官方指数）
- Kp 官方：GFZ https://kp.gfz.de/
- NOAA/NCEI：IGRF 与地磁产品 https://www.ncei.noaa.gov/products/international-geomagnetic-reference-field ；太阳风/行星际条件用 CDAWeb https://cdaweb.gsfc.nasa.gov/
- USGS 地磁台网、BGS 地磁服务（https://geomag.bgs.ac.uk/ ）、中国地震局地磁台网
- IGRF 系数：同 NCEI 产品页（当前 IGRF-14，2025.0 起）；旧的 ngdc.noaa.gov/IAGA/vmod/igrf.html 已不可达，勿再引用

## 常见坑

- IAGA-2002 固定列宽解析错误（空格分词会错位）；
- D 分量单位（角分 vs 度）混淆；
- 缺测值 99999.0 未剔除当真实数据用；
- 仪器变更/台阶未标注，直接跨段做统计 → 虚假异常；
- 用 IGRF 解释外部场变化（IGRF 只含主磁场）；
- 线性插值跨越仪器变更时段；
- 分钟值/秒值时间基准不一致（UT vs LT、时区）；
- 磁静日定义不一致导致 Sq 基线不可比（应记录选择标准）；
- 引用已退役的站点路径：intermagnet.org 的 `data-donnee/download-eng.php` 已 404（现行路径 `/data_download.html`、`/gins.html`），`ngdc.noaa.gov/IAGA/vmod/igrf.html` 已不可达——一律用"数据源清单"里的地址。

## 复现优先

每步处理（剔除清单、去尖峰参数、基线选取、IGRF 系数版本——当前 IGRF-14，2025.0 起）写入 log.md；最终结果（指数时间序列、事件目录、异常图）用 artifact_save 归档。
