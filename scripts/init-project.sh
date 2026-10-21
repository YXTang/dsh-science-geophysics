#!/usr/bin/env bash
# 初始化地球物理科研项目目录骨架（无需地球物理模式会话也能用）。
# 等价于在地球物理模式会话中调用 research_init，后者还会创建研究清单与 README。
# 用法：scripts/init-project.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT"/{experiments,literature,artifacts,analyses,figures,manuscript,reviews,data,envs}

# data/README.md —— 数据清单模板
if [ ! -f "$ROOT/data/README.md" ]; then
  cat > "$ROOT/data/README.md" <<'EOF'
# 数据清单（Data Inventory）

每份数据登记一行：id、类型、来源、下载命令、校验值、大小、授权、状态。
详见技能 data-inventory。

| id | 类型 | 来源 | 下载命令 | 校验值 | 大小 | 授权 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
|  |  |  |  |  |  |  |  |
EOF
fi

# data/stations.csv —— 台站/观测清单（分析唯一事实来源）
# station_id 全局唯一；响应文件（PAZ/StationXML/标定报告）登记路径；缺测元数据先补全再分析。
if [ ! -f "$ROOT/data/stations.csv" ]; then
  cat > "$ROOT/data/stations.csv" <<'EOF'
station_id,latitude,longitude,elevation_m,sensor,digitizer,sample_rate_hz,response_file,orientation,install_date,last_cal_date,notes
EOF
fi

# data/devices.tsv —— 仪器/设备清单（标定与固件版本追溯）
# 每台设备（传感器/采集器/磁力仪）单独一行；固件升级前后各做一次标定并更新本表。
if [ ! -f "$ROOT/data/devices.tsv" ]; then
  cat > "$ROOT/data/devices.tsv" <<'EOF'
device_id	type	serial_no	firmware_version	calibration_date	sensitivity	notes
EOF
fi

# literature/references.bib —— 参考文献库
if [ ! -f "$ROOT/literature/references.bib" ]; then
  touch "$ROOT/literature/references.bib"
fi

# envs/environment.yml —— conda 可复现环境规格（地震 + 地磁两套场景共用）
# 已存在则不覆盖：项目通常已按自己的版本锁定，不能被初始化脚本回退。
if [ ! -f "$ROOT/envs/environment.yml" ]; then
  cat > "$ROOT/envs/environment.yml" <<'EOF'
# 地球物理科研项目环境规格（conda / mamba）
# 由 scripts/init-project.sh 幂等生成：文件已存在时不会被覆盖。
# 一个环境同时覆盖「地震（earthquake）」与「地磁（geomag）」两类分析场景。
#
# 版本策略：只写核对过确实存在的保守下限（conda-forge 索引），不追最新、不锁死补丁号；
# 需要逐补丁复现时另存锁文件：conda env export > envs/<env-name>.lock.yml
name: geophysics
channels:
  - conda-forge
dependencies:
  - python=3.11
  # ---- 公共基础：两类场景共用 ----
  - numpy>=1.26
  - scipy>=1.11
  - pandas>=2.0
  - matplotlib>=3.7
  # ---- 地震场景：波形 / 台站元数据 / SEG-Y / 出图 ----
  - obspy>=1.4.2        # 波形读取、去仪器响应、FDSN 客户端；1.4.2 起支持 numpy 2.x
  - pyproj>=3.6         # 坐标与投影
  - segyio>=1.9.12      # 主动源/勘探 SEG-Y（conda-forge 版略滞后于 PyPI）
  - gmt>=6.4            # 出图（GMT）
  - pygmt>=0.11         # GMT 的 Python 接口
  - sac>=103.0          # SAC 命令行：读 SAC 头段、ppk 交互拾取
  # ---- 地磁场景：台站数据 / 指数 / IGRF ----
  # IAGA-2002 与 INTERMAGNET 文本按列宽自研解析（见 skills/geomagnetism-toolkit），
  # 统计与出图复用上面的 numpy/scipy/pandas/matplotlib。
  - ppigrf>=2.0         # IGRF 正常场（当前 IGRF-14）
  - requests>=2.31      # 指数与台站数据下载
  - h5py>=3.10          # 部分数据中心提供 HDF5 格式
  - pip                 # 若需 PyPI 独占包，在下面追加 pip 小节并写带下限的约束
EOF
fi

echo "✔ 项目骨架已就绪：$ROOT"
echo "  目录：experiments/ literature/ artifacts/ analyses/ figures/ manuscript/ reviews/ data/ envs/"
echo "  台站清单：data/stations.csv（观测元数据唯一事实来源）"
echo "  设备清单：data/devices.tsv（标定/固件追溯）"
echo "  环境规格：envs/environment.yml（conda env create -f envs/environment.yml）"
echo "  下一步：在地球物理模式会话中调用 research_init 建立研究清单（research-manifest.json）。"
