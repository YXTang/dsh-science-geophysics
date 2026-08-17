#!/usr/bin/env bash
# dsh-science-geophysics 文档维护脚本（bash / Linux / macOS）
# 在插件安装/更新后运行：把使用说明与版本说明写入全局可读位置
#   <DSH_HOME>/plugin-docs/dsh-science-geophysics/  （DSH_HOME 缺省 ~/.dsh）
# 用法：bash scripts/update-docs.sh [install|update] ["备注"]

set -euo pipefail
SRC="$(cd "$(dirname "$0")/.." && pwd)"
DSH_HOME="${DSH_HOME:-$HOME/.dsh}"
DOCS_DIR="$DSH_HOME/plugin-docs/dsh-science-geophysics"
mkdir -p "$DOCS_DIR"

VERSION="$(node -p "require('$SRC/package.json').version" 2>/dev/null || grep -o '"version"[^,]*' "$SRC/package.json" | head -1 | sed 's/.*: *"//;s/"//')"
KIND="${1:-auto}"
NOTE="${2:-}"

cp "$SRC/USAGE.md" "$DOCS_DIR/USAGE.md"
cp "$SRC/CHANGELOG.md" "$DOCS_DIR/CHANGELOG.md"

META="$DOCS_DIR/meta.json"
if [ -f "$META" ] && grep -q events "$META"; then
  [ "$KIND" = "auto" ] && KIND="update"
else
  [ "$KIND" = "auto" ] && KIND="install"
fi

# 用 node 维护 JSON（比 sed 可靠）
node -e '
  const fs = require("fs");
  const p = process.argv[1], kind = process.argv[2], ver = process.argv[3], note = process.argv[4];
  let m = fs.existsSync(p) ? JSON.parse(fs.readFileSync(p, "utf8")) : {};
  m.events = m.events || [];
  m.events.push({ at: new Date().toISOString(), kind, version: ver, note });
  m.version = ver; m.updatedAt = new Date().toISOString();
  fs.writeFileSync(p, JSON.stringify(m, null, 2) + "\n");
' "$META" "$KIND" "$VERSION" "$NOTE"

echo "✔ 文档已更新（全局可读）：$DOCS_DIR"
echo "  - USAGE.md / CHANGELOG.md / meta.json（最近：$KIND v$VERSION $NOTE）"
