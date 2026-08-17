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

echo "✔ 项目骨架已就绪：$ROOT"
echo "  目录：experiments/ literature/ artifacts/ analyses/ figures/ manuscript/ reviews/ data/ envs/"
echo "  台站清单：data/stations.csv（观测元数据唯一事实来源）"
echo "  设备清单：data/devices.tsv（标定/固件追溯）"
echo "  下一步：在地球物理模式会话中调用 research_init 建立研究清单（research-manifest.json）。"
