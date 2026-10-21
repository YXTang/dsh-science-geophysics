#!/usr/bin/env bash
# dsh-science-geophysics 校验入口。默认跑五类真校验（CI 可跑、不改已装 DSH、不联网）：
#   1) 引用名解析  —— package.json / cordis.patch.yml / preset/agent.cordis.yml / scripts/*.mjs 里
#                    出现的每个 @deepseek-ai/dsh-* 名称逐个查已装目录；@deepseek-ai/dsh（宿主自身）豁免。
#   2) 技能 frontmatter —— 12 个 skills/*/SKILL.md 的 frontmatter 必须可解析，requires 键名
#                    必须 ⊆ {python,conda,pip,cli,tools,services}，requires.tools 里的每个 id
#                    必须能在 preset/agent.cordis.yml 找到对应行。
#   3) envs/environment.yml —— 必须是合法 YAML 且含 name / channels / dependencies。
#   4) smoke-test  —— node scripts/smoke-test.mjs，失败计数非 0 即判失败。
#   5) cordis.patch.yml preset 声明 —— 必须能被 YAML 解析；含 preset 声明行（loader 行 id
#                     preset-<config.id>）且 config.id / config.plugins 齐备；config.plugins 与
#                     preset/agent.cordis.yml 顶层行逐行对齐；plugins[].name 里出现的每个
#                     @deepseek-ai/* 都在已装目录中存在，每个 dsh-science-geophysics/* 子路径
#                     都对应仓库里真实存在的文件；两条 profile 引擎行必须是包子路径。
#
# 用法：
#   bash test/verify-bundle.sh                  # 五类校验（默认，约 3 秒，零网络）
#   npm run check                               # smoke-test + 本脚本（聚合入口）
#   VERIFY_E2E=1 bash test/verify-bundle.sh     # 追加端到端 bundle 安装验证（需 pnpm/dsh/网络）
#
# 环境变量：
#   DSH_SCOPE_DIR   指定已装 @deepseek-ai/* 目录（缺省自动探测 dsh 安装位置）
#   DSH_YAML_DIR    指定 DSH 自带 yaml 包目录（缺省自动探测；设为 none 或找不到即降级为内置极简解析，
#                   输出里会说明本次走了哪条路径）
#   VERIFY_E2E=1    追加端到端验证：pnpm pack + dsh plugin add 到隔离 profile 并引导启动
#
# 说明（端到端部分）：用 git+file 依赖安装以绕过 pnpm 对未发布 registry 包的供应链接收检查；
# 用 $DSH_HOME/cordis.patch.yml 把 webserver 端口改为 0（OS 分配），避免与运行中的 Web GUI(3080) 冲突。

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FAIL=0
WORK="$(mktemp -d "${TMPDIR:-/tmp}/dsh-sgp-verify-XXXXXX")"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

STATIC="$WORK/verify-static.mjs"
cat > "$STATIC" <<'NODEJS'

// 静态校验 1-3：引用名解析 / 技能 frontmatter / envs 环境文件。
// 由 test/verify-bundle.sh 生成为临时文件后执行（仓库保持零第三方依赖）。

import { promises as fsp, existsSync } from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { execSync } from 'node:child_process';

const ROOT = process.argv[2];
const REQUIRES_KEYS = ['python', 'conda', 'pip', 'cli', 'tools', 'services'];
const HOST = '@deepseek-ai/dsh';
const SCOPE_ROOT = '@deepseek-ai/';

let failures = 0;
const ok = (m) => console.log('   ✔ ' + m);
const bad = (m) => { failures++; console.log('   ✗ ' + m); };
const info = (m) => console.log('   ' + m);

// ── 已装 DSH 定位 ────────────────────────────────────────────────────
function isScopeDir(d) {
  return !!d && existsSync(path.join(d, 'dsh', 'package.json'));
}

function candidateScopes() {
  const out = [];
  const push = (d) => { if (!d) return; try { out.push(path.resolve(d)); } catch { /* 忽略非法路径 */ } };
  push(process.env.DSH_SCOPE_DIR);
  try {
    const npmRoot = execSync('npm root -g', { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim();
    if (npmRoot) push(path.join(npmRoot, SCOPE_ROOT));
  } catch { /* npm 不可用：忽略 */ }
  for (const entry of (process.env.PATH || '').split(path.delimiter)) {
    if (!entry) continue;
    let dir = entry;
    for (let i = 0; i < 5; i++) {
      push(path.join(dir, 'node_modules', SCOPE_ROOT));
      push(path.join(dir, SCOPE_ROOT));
      const parent = path.dirname(dir);
      if (parent === dir) break;
      dir = parent;
    }
  }
  // 便携版布局：<root>/nodejs/node.exe 与 <root>/npm-global/node_modules 同处一块盘。
  // 盘符会变，故按当前 node 的位置向上推，不写死某个盘符。
  const nodeDir = path.dirname(process.execPath);
  for (const up of ['..', path.join('..', '..')]) {
    push(path.join(nodeDir, up, 'npm-global', 'node_modules', SCOPE_ROOT));
  }
  if (process.env.APPDATA) push(path.join(process.env.APPDATA, 'npm', 'node_modules', '@deepseek-ai'));
  return [...new Set(out)];
}

function resolveScopeDir() {
  for (const c of candidateScopes()) if (isScopeDir(c)) return c;
  return null;
}

const scopeDir = resolveScopeDir();
if (!scopeDir) {
  console.log('   ✗ 未找到已装 @deepseek-ai/dsh —— 无法做引用名解析');
  console.log('     请用 DSH_SCOPE_DIR 指定含 dsh/ 的 @deepseek-ai 目录');
  console.log('\n静态校验结论：失败（1 项阻断：找不到已装 DSH）');
  process.exit(1);
}
const dshVersion = JSON.parse(await fsp.readFile(path.join(scopeDir, 'dsh', 'package.json'), 'utf8')).version;
info('已装 DSH ' + dshVersion + ' → ' + scopeDir);

// @deepseek-ai/* 的落点不止一处：本机 npm-global 形态把依赖嵌套在 dsh/node_modules 下，
// pnpm / hoisted 形态则与 dsh 平级。三处都查，命中任一处即算已装。
const pkgRoots = [...new Set([
  path.join(scopeDir, 'dsh', 'node_modules', SCOPE_ROOT),
  scopeDir,
  path.join(path.dirname(scopeDir), SCOPE_ROOT),
])].filter((d) => existsSync(d));
info('包搜索根：' + pkgRoots.join('  |  '));

// ── YAML 解析：优先用 DSH 自带 yaml 包，找不到则降级为内置极简解析 ──────
async function loadYaml() {
  if (process.env.DSH_YAML_DIR === 'none') return null;   // 自测降级路径用
  const dirs = [];
  const push = (d) => { if (d) dirs.push(d); };
  push(process.env.DSH_YAML_DIR);
  push(path.join(scopeDir, 'dsh', 'node_modules', 'yaml'));
  push(path.join(scopeDir, '..', 'yaml'));
  push(path.join(scopeDir, 'yaml'));
  for (const dir of dirs) {
    try {
      const pj = JSON.parse(await fsp.readFile(path.join(dir, 'package.json'), 'utf8'));
      const exp = pj.exports && pj.exports['.'];
      const entry = (typeof exp === 'string' ? exp : (exp && exp.node)) || pj.module || pj.main || 'index.js';
      const mod = await import(pathToFileURL(path.join(dir, entry)).href);
      const parse = mod.parse || (mod.default && mod.default.parse);
      if (typeof parse === 'function') return { mode: 'yaml 包 v' + pj.version + '（' + dir + '）', strict: true, parse, entry: path.join(dir, entry) };
    } catch { /* 换下一个候选 */ }
  }
  return null;
}

function stripQuotes(v) {
  if (v.length >= 2 && ((v[0] === '"' && v[v.length - 1] === '"') || (v[0] === "'" && v[v.length - 1] === "'"))) return v.slice(1, -1);
  return v;
}
function parseScalar(v) {
  const t = v.trim();
  if (t === '') return '';
  if (t.startsWith('[') && t.endsWith(']')) {
    const body = t.slice(1, -1).trim();
    return body === '' ? [] : body.split(',').map((s) => stripQuotes(s.trim())).filter((s) => s !== '');
  }
  if (t.startsWith('{') && t.endsWith('}')) {
    const body = t.slice(1, -1).trim();
    const obj = {};
    if (body) for (const kv of body.split(',')) {
      const i = kv.indexOf(':');
      if (i > 0) obj[stripQuotes(kv.slice(0, i).trim())] = parseScalar(kv.slice(i + 1));
    }
    return obj;
  }
  return stripQuotes(t);
}
// 极简 YAML 子集解析：只覆盖 SKILL.md frontmatter 与 environment.yml 用到的形态
// （顶层标量 / 一层嵌套映射 / 行内数组 / 块状数组）。不是完整 YAML 实现。
function minimalParse(text) {
  const lines = String(text).replace(/\t/g, '  ').split(/\r?\n/);
  let i = 0;
  const skipBlank = () => { while (i < lines.length && (!lines[i].trim() || lines[i].trim().startsWith('#'))) i++; };
  const indentOf = (s) => s.match(/^ */)[0].length;

  function parseList(indent) {
    const arr = [];
    while (i < lines.length) {
      const raw = lines[i];
      if (!raw.trim()) { i++; continue; }
      if (indentOf(raw) < indent || !/^\s*-(\s|$)/.test(raw)) break;
      const item = raw.replace(/^\s*-\s?/, '');
      if (/^[A-Za-z0-9_.-]+\s*:(\s|$)/.test(item)) {
        const key = item.split(':')[0].trim();
        const rest = item.replace(/^[A-Za-z0-9_.-]+\s*:/, '');
        i++;
        const obj = {};
        obj[key] = rest.trim() === '' ? [] : parseScalar(rest);
        if (i < lines.length && lines[i].trim() && indentOf(lines[i]) > indent && !/^\s*-(\s|$)/.test(lines[i])) {
          Object.assign(obj[key], parseBlock(indentOf(lines[i])));
        }
        arr.push(obj);
      } else {
        arr.push(parseScalar(item));
        i++;
      }
    }
    return arr;
  }

  function parseBlock(indent) {
    const obj = {};
    while (i < lines.length) {
      const raw = lines[i];
      if (!raw.trim() || raw.trim().startsWith('#')) { i++; continue; }
      const ind = indentOf(raw);
      if (ind < indent) break;
      const m = raw.match(/^\s*([A-Za-z0-9_.@\/-]+)\s*:\s*(.*)$/);
      if (!m) { i++; continue; }
      const key = stripQuotes(m[1]);
      const rest = m[2];
      i++;
      if (rest.trim() !== '') { obj[key] = parseScalar(rest); continue; }
      skipBlank();
      if (i < lines.length && indentOf(lines[i]) > indent) {
        obj[key] = /^\s*-(\s|$)/.test(lines[i]) ? parseList(indentOf(lines[i])) : parseBlock(indentOf(lines[i]));
      } else {
        obj[key] = null;
      }
    }
    return obj;
  }

  skipBlank();
  return lines.length ? parseBlock(indentOf(lines[0])) : {};
}

const yaml = await loadYaml();
info('YAML 解析路径：' + (yaml ? yaml.mode : '内置极简解析（未找到 DSH 自带 yaml 包：只做结构解析，不做完整 YAML 合法性校验）'));

function parseYaml(text, what) {
  if (yaml) {
    try { return yaml.parse(text); }
    catch (e) { bad(what + '：YAML 解析失败 —— ' + (e && e.message ? String(e.message).split('\n')[0] : e)); return null; }
  }
  const v = minimalParse(text);
  if (!v || typeof v !== 'object' || Array.isArray(v) || Object.keys(v).length === 0) { bad(what + '：内置极简解析未得到映射结构'); return null; }
  return v;
}

// ═══ 1/3 引用名解析 ═══════════════════════════════════════════════════
console.log('\n== 1/5 引用名解析（@deepseek-ai/dsh-* → 已装目录）==');
const sources = [
  { label: 'package.json', file: path.join(ROOT, 'package.json') },
  { label: 'cordis.patch.yml', file: path.join(ROOT, 'cordis.patch.yml') },
  { label: 'preset/agent.cordis.yml', file: path.join(ROOT, 'preset', 'agent.cordis.yml') },
];
for (const e of await fsp.readdir(path.join(ROOT, 'scripts'), { withFileTypes: true })) {
  if (e.isFile() && e.name.endsWith('.mjs')) sources.push({ label: 'scripts/' + e.name, file: path.join(ROOT, 'scripts', e.name) });
}

const NAME_RE = /@deepseek-ai\/dsh(?:-[a-z0-9][a-z0-9-]*)*/g;
const refs = new Map();
for (const src of sources) {
  const text = await fsp.readFile(src.file, 'utf8');
  text.split(/\r?\n/).forEach((line, idx) => {
    for (const m of line.matchAll(NAME_RE)) {
      const name = m[0];
      if (!refs.has(name)) refs.set(name, []);
      const where = src.label + ':' + (idx + 1);
      if (!refs.get(name).includes(where)) refs.get(name).push(where);
    }
  });
}
info('扫描 ' + sources.length + ' 个文件源：' + sources.map((s) => s.label).join(' / '));

let checked = 0, hostSites = 0;
const missing = [];
const resolvedNames = [];
for (const name of [...refs.keys()].sort()) {
  if (name === HOST) { hostSites += refs.get(name).length; continue; }
  checked++;
  const dirName = name.slice(SCOPE_ROOT.length);
  if (pkgRoots.some((root) => existsSync(path.join(root, dirName, 'package.json')))) resolvedNames.push(name);
  else missing.push([name, refs.get(name)]);
}
info('引用：' + HOST + '（宿主自身，豁免 ' + hostSites + ' 处）');
info('解析命中名称：' + resolvedNames.join(', '));
if (missing.length) {
  bad('引用名解析失败：' + missing.length + ' 个 @deepseek-ai/dsh-* 名称在包搜索根下均不存在');
  for (const [name, sites] of missing) info('   缺失 ' + name + '  ←  ' + sites.join(', '));
} else {
  ok('引用名解析通过：' + checked + ' 个 @deepseek-ai/dsh-* 名称全部命中已装目录');
}

// ═══ 2/3 技能 frontmatter ═════════════════════════════════════════════
console.log('\n== 2/5 技能 frontmatter（可解析 + requires 键白名单 + tools id 存在）==');
const presetText = await fsp.readFile(path.join(ROOT, 'preset', 'agent.cordis.yml'), 'utf8');
const presetIds = new Set([...presetText.matchAll(/^\s*-\s*id:\s*['"]?([A-Za-z0-9_.-]+)['"]?\s*$/gm)].map((m) => m[1]));
info('preset/agent.cordis.yml 中 ' + presetIds.size + ' 个 id 可作为 requires.tools 的落点');

const skillsDir = path.join(ROOT, 'skills');
const skillDirs = (await fsp.readdir(skillsDir, { withFileTypes: true })).filter((e) => e.isDirectory()).map((e) => e.name).sort();
let skillCount = 0, withRequires = 0, toolRefs = 0;
let skillFailuresBefore = failures;
for (const name of skillDirs) {
  const file = path.join(skillsDir, name, 'SKILL.md');
  if (!existsSync(file)) continue;
  skillCount++;
  const text = await fsp.readFile(file, 'utf8');
  const fm = text.match(/^\uFEFF?---\r?\n([\s\S]*?)\r?\n---(\r?\n|$)/);
  if (!fm) { bad('skills/' + name + '/SKILL.md：缺少 frontmatter（首行需为 ---）'); continue; }
  const data = parseYaml(fm[1], 'skills/' + name + '/SKILL.md frontmatter');
  if (!data) continue;
  if (typeof data.name !== 'string' || data.name !== name) bad('skills/' + name + '/SKILL.md：frontmatter name=' + JSON.stringify(data.name) + ' 与目录名不一致');
  if (typeof data.description !== 'string' || !data.description.trim()) bad('skills/' + name + '/SKILL.md：frontmatter 缺 description');
  const req = data.requires;
  if (req === undefined || req === null) { info('skills/' + name + '：无 requires 段（允许，跳过依赖校验）'); continue; }
  withRequires++;
  if (typeof req !== 'object' || Array.isArray(req)) { bad('skills/' + name + '：requires 必须是映射'); continue; }
  const unknown = Object.keys(req).filter((k) => !REQUIRES_KEYS.includes(k));
  if (unknown.length) bad('skills/' + name + '：requires 出现未允许的键 ' + unknown.join(', ') + '（只允许 ' + REQUIRES_KEYS.join('/') + '）');
  const tools = req.tools;
  if (tools === undefined) continue;
  if (!Array.isArray(tools)) { bad('skills/' + name + '：requires.tools 必须是数组'); continue; }
  for (const t of tools) {
    toolRefs++;
    if (typeof t !== 'string') { bad('skills/' + name + '：requires.tools 含非字符串项 ' + JSON.stringify(t)); continue; }
    if (!presetIds.has(t)) bad('skills/' + name + '：requires.tools 的 "' + t + '" 在 preset/agent.cordis.yml 中找不到对应 id 行');
  }
}
if (skillCount === 0) bad('skills/ 下没有找到任何 SKILL.md');
else if (failures === skillFailuresBefore) ok('技能 frontmatter 通过：' + skillCount + ' 个技能全部可解析，' + withRequires + ' 个 requires 段键名合法，' + toolRefs + ' 个 tools 引用全部命中 preset');
else info('技能 frontmatter：' + skillCount + ' 个技能已检查，问题见上面 ✗ 行');

// ═══ 3/3 envs/environment.yml ═════════════════════════════════════════
console.log('\n== 3/5 envs/environment.yml（合法 YAML + name/channels/dependencies）==');
const envFile = path.join(ROOT, 'envs', 'environment.yml');
if (!existsSync(envFile)) {
  bad('envs/environment.yml 不存在');
} else {
  const envText = await fsp.readFile(envFile, 'utf8');
  const env = parseYaml(envText, 'envs/environment.yml');
  if (env) {
    const problems = [];
    if (typeof env.name !== 'string' || !env.name.trim()) problems.push('缺少 name（或非字符串）');
    if (!Array.isArray(env.channels) || env.channels.length === 0) problems.push('缺少 channels（或非非空数组）');
    if (!Array.isArray(env.dependencies) || env.dependencies.length === 0) problems.push('缺少 dependencies（或非非空数组）');
    if (problems.length) bad('envs/environment.yml：' + problems.join('；'));
    else ok('envs/environment.yml 合法：name=' + env.name + '，channels ' + env.channels.length + ' 个，dependencies ' + env.dependencies.length + ' 条');
  }
}

// 把已装 DSH 定位结果交给第 5 类校验（cordis.patch.yml preset 声明），避免重复探测
if (process.env.VERIFY_ROOTS_OUT) {
  try {
    await fsp.writeFile(process.env.VERIFY_ROOTS_OUT, JSON.stringify({ scopeDir, pkgRoots, yamlEntry: yaml ? (yaml.entry || null) : null }), 'utf8');
  } catch (e) { info('提示：写不出定位结果（' + ((e && e.message) || e) + '），第 5 类校验将降级'); }
}

console.log('\n静态校验结论（第 1-3 类）：' + (failures ? '失败（' + failures + ' 项，见 ✗ 行）' : '引用名解析 / 技能 frontmatter / envs 环境文件 三类全部通过'));
process.exit(failures ? 1 : 0);

NODEJS

ROOTS_JSON="$WORK/roots.json"

echo "dsh-science-geophysics 校验（仓库根：$ROOT）"
VERIFY_ROOTS_OUT="$ROOTS_JSON" node "$STATIC" "$ROOT"
[ $? -eq 0 ] || FAIL=1

# ── 4/4 smoke-test ────────────────────────────────────────────────────
echo ""
echo "== 4/5 smoke-test（引擎逻辑 + 端到端循环 + 错误码 + 迁移）=="
SMOKE_LOG="$WORK/smoke.log"
if node "$ROOT/scripts/smoke-test.mjs" >"$SMOKE_LOG" 2>&1; then
  grep -E '结果:' "$SMOKE_LOG" | sed 's/^/   /'
  SUMMARY="$(grep -E '结果:' "$SMOKE_LOG" | tail -1)"
  if echo "$SUMMARY" | grep -qE '0 失败'; then
    echo "   ✔ 结论：smoke-test 通过（失败计数 0）"
  else
    echo "   ✗ 结论：smoke-test 失败计数非 0 —— $SUMMARY"
    FAIL=1
  fi
else
  echo "   ✗ 结论：smoke-test 非 0 退出（末尾输出如下）"
  tail -20 "$SMOKE_LOG" | sed 's/^/   /'
  FAIL=1
fi

# ── 5/5 cordis.patch.yml preset 声明 ─────────────────────────────────
echo ""
echo "== 5/5 cordis.patch.yml preset 声明（YAML + config.id/plugins + 包名/包子路径落点）=="
PATCH="$WORK/verify-patch.mjs"
cat > "$PATCH" <<'NODEJS'

// 校验 5：cordis.patch.yml —— YAML 合法 + preset 声明行齐备 + 引用落点真实存在。
// 由 test/verify-bundle.sh 生成为临时文件后执行（仓库保持零第三方依赖）。
// 已装 DSH 的定位结果由第 1-3 类校验写出（VERIFY_ROOTS_OUT），此处不重复探测。

import { promises as fsp, existsSync } from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const ROOT = process.argv[2];
const ROOTS_FILE = process.argv[3];
const SELF = 'dsh-science-geophysics';
const SELF_REL = SELF + '/';
const SELF_ENGINES = SELF + '/engines/';

let failures = 0;
const ok = (m) => console.log('   ✔ ' + m);
const bad = (m) => { failures++; console.log('   ✗ ' + m); };
const info = (m) => console.log('   ' + m);
const oneLine = (e) => String((e && e.message) || e).split('\n')[0];

let roots = null;
try { roots = JSON.parse(await fsp.readFile(ROOTS_FILE, 'utf8')); } catch { /* 第 1-3 类未跑成 */ }
if (!roots) {
  console.log('   ✗ 读不到已装 DSH 定位结果 —— 第 1-3 类校验未成功执行，无法核对包名落点');
  process.exit(1);
}
const pkgRoots = roots.pkgRoots || [];

let parse = null;
if (roots.yamlEntry) {
  try {
    const mod = await import(pathToFileURL(roots.yamlEntry).href);
    parse = mod.parse || (mod.default && mod.default.parse) || null;
  } catch { parse = null; }
}
info('YAML 解析路径：' + (parse ? 'DSH 自带 yaml 包（' + roots.yamlEntry + '）' : '未找到 yaml 包 —— 降级为文本结构校验'));

const patchFile = path.join(ROOT, 'cordis.patch.yml');
if (!existsSync(patchFile)) { console.log('   ✗ cordis.patch.yml 不存在'); process.exit(1); }
const patchText = await fsp.readFile(patchFile, 'utf8');
const srcText = await fsp.readFile(path.join(ROOT, 'preset', 'agent.cordis.yml'), 'utf8');
const srcIds = [...srcText.matchAll(/^- id:[ \t]*['"]?([A-Za-z0-9_.-]+)['"]?[ \t]*$/gm)].map((m) => m[1]);
if (!srcIds.length) bad('preset/agent.cordis.yml 里没解析出顶层 id 行（真源不可用）');

// ── 结构：顶层 patch 段 / insert 行 / preset 声明行 ──────────────────
let rows = null;
let preset = null;
let pluginRows = null;
if (parse) {
  try {
    const doc = parse(patchText, { logLevel: 'silent' });
    if (!Array.isArray(doc) || doc.length === 0) {
      bad('cordis.patch.yml 顶层不是非空数组（patch 形态应为 - insert: 列表）');
    } else {
      ok('YAML 解析通过：顶层 ' + doc.length + ' 个 patch 段');
      rows = doc.flatMap((r) => (r && Array.isArray(r.insert) ? r.insert : []));
      preset = rows.find((r) => r && r.name === '@deepseek-ai/dsh-agent-preset') || null;
      info('insert 行：' + rows.map((r) => (r && r.id) || '?').join(', '));
    }
  } catch (e) { bad('cordis.patch.yml：YAML 解析失败 —— ' + oneLine(e)); }
}

if (preset) {
  if (!/^preset-/.test(String(preset.id))) bad('preset 声明行的 id 应为 preset-<config.id>，实际 ' + JSON.stringify(preset.id));
  const cfg = preset.config || {};
  if (typeof cfg.id !== 'string' || !cfg.id.trim()) bad('preset 声明行缺 config.id');
  if (!Array.isArray(cfg.plugins) || cfg.plugins.length === 0) {
    bad('preset 声明行缺 config.plugins（缺失或为空）');
  } else {
    pluginRows = cfg.plugins;
    const ids = cfg.plugins.map((r) => (r && r.id));
    if (ids.length !== srcIds.length) bad('config.plugins 条数 ' + ids.length + ' != preset/agent.cordis.yml 顶层行数 ' + srcIds.length);
    const drift = ids.filter((x, i) => x !== srcIds[i]);
    if (drift.length) bad('config.plugins 的 id 序列与真源不一致：patch=' + JSON.stringify(ids) + ' 真源=' + JSON.stringify(srcIds));
    else if (ids.length === srcIds.length) ok('preset 声明行齐备：id=' + preset.id + '，config.id=' + cfg.id + '，config.plugins ' + ids.length + ' 行 = 真源 ' + srcIds.length + ' 行（id 序列一致）');
  }
} else if (parse) {
  bad('缺 preset 声明行：没有任何 insert 行的 name 是 @deepseek-ai/dsh-agent-preset');
} else {
  // 降级：未找到 yaml 包时至少做文本形态校验
  const hasRow = /^ {4}- id:[ \t]*['"]?preset-[A-Za-z0-9_.-]+['"]?[ \t]*$/m.test(patchText);
  const hasLoader = /^ {6}name:[ \t]*['"]?@deepseek-ai\/dsh-agent-preset['"]?[ \t]*$/m.test(patchText);
  if (hasRow && hasLoader) ok('preset 声明行存在（文本形态：insert 行的 id 为 preset-*，name 为 @deepseek-ai/dsh-agent-preset）');
  else bad('缺 preset 声明行（文本形态未同时命中 preset-* 行 id 与 @deepseek-ai/dsh-agent-preset）');
  if (/^ {8}id:[ \t]*['"]?[A-Za-z0-9_.-]+['"]?[ \t]*$/m.test(patchText)) ok('config.id 存在（文本形态）');
  else bad('preset 声明行缺 config.id（文本形态未命中）');
  const textIds = [...patchText.matchAll(/^ {10}- id:[ \t]*['"]?([A-Za-z0-9_.-]+)['"]?[ \t]*$/gm)].map((m) => m[1]);
  if (textIds.length !== srcIds.length) bad('config.plugins 行数 ' + textIds.length + ' != 真源顶层行数 ' + srcIds.length + '（文本计数）');
  else if (textIds.some((x, i) => x !== srcIds[i])) bad('config.plugins 的 id 序列与真源不一致（文本计数）');
  else ok('config.plugins ' + textIds.length + ' 行 = 真源 ' + srcIds.length + ' 行（文本计数）');
}

// ── 引用落点：@deepseek-ai/* 必须在已装目录；dsh-science-geophysics/* 必须是真实文件 ──
let names = [];
if (pluginRows) names = names.concat(pluginRows.map((p) => p && p.name));
if (rows) names = names.concat(rows.filter((r) => r && typeof r.name === 'string' && r.name.indexOf(SELF_ENGINES) === 0).map((r) => r.name));
if (preset) names.push('@deepseek-ai/dsh-agent-preset');
if (!names.length) names = [...patchText.matchAll(/^[ \t]*(?:- )?name:[ \t]*['"]?([^'"\n]+?)['"]?[ \t]*$/gm)].map((m) => m[1]);
names = [...new Set(names.filter((n) => typeof n === 'string' && n.trim()))];

const installed = [];
const bundled = [];
const builtin = [];
const missingPkg = [];
const missingSub = [];
for (const name of names) {
  if (/(^|[\s'"])\.\/engines\//.test(name)) { bad('仍存在相对路径引用（bundle 内不可解析）：' + name); continue; }
  if (name.charAt(0) === '@') {
    const parts = name.split('/');
    const scope = parts[0].slice(1);
    const pkg = parts[1];
    if (!pkg) { bad('包名不完整：' + name); continue; }
    if (scope !== 'deepseek-ai') { bad('未识别的 scope（本包只用 @deepseek-ai/*）：' + name); continue; }
    if (pkgRoots.some((root) => existsSync(path.join(root, pkg, 'package.json')))) installed.push(name);
    else missingPkg.push(name);
  } else if (name.indexOf(SELF_REL) === 0) {
    if (existsSync(path.join(ROOT, name.slice(SELF_REL.length)))) bundled.push(name);
    else missingSub.push(name);
  } else if (name.indexOf('cordis:') === 0) {
    builtin.push(name);   // 宿主内置 pseudo 插件（如 cordis:group），不走 node_modules 解析
  } else {
    bad('未识别的引用形态（应为 @deepseek-ai/* 或 ' + SELF_REL + '*）：' + name);
  }
}
if (missingPkg.length) bad('@deepseek-ai/* 在已装目录下不存在：' + missingPkg.join(', '));
if (missingSub.length) bad(SELF_REL + '* 子路径在仓库里不存在对应文件：' + missingSub.join(', '));
if (builtin.length) info('宿主内置 pseudo 插件 ' + builtin.length + ' 处（' + [...new Set(builtin)].join(', ') + '，由 cordis 自身提供，无需 node_modules 落点）');
if (!missingPkg.length && !missingSub.length && (installed.length || bundled.length)) {
  ok('引用落点全部命中：@deepseek-ai/* ' + installed.length + ' 个已装，' + SELF_REL + '* ' + bundled.length + ' 个子路径真实存在'
    + (builtin.length ? '，宿主内置 ' + builtin.length + ' 处豁免' : ''));
}

// ── 引擎只在 preset 内挂一次（包子路径），profile 层不得重复注册同一个包 ──
{
  const presetEngineNames = (pluginRows || [])
    .filter((p) => p && typeof p.name === 'string' && p.name.indexOf('/engines/') !== -1)
    .map((p) => p.name);
  for (const file of ['research-loop.mjs', 'artifact-registry.mjs']) {
    if (!presetEngineNames.includes(SELF_ENGINES + file)) bad('preset config.plugins 缺少引擎行或未用包子路径：' + file);
  }
  if (presetEngineNames.length === 2) ok('preset 内引擎行 2 条且均为包子路径：' + presetEngineNames.join(', '));

  const profileEngineNames = (rows || [])
    .filter((r) => r && typeof r.name === 'string' && r.name.indexOf('/engines/') !== -1)
    .map((r) => r.name);
  if (profileEngineNames.length) bad('profile 层重复注册了引擎行（同一包双层挂载会撞工具名）：' + profileEngineNames.join(', '));
  else ok('profile 层未重复注册引擎：引擎只随 preset 生效');
}

// ── 结论 ────────────────────────────────────────────────────────────
console.log('');
console.log('   ' + (failures
  ? '✗ 结论：cordis.patch.yml 有 ' + failures + ' 项问题（见上 ✗ 行）'
  : '✔ 结论：cordis.patch.yml preset 声明齐备 —— preset-geophysics（config.plugins ' + (pluginRows ? pluginRows.length : srcIds.length) + ' 行 = 真源 ' + srcIds.length + ' 行），@deepseek-ai/* 落点 ' + installed.length + ' 个全部已装，' + SELF_REL + '* 子路径 ' + bundled.length + ' 个全部存在，宿主内置 pseudo 插件 ' + builtin.length + ' 处豁免'));
process.exit(failures ? 1 : 0);

NODEJS
node "$PATCH" "$ROOT" "$ROOTS_JSON" || FAIL=1

# ── 可选：端到端 bundle 安装验证（VERIFY_E2E=1）──────────────────────
if [ "${VERIFY_E2E:-0}" = "1" ]; then
  echo ""
  echo "== +E2E 端到端 bundle 安装验证（VERIFY_E2E=1）=="
  if ! command -v pnpm >/dev/null 2>&1; then
    echo "   ✗ 需要 pnpm（端到端部分）"; FAIL=1
  elif ! command -v dsh >/dev/null 2>&1; then
    echo "   ✗ 需要 PATH 上的 dsh（端到端部分）"; FAIL=1
  else
    TMP="$(mktemp -d "${TMPDIR:-/tmp}/dsh-sgp-e2e-XXXXXX")"
    HOME_HOME="$TMP/home"; GIT_DIR="$TMP/repo"
    SAVED_DSH_HOME="${DSH_HOME:-}"
    export DSH_HOME="$HOME_HOME"
    e2e_rc=0

    echo "   [1/4] pnpm pack（模拟 npm 发布物）"
    if ( cd "$ROOT" && pnpm pack --pack-destination "$TMP" >/dev/null 2>&1 ); then
      TGZ="$(ls "$TMP"/*.tgz 2>/dev/null | head -1)"
      echo "      tarball: $(basename "$TGZ")"
      tar -tzf "$TGZ" | grep -E "engines/(research-loop|artifact-registry)\.mjs|cordis\.patch\.yml|preset/agent\.cordis\.yml|skills/[^/]+/SKILL\.md" | head -4 | sed 's/^/      /'
    else
      echo "      ✗ pnpm pack 失败"; e2e_rc=1
    fi

    if [ "$e2e_rc" -eq 0 ]; then
      echo "   [2/4] 本机 git 仓库（供 git+file 依赖）"
      git init -q "$GIT_DIR" || e2e_rc=1
      cp -R "$ROOT"/package.json "$ROOT"/cordis.patch.yml "$ROOT"/engines "$ROOT"/preset "$ROOT"/skills "$GIT_DIR/" || e2e_rc=1
      git -C "$GIT_DIR" add -A && git -C "$GIT_DIR" -c user.name=verify -c user.email=verify@local commit -qm "verify" || e2e_rc=1
    fi

    if [ "$e2e_rc" -eq 0 ]; then
      echo "   [3/4] 隔离 profile 安装 bundle"
      mkdir -p "$HOME_HOME"
      cat > "$HOME_HOME/cordis.patch.yml" <<'EOF'
# 验证专用：webserver 用 OS 分配端口，避免与运行中的 GUI(3080) 冲突
- id: webserver
  config:
    port: 0
EOF
      ADD_OUT="$(dsh plugin --profile web add "git+file://$GIT_DIR" 2>&1 || true)"
      echo "$ADD_OUT" | grep -E "Packages|Done" || true
      echo "$ADD_OUT" | tail -4 | sed 's/^/      /'
      node -e '
        const fs = require("node:fs");
        const d = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
        const b = (d.dsh && d.dsh.profile && d.dsh.profile.bundles) || [];
        if (!b.includes("dsh-science-geophysics")) { console.error("      ✗ 未入层栈: " + JSON.stringify(b)); process.exit(1); }
        console.log("      dsh-science-geophysics 已加入 bundles 层栈 ✓");
      ' "$HOME_HOME/profiles/web/package.json" || e2e_rc=1

      OUT="$(dsh --profile web --dump-config 2>&1 || true)"
      for row in science-research-loop science-artifact-registry; do
        if echo "$OUT" | grep -q "$row"; then echo "      行 $row 已合入组合 ✓"; else echo "      ✗ 行 $row 缺失"; e2e_rc=1; fi
      done
    fi

    if [ "$e2e_rc" -eq 0 ]; then
      echo "   [4/4] 引导启动（加载器解析 + apply）"
      BOOT_LOG="$TMP/boot.log"
      timeout 40 dsh --profile web >"$BOOT_LOG" 2>&1 || true
      if grep -qE "dsh-science-geophysics/engines|science-research-loop|science-artifact-registry" "$BOOT_LOG"; then
        echo "      ✗ 引导日志出现引擎相关错误："
        grep -E "dsh-science-geophysics/engines|science-research-loop|science-artifact-registry" "$BOOT_LOG" | head -5 | sed 's/^/      /'
        e2e_rc=1
      else
        echo "      无引擎加载错误（子路径导出解析 + apply 成功）✓"
      fi
    fi

    rm -rf "$TMP"
    if [ -n "$SAVED_DSH_HOME" ]; then export DSH_HOME="$SAVED_DSH_HOME"; else unset DSH_HOME; fi
    if [ "$e2e_rc" -ne 0 ]; then FAIL=1; echo "   ✗ 结论：端到端验证失败"; else echo "   ✔ 结论：端到端 bundle 安装验证通过"; fi
  fi
fi

# ── 汇总 ──────────────────────────────────────────────────────────────
echo ""
if [ "$FAIL" -ne 0 ]; then
  echo "✗ 校验失败：见上面以 ✗ 开头的结论行。"
  exit 1
fi
echo "✔ 全部五类校验通过（引用名解析 / 技能 frontmatter / envs 环境文件 / smoke-test / cordis.patch.yml preset 声明）。"

