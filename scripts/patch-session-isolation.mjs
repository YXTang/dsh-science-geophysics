#!/usr/bin/env node
/**
 * patch-session-isolation.mjs — workspace-isolation guard for the DSH web UI.
 *
 * WHY
 *   DSH's shared "New Session" action used to resolve its target Workspace as
 *     workspaceId ?? currentWorkspaceId ?? recentWorkspaceId
 *   The implicit `recentWorkspaceId` fallback let automation driving the web
 *   UI (e.g. a Playwright script, or any programmatic session creator) spawn
 *   sessions into whatever project happened to be most recently used — a
 *   cross-project pollution vector. This plugin ships the one-line guard:
 *     workspaceId ?? currentWorkspaceId            (no recent fallback)
 *   so a new session without an explicit Workspace clears into the New
 *   Session view state and the user must pick one.
 *
 *   The fix lives in DSH core
 *   (packages/client/ui-workspace/src/client/workspaces/service.ts, `startSession`)
 *   and upstream currently cannot accept external PRs, so dsh-science carries
 *   it as an idempotent patch you re-apply after every `dsh` upgrade. See
 *   docs/workspace-isolation.md.
 *
 * USAGE
 *   node scripts/patch-session-isolation.mjs [apply|revert|status] [--file <path>]
 *   - apply   (default) apply the guard if not already applied (backup first)
 *   - revert  restore the pristine file from the backup
 *   - status  report whether the guard is applied / a backup exists
 *
 *   The target file is auto-detected from the global @deepseek-ai/dsh install;
 *   override with --file or the DSH_CLIENT_BUNDLE env var (the older
 *   DSH_CLIENT_RUNTIME spelling is still honored).
 *
 * EXIT CODES
 *   0 ok (apply was a no-op or succeeded; status printed)
 *   1 file not found / pattern not matched / revert had no backup
 */

import { readFileSync, writeFileSync, existsSync, copyFileSync, rmSync } from 'node:fs'
import { createRequire } from 'node:module'
import { execFileSync } from 'node:child_process'
import path from 'node:path'

const GUARD_COMMENT = 'Workspace-isolation guard'
// The guarded expression, as shipped by the DSH client bundle
// (@deepseek-ai/dsh-client-ui-workspace/lib/client.js, WorkspaceRuntime#startSession).
// As of 0.2.1-rc.2 it reads `?? recent`, a local const holding the "most recently used
// workspace" — the older inlined spelling no longer exists in the bundle.
const FIXED = 'const target = workspaceId ?? currentWorkspaceId;'
const ANCHORS = [
  { label: 'dsh >= 0.2.1-rc.2', pristine: 'const target = workspaceId ?? currentWorkspaceId ?? recent;' },
]
const BACKUP_SUFFIX = '.bak-science-isolation'

function fail(msg) {
  console.error(`[patch-session-isolation] ${msg}`)
  process.exit(1)
}

// Newest first. The bundle moved between dsh releases; the first one that exists wins.
const CLIENT_SUBPATHS = [
  '@deepseek-ai/dsh-client-ui-workspace/lib/client.js',
]

function findClientJs(override) {
  if (override) return override
  const candidates = []
  const require = createRequire(import.meta.url)
  for (const sub of CLIENT_SUBPATHS) {
    try {
      candidates.push(require.resolve(sub))
    } catch { /* not resolvable from this package (exports map / not installed) */ }
  }
  try {
    // The bundle lives next to the host: <dsh>/node_modules/@deepseek-ai/*.
    const dshPkg = require.resolve('@deepseek-ai/dsh/package.json')
    for (const sub of CLIENT_SUBPATHS) {
      candidates.push(path.join(path.dirname(dshPkg), 'node_modules', sub))
    }
  } catch { /* @deepseek-ai/dsh not resolvable from this package */ }
  try {
    // npm on Windows is npm.cmd, which spawnSync only launches through a shell.
    const globalRoot = execFileSync('npm', ['root', '-g'], {
      encoding: 'utf8',
      shell: process.platform === 'win32',
    }).trim()
    for (const sub of CLIENT_SUBPATHS) {
      candidates.push(
        path.join(globalRoot, '@deepseek-ai/dsh/node_modules', sub),
        path.join(globalRoot, sub),
      )
    }
  } catch { /* npm root unavailable */ }
  for (const c of candidates) if (c && existsSync(c)) return c
  return undefined
}

function findAnchor(src) {
  return ANCHORS.find((a) => src.includes(a.pristine))
}

function indentOf(line) {
  const m = /^[ \t]*/.exec(line)
  return m ? m[0] : ''
}

function apply(file) {
  const src = readFileSync(file, 'utf8')
  if (src.includes(GUARD_COMMENT) && src.includes(FIXED)) {
    console.log(`[patch-session-isolation] already applied: ${file}`)
    return 0
  }
  const anchor = findAnchor(src)
  if (!anchor) {
    console.error(`[patch-session-isolation] no known anchor found in ${file}`)
    for (const a of ANCHORS) console.error(`  expected (${a.label}): ${a.pristine}`)
    for (const line of src.split('\n')) {
      if (/const target = workspaceId/.test(line)) console.error('  found instead: ' + line.trim())
    }
    return 1
  }
  const lines = src.split('\n')
  const idx = lines.findIndex(l => l.includes(anchor.pristine))
  if (idx === -1) return 1
  const indent = indentOf(lines[idx])
  const guard = [
    `${indent}// ${GUARD_COMMENT}: only create a new session into an EXPLICITLY`,
    `${indent}// chosen workspace. The implicit \`recentWorkspaceId\` fallback let`,
    `${indent}// automation driving the web UI spawn sessions into whatever project`,
    `${indent}// happened to be most recent — the cross-project pollution vector that`,
    `${indent}// created demo sessions in an unrelated project.`,
    `${indent}${FIXED}`,
  ]
  lines.splice(idx, 1, ...guard)
  const backup = file + BACKUP_SUFFIX
  copyFileSync(file, backup)
  writeFileSync(file, lines.join('\n'))
  // verify
  const out = readFileSync(file, 'utf8')
  if (!out.includes(FIXED) || out.includes(anchor.pristine)) {
    copyFileSync(backup, file)
    rmSync(backup)
    console.error('[patch-session-isolation] apply failed verification; restored backup')
    return 1
  }
  console.log(`[patch-session-isolation] applied via anchor "${anchor.label}" (backup: ${backup})`)
  return 0
}

function revert(file) {
  const backup = file + BACKUP_SUFFIX
  if (!existsSync(backup)) {
    console.error(`[patch-session-isolation] no backup at ${backup}`)
    return 1
  }
  copyFileSync(backup, file)
  rmSync(backup)
  console.log(`[patch-session-isolation] reverted ${file}`)
  return 0
}

function status(file) {
  const src = readFileSync(file, 'utf8')
  const applied = src.includes(GUARD_COMMENT) && src.includes(FIXED)
  const anchor = findAnchor(src)
  console.log(`[patch-session-isolation] file: ${file}`)
  console.log(`[patch-session-isolation] guard applied: ${applied ? 'yes' : 'no'}`)
  console.log(`[patch-session-isolation] anchor matched: ${anchor ? `yes (${anchor.label})` : 'no'}`)
  console.log(`[patch-session-isolation] pristine expression present: ${anchor ? 'yes' : 'no'}`)
  console.log(`[patch-session-isolation] backup exists: ${existsSync(file + BACKUP_SUFFIX) ? 'yes' : 'no'}`)
  return 0
}

const argv = process.argv.slice(2)
const cmd = argv[0] && !argv[0].startsWith('--') ? argv[0] : 'apply'
const fileFlag = argv.find(a => a === '--file')
const override = fileFlag
  ? argv[argv.indexOf(fileFlag) + 1]
  : (process.env.DSH_CLIENT_BUNDLE || process.env.DSH_CLIENT_RUNTIME || undefined)

const file = findClientJs(override)
if (!file) fail(`could not locate the DSH client bundle (${CLIENT_SUBPATHS.join(', ')}) — pass --file <path>`)

let code = 0
if (cmd === 'apply') code = apply(file)
else if (cmd === 'revert') code = revert(file)
else if (cmd === 'status') code = status(file)
else fail(`unknown command: ${cmd} (use apply|revert|status)`)
process.exit(code)
