#!/usr/bin/env bash
# 安装「地球物理模式」agent preset 到某个 DSH profile。
#
# 现行机制（dsh 0.2.1-rc.2 起）：preset 不是目录，而是 bundle patch 里的一条
# @deepseek-ai/dsh-agent-preset 声明行；旧的 $DSH_HOME/.agent-presets/<id>/ 目录已经没有任何
# 东西读取（官方 skill editing-cordis-compositions 第 70 行）。所以安装方式就是装 bundle：
#   npm pack -> dsh plugin --profile <profile> add <tgz>
# 装完后本包携带的 preset 声明行让 DSH 出现可选 preset「地球物理模式」（人格 + 引擎 + 技能声明）。
#
# 用法：
#   bash scripts/install.sh                  # 装到 profile web（默认）
#   bash scripts/install.sh <profile>        # 装到指定 profile（或 DSH_PROFILE=<profile>）
# 说明：
#   - 安装前按真源重新生成 cordis.patch.yml（幂等：真源未变则字节一致），保证打进去的不是旧 patch。
#   - 安装前后都会打印如何确认（dsh plugin list / --dump-config / 新建会话选 preset）。
#   - 不写 $DSH_HOME 下的任何 preset 目录；preset 与引擎全部由本包携带。
#   - 技能另装：bash scripts/install-skills.sh
# 环境变量：
#   DSH_SKIP_VERSION_CHECK=1   跳过 DSH 版本探测（自担风险）
#   DSH_PROFILE=web            默认 profile（等价于第一个参数）
# ── 前置：已装 DSH 版本探测（peerDependencies 声明的下限）────────────────
# 语义比较（含 prerelease 如 0.2.1-rc.2）交给 node；只按声明值当下界比较。
read -r -d '' SEMVER_JS <<'JS' || true
const installed = process.argv[1], range = process.argv[2];
const p = (v) => {
  const m = String(v || '').trim().match(/^[v=~^><= ]*(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?/);
  return m ? { main: [+m[1], +m[2], +m[3]], pre: m[4] ? m[4].split('.') : null } : null;
};
const cmpPre = (a, b) => {
  if (!a && !b) return 0;
  if (!a) return 1;
  if (!b) return -1;
  const n = Math.max(a.length, b.length);
  for (let i = 0; i < n; i++) {
    const x = a[i], y = b[i];
    if (x === undefined) return -1;
    if (y === undefined) return 1;
    const nx = /^\d+$/.test(x), ny = /^\d+$/.test(y);
    if (nx && ny) { if (+x !== +y) return +x > +y ? 1 : -1; continue; }
    if (nx !== ny) return nx ? -1 : 1;
    if (x !== y) return x > y ? 1 : -1;
  }
  return 0;
};
const I = p(installed), R = p(range);
if (!I || !R) { console.log('unknown'); process.exit(0); }
let c = 0;
for (let i = 0; i < 3; i++) { if (I.main[i] !== R.main[i]) { c = I.main[i] > R.main[i] ? 1 : -1; break; } }
if (c === 0) c = cmpPre(I.pre, R.pre);
console.log(c >= 0 ? 'ok' : 'low');
JS

detect_dsh_version() {
  dsh --version 2>/dev/null | head -1 | tr -d '\r' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?' | head -1
}

PEER_RANGE="$(cd "$ROOT" && node -e 'const p=require("./package.json");process.stdout.write(((p.peerDependencies||{})["@deepseek-ai/dsh"])||"")' 2>/dev/null || true)"
# 用于升级提示：去掉比较符，得到裸版本号
PEER_HINT="${PEER_RANGE#>=}"
PEER_HINT="${PEER_HINT#^}"
PEER_HINT="${PEER_HINT#~}"

if [ "${DSH_SKIP_VERSION_CHECK:-0}" = "1" ]; then
  echo "已按 DSH_SKIP_VERSION_CHECK=1 跳过 DSH 版本探测。"
elif [ -z "$PEER_RANGE" ]; then
  echo "提示：package.json 未声明 @deepseek-ai/dsh 的 peerDependencies，跳过版本探测。"
else
  INSTALLED_DSH="$(detect_dsh_version || true)"
  if [ -z "$INSTALLED_DSH" ]; then
    echo "警告：PATH 上探测不到 dsh，无法校验版本；本包要求 @deepseek-ai/dsh $PEER_RANGE。" >&2
    echo "      若尚未安装：npm i -g @deepseek-ai/dsh@latest" >&2
  else
    VERDICT="$(node -e "$SEMVER_JS" "$INSTALLED_DSH" "$PEER_RANGE" 2>/dev/null || echo unknown)"
    if [ "$VERDICT" = "ok" ]; then
      echo "✔ 已装 DSH $INSTALLED_DSH 满足要求（peerDependencies: @deepseek-ai/dsh $PEER_RANGE）"
    elif [ "$VERDICT" = "low" ]; then
      echo "" >&2
      echo "⚠ 警告：已装 DSH $INSTALLED_DSH 低于本包要求 @deepseek-ai/dsh $PEER_RANGE。" >&2
      echo "  低于该版本的 DSH 可能缺少 preset / 隔离补丁引用的插件行" >&2
      echo "  （如 dsh-workflow-ptc、dsh-client-ui-workspace），装完 preset 可能加载失败。" >&2
      echo "  建议先升级：npm i -g @deepseek-ai/dsh@$PEER_HINT" >&2
      if [ -t 0 ] && [ -t 1 ]; then
        printf '仍要继续安装？[y/N] ' >&2
        ans=""
        read -r -t 20 ans || echo "" >&2
        case "$ans" in
          y|Y|yes|YES) echo "已确认，继续安装。" >&2 ;;
          *) echo "已取消安装。请升级 DSH 后重试。" >&2; exit 2 ;;
        esac
      else
        echo "非交互环境：只警告，继续安装（可用 DSH_SKIP_VERSION_CHECK=1 静默）。" >&2
      fi
    else
      echo "警告：无法比较 DSH 版本（$INSTALLED_DSH vs $PEER_RANGE，可能缺 node），继续安装。" >&2
    fi
  fi
fi


# ── 安装：npm pack + dsh plugin add ─────────────────────────────────────
PROFILE="$1"
[ -n "$PROFILE" ] || PROFILE="$DSH_PROFILE"
[ -n "$PROFILE" ] || PROFILE="web"

command -v node >/dev/null 2>&1 || { echo "错误：需要 node（生成 cordis.patch.yml）" >&2; exit 1; }
command -v npm  >/dev/null 2>&1 || { echo "错误：需要 npm（npm pack 打 tgz）" >&2; exit 1; }
command -v dsh  >/dev/null 2>&1 || { echo "错误：PATH 上找不到 dsh（dsh plugin add 需要它）" >&2; exit 1; }

echo ""

WORK="$(mktemp -d)"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

echo ""
echo "打包本仓库（npm pack）…"
if ! ( cd "$ROOT" && npm pack --pack-destination "$WORK" >/dev/null 2>&1 ); then
  echo "错误：npm pack 失败（检查 package.json 的 files 段）" >&2; exit 1
fi
TGZ="$(ls "$WORK"/*.tgz 2>/dev/null | head -1)"
[ -n "$TGZ" ] || { echo "错误：npm pack 没有产出 tgz" >&2; exit 1; }
echo "  tarball：$(basename "$TGZ")（$(wc -c < "$TGZ" | tr -d ' ') 字节）"
echo "  cordis.patch.yml：preset 声明行 $(grep -c 'id: preset-' "$ROOT/cordis.patch.yml") 条，插件行 $(grep -c '^            - id: ' "$ROOT/cordis.patch.yml") 条"

echo ""
echo "安装前，确认本包当前还没进 profile '$PROFILE' 的层栈："
echo "  dsh plugin --profile $PROFILE list                                   # 此时列表里不应有 dsh-science-geophysics"
echo "  dsh --profile $PROFILE --dump-config | grep -c preset-geophysics     # 期望 0"
echo ""
echo "安装到 profile '$PROFILE'（dsh plugin --profile $PROFILE add <tgz>）…"
if ! dsh plugin --profile "$PROFILE" add "$TGZ"; then
  echo "错误：dsh plugin add 失败" >&2; exit 1
fi

echo ""
echo "✔ 安装完成。安装后逐条确认："
echo "  1. dsh plugin --profile $PROFILE list"
echo "     → 列表里应出现 dsh-science-geophysics（bundles 层栈已收本包）"
echo "  2. dsh --profile $PROFILE --dump-config | grep -E 'preset-geophysics|science-research-loop|science-artifact-registry'"
echo "     → 应看到 preset-geophysics 声明行与两条 dsh-science-geophysics/engines/*.mjs 引擎行"
echo "  3. 重启 profile（或刷新 Web GUI）后新建会话 —— preset 选择器里应能选到「地球物理模式」"
echo "     （人格 + 引擎按 agent 作用域生效；未选该 preset 的会话不受影响）"
echo ""
echo "接下来："
echo "  1. 新会话中调用 research_init 初始化你的科研项目（技能 seismology-toolkit / geomagnetism-toolkit / instrument-dev）。"
echo "  2. 技能单独安装：bash scripts/install-skills.sh（装到 ~/.dsh/skills；或把 skills/ 放进项目 .dsh/skills）。"

echo "  同步更新全局文档（使用说明 + 版本说明）："
bash "$(dirname "$0")/update-docs.sh" install "install.sh 安装 bundle（profile: $PROFILE）"
