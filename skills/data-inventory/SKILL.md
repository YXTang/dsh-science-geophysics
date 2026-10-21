---
name: data-inventory
description: 登记数据清单：来源、下载命令、校验值、授权与使用边界（生物数据常有授权/隐私限制）。涉及原始数据、公共数据库下载、大文件时使用。
whenToUse: 拿到新数据、下载公共数据、复现需要恢复数据、或需要说明数据来源时。
requires:
  tools: ["tool-fs"]
---

# 数据清单（Data Inventory）

`data/` 下的每个数据集都登记到 `data/README.md`（或 `data/manifest.tsv`），保证可追溯、可恢复、边界清晰。

## 登记条目（每份数据一条）

| 字段 | 说明 | 示例 |
| --- | --- | --- |
| id | 短标识 | `station01-2024` / `kak-min-2024` |
| 类型 | 原始/中间/公共/自产 | raw / public / derived |
| 来源 | 数据库/机构 + 标识 | IRIS FDSN / INTERMAGNET KAK / 自产 |
| 下载命令 | 可重跑 | `obspy-clients` 下载脚本 / INTERMAGNET ftp |
| 校验值 | sha256/md5（或 fastq 行数等替代） | sha256:abcd… |
| 大小 | 体积 | 4.2 GB |
| 授权 | 许可/使用边界 | NCBI 公开数据 / 课题组许可，禁止外传 |
| 状态 | 在用/已归档 | active |

模板：`data/manifest.tsv` 或 `data/README.md` 表格均可，**选一个保持统一**。

## 数据放置与版本库边界

- `data/` **不入 git**（大文件 + 隐私）；`.gitignore` 已排除。
- 大文件不放 artifacts：工件存"怎么得到这个结果"（命令+输入），数据本体留在 data/。
- 台站/观测清单（如 `data/stations.csv` 或 `data/devices.tsv`）是分析唯一事实来源（station_id 全局唯一、元数据与原始数据对应）。

## 授权与隐私纪律

- 台站/观测数据（波形、地磁）：公开数据中心（IRIS/INTERMAGNET）数据注明来源与版本；机构受控数据（如台网未发布数据、涉密台站）遵守授权协议，**不外传、不写入公开仓库**。
- 公共数据：记录 accession 与下载日期；论文引用数据库版本与检索日期。
- 涉密/受控数据（地震监测台网敏感信息、国防相关地磁数据）：按机构政策处理，默认不对外。
- 不确定授权 → 按最严格处理，并询问用户。

## 恢复与复现

- 数据丢失时按"来源 + 下载命令"恢复，恢复后核对校验值。
- 论文复现说明写：`数据见 data/README.md（含下载命令与校验值）`。

## 定期维护

- 每轮循环/每月：检查 data/README.md 是否覆盖所有在用数据；过期 accession 更新。
- 删除数据前先确认对应工件与论文引用不再需要，并留一条记录（删除日期 + 原因）。
