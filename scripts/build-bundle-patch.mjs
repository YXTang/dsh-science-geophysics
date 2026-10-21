#!/usr/bin/env node
// 生成仓库根的 cordis.patch.yml —— 由 preset/agent.cordis.yml（插件行真源）+ preset/preset.yml
// （name / description）派生。cordis.patch.yml 是生成物，勿手改：改真源后重新运行
//   node scripts/build-bundle-patch.mjs   （或 npm run build:patch）
//
// 为什么需要这一步：dsh 0.2.1-rc.2 起用户 preset 不再是 $DSH_HOME/.agent-presets/<id>/ 目录
// （官方 skill editing-cordis-compositions 第 70 行：Nothing reads that directory any more.），
// 而是 bundle patch 里的一条 @deepseek-ai/dsh-agent-preset 声明行。bundle 只能通过
// cordis.patch.yml 携带它，所以 preset 行必须由真源生成一份到 patch 里，两边不可能各写一份。

import { promises as fsp } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const SRC_AGENT = path.join(ROOT, 'preset', 'agent.cordis.yml');
const SRC_PRESET = path.join(ROOT, 'preset', 'preset.yml');
const OUT = path.join(ROOT, 'cordis.patch.yml');

const BUNDLE = 'dsh-science-geophysics';   // 包子路径前缀：profile 从 node_modules 解析
const PRESET_ID = 'geophysics';
const PRESET_LABEL = '';                   // 预留：名字取自 preset.yml
const PLUGIN_INDENT = ' '.repeat(10);      // plugins 行在 insert 结构里的缩进（- id: 层）
const ENGINE_RE = /^(\s*name:\s*)(['"]?)\.\/engines\/([^'"]+?)\2\s*$/;

const q = (v) => "'" + String(v).replace(/'/g, "''") + "'";
const tidy = (s) => s.replace(/[ \t]+$/, '');

// preset.yml 的单行标量（name / description）：够用即可，不做完整 YAML 解析
function scalarOf(text, key) {
  const m = new RegExp('^' + key + ':[ \t]*(.*)$', 'm').exec(text);
  if (!m) return '';
  let v = m[1].trim();
  if (v.length >= 2) {
    const c = v[0];
    if ((c === "'" || c === '"') && v[v.length - 1] === c) v = v.slice(1, -1);
  }
  return v;
}

// agent.cordis.yml → insert 项的 config.plugins 行
//   * 逐行搬入（保持 block scalar 的相对缩进，人格文本一字不改）
//   * 只去掉顶格注释行：那是真源自己的文件头/分节横幅（且提到 ./engines 相对路径挂载，
//     在本文件里已被改写为包子路径，留着只会误导）；缩进注释作为行内说明保留
//   * ./engines/<file> → dsh-science-geophysics/engines/<file>（官方 skill 第 80 行：
//     Resolve assets from installed packages rather than a preset directory.）
function pluginsLines(agentText) {
  const out = [];
  let rows = 0, rewritten = 0;
  for (const raw of agentText.split(/\r?\n/)) {
    if (raw.trim() === '') { out.push(''); continue; }
    if (raw.startsWith('#')) continue;
    if (/^-(?:[ \t]|$)/.test(raw)) rows++;
    const m = ENGINE_RE.exec(raw);
    let body = raw;
    if (m) {
      body = m[1] + m[2] + BUNDLE + '/engines/' + m[3] + m[2];
      rewritten++;
    }
    out.push(PLUGIN_INDENT + tidy(body));
  }
  while (out.length && out[0] === '') out.shift();   // 列表首行不留空行
  while (out.length && out[out.length - 1] === '') out.pop();
  const isRow = (l) => l.startsWith(PLUGIN_INDENT + '- id:');
  return { lines: out, rows, rewritten, pluginRows: out.filter(isRow).length };
}

const HEADER = [
  '# dsh-science-geophysics —— bundle patch',
  '#',
  '# 由 scripts/build-bundle-patch.mjs 生成，勿手改。GENERATED FILE — DO NOT EDIT BY HAND.',
  '# 重新生成：node scripts/build-bundle-patch.mjs   （或 npm run build:patch）',
  '#',
  '# 生成输入（真源）：',
  '#   preset/agent.cordis.yml  -> preset 声明行的 config.plugins（逐行搬入，仅去掉顶格注释行）',
  '#   preset/preset.yml        -> preset 声明行的 name / description',
  '#',
  '# package.json 的 dsh.bundle.patch 指向本文件；dsh plugin add 安装后由 profile 加载。',
  '# 本文件只有一条 insert 行：注册用户 preset「地球物理模式」。',
  '# 两个零依赖引擎不在此处插入 profile 层——它们已作为 preset 的 plugins 成员挂在 preset 内。',
  '# 同一插件包若在 profile 层与 preset 层各挂一次，会得到两个实例并可能撞工具名，故只保留 preset 内一份。',
];

function presetBlock(name, description, plugins) {
  const head = [
    '# ── preset 声明行（让 DSH 出现可选 preset「地球物理模式」）──────────────────────',
    '#',
    '# 现行机制：preset 不是目录，而是这条 @deepseek-ai/dsh-agent-preset 声明行。',
    '# config.plugins 逐行取自 preset/agent.cordis.yml（真源），其中的 ./engines/*.mjs 已改写为',
    '# 包子路径 dsh-science-geophysics/engines/*.mjs —— 官方 skill editing-cordis-compositions',
    '# 第 80 行要求 Resolve assets from installed packages rather than a preset directory。',
    '# 人格与引擎都在 preset 内，因此只作用于选了「地球物理模式」的 agent（不走 profile 全局）。',
  '# 引擎行必须是包子路径：profile 加载器把相对名按 profile 目录解析，./engines/... 在 bundle 里会断。',
  '# Verified experimentally on dsh 0.2.1-rc.2.',
    '- insert:',
    '    - id: preset-' + PRESET_ID,
    "      name: '@deepseek-ai/dsh-agent-preset'",
    '      config:',
    '        id: ' + q(PRESET_ID),
    '        name: ' + q(name),
    '        description: ' + q(description),
    '        order: 20',
    '        plugins:',
  ];
  return head.concat(plugins);
}

const [agentText, presetText] = await Promise.all([
  fsp.readFile(SRC_AGENT, 'utf8'),
  fsp.readFile(SRC_PRESET, 'utf8'),
]);

const name = scalarOf(presetText, 'name');
const description = scalarOf(presetText, 'description');
if (!name) throw new Error('preset/preset.yml 缺少 name');
if (!description) throw new Error('preset/preset.yml 缺少 description');

const { lines: plugins, rows, rewritten, pluginRows } = pluginsLines(agentText);

const problems = [];
if (rows === 0) problems.push('preset/agent.cordis.yml 没解析出任何顶层插件行');
if (pluginRows !== rows) problems.push('plugins 行数 ' + pluginRows + ' != 真源顶层行数 ' + rows);
if (rewritten !== 2) problems.push('./engines/*.mjs 改写条数为 ' + rewritten + '（期望 2）');
if (plugins.some((l) => /\.\/engines\//.test(l))) problems.push('改写后仍残留 ./engines/ 相对路径');
if (problems.length) throw new Error('生成失败：' + problems.join('；'));

const text = [
  ...HEADER,
  '',
  ...presetBlock(name, description, plugins),
].join('\n').replace(/\n*$/, '\n');   // 恰好一个结尾换行（POSIX 文本文件）

const before = await fsp.readFile(OUT, 'utf8').catch(() => null);
await fsp.writeFile(OUT, text, 'utf8');

console.log('✔ 已生成 cordis.patch.yml' + (before === text ? '（内容未变）' : '（内容已更新）'));
console.log('  preset 声明行：id=preset-' + PRESET_ID + '，config.id=' + PRESET_ID + '，name=' + name + '，order=20');
console.log('  config.plugins：' + pluginRows + ' 行（真源 preset/agent.cordis.yml 顶层 ' + rows + ' 行）');
console.log('  引擎行改写：' + rewritten + ' 处 ./engines/*.mjs -> ' + BUNDLE + '/engines/*.mjs');
console.log('  字节数：' + Buffer.byteLength(text, 'utf8'));

