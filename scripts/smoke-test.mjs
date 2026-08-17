// dsh-science-geophysics smoke test —— 在临时工作区上验证两个引擎插件的工具逻辑、
// 错误码体系、状态机约束、并发基础（锁/原子写）、schema 迁移与新工具
// （artifact_diff / artifact_verify / artifact_deprecate / research_report），
// 并对发布包做静态校验（dsh.bundle manifest、cordis.patch.yml 子路径、引擎镜像一致性）。
// 用法：node scripts/smoke-test.mjs [工作目录]
// 默认工作目录 = os.tmpdir() 下的临时目录（发布包本身保持只读，适合 CI）。

import { promises as fsp, existsSync } from "node:fs";
import { createHash } from "node:crypto";
import os from "node:os";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const pkg = path.resolve(here, "..");

// ── 临时工作区 ──────────────────────────────────────────────────────
const work = process.argv[2]
  ? path.resolve(process.argv[2])
  : await fsp.mkdtemp(path.join(os.tmpdir(), "dsh-science-geophysics-smoke-"));
await fsp.mkdir(work, { recursive: true });
console.log(`工作区：${work}\n`);

let passed = 0;
let failures = 0;

function ok(name, cond, extra = "") {
  if (cond) {
    passed++;
    console.log(`  ✔ ${name}${extra ? " — " + extra : ""}`);
  } else {
    failures++;
    console.error(`  ✗ ${name}`);
  }
}

async function expectThrow(fn, code, name) {
  try {
    await fn();
    failures++;
    console.error(`  ✗ ${name}：期望抛错 ${code}，但未抛`);
    return false;
  } catch (err) {
    if (code && err?.code !== code) {
      failures++;
      console.error(`  ✗ ${name}：错误码不符，期望 ${code}，实际 ${err?.code ?? err?.message}`);
      return false;
    }
    passed++;
    console.log(`  ✔ ${name} → 抛错 ${err?.code ?? err?.message}`);
    return true;
  }
}

const exec = { agent: { session: { id: "smoke-test-session", cwd: work } } };

async function registerEngines(config = {}) {
  const loopMod = await import(pathToFileURL(path.join(pkg, "engines", "research-loop.mjs")).href);
  const artMod = await import(pathToFileURL(path.join(pkg, "engines", "artifact-registry.mjs")).href);
  const loopTools = {};
  const artTools = {};
  await loopMod.apply({ tools: { register: (d) => (loopTools[d.name] = d) } }, config);
  await artMod.apply({ tools: { register: (d) => (artTools[d.name] = d) } }, config);
  return { loopTools, artTools, loopMod, artMod };
}

const sub = (name) => path.join(work, name);

// ── 1. 静态包校验 ───────────────────────────────────────────────────
console.log("== 1. 静态包校验 ==");
const pkgJson = JSON.parse(await fsp.readFile(path.join(pkg, "package.json"), "utf8"));
ok("package.json: dsh.bundle.patch", pkgJson?.dsh?.bundle?.patch === "./cordis.patch.yml");

const patchText = await fsp.readFile(path.join(pkg, "cordis.patch.yml"), "utf8");
const patchNames = ["research-loop.mjs", "artifact-registry.mjs"];
let patchOk = patchText.includes("dsh-science-geophysics/engines/research-loop.mjs") && patchText.includes("dsh-science-geophysics/engines/artifact-registry.mjs");
ok("cordis.patch.yml: 子路径导出引用两个引擎", patchOk);
ok("package.json exports ./engines/*（含 core.mjs 子路径）", Boolean(pkgJson.exports?.["./engines/*"]));

let mirrorOk = true;
for (const e of ["core.mjs", "research-loop.mjs", "artifact-registry.mjs"]) {
  const a = await sha256(path.join(pkg, "engines", e));
  const b = await sha256(path.join(pkg, "preset", "engines", e));
  if (a !== b) mirrorOk = false;
}
ok("engines/ ↔ preset/engines/ 镜像一致（含 core.mjs）", mirrorOk);

// ── 2. 插件契约与工具注册 ───────────────────────────────────────────
console.log("\n== 2. 插件契约与工具注册 ==");
const { loopTools, artTools, loopMod, artMod } = await registerEngines();
ok("research-loop: name/inject/apply", loopMod.name === "science-research-loop" && loopMod.inject?.includes("tools") && typeof loopMod.apply === "function");
ok("artifact-registry: name/inject/apply", artMod.name === "science-artifact-registry" && artMod.inject?.includes("tools") && typeof artMod.apply === "function");

const EXPECT_LOOP = ["research_init", "research_state", "research_hypothesis", "research_experiment", "research_findings", "research_phase", "research_review", "research_report"];
const EXPECT_ART = ["artifact_save", "artifact_list", "artifact_show", "artifact_diff", "artifact_verify", "artifact_deprecate", "artifact_reproduce"];
const loopMissing = EXPECT_LOOP.filter((n) => !loopTools[n]);
const artMissing = EXPECT_ART.filter((n) => !artTools[n]);
ok(`research-loop 注册 8 工具`, loopMissing.length === 0, loopMissing.length ? `缺：${loopMissing}` : "");
ok(`artifact-registry 注册 7 工具`, artMissing.length === 0, artMissing.length ? `缺：${artMissing}` : "");
ok("结构化输出：research_report / artifact_diff / artifact_verify 有 JSON schema",
  loopTools.research_report.output?.schema?.type === "object" &&
  artTools.artifact_diff.output?.schema?.type === "object" &&
  artTools.artifact_verify.output?.schema?.type === "object");

// ── 3. 错误码 / 校验（隔离根目录，互不干扰）──────────────────────────
console.log("\n== 3. 错误码与校验约束 ==");
await expectThrow(() => loopTools.research_state.execute({ root: sub("t-err-uninit") }, exec), "ERR_NOT_INIT", "未初始化时 research_state");
await expectThrow(() => loopTools.research_hypothesis.execute({ root: sub("t-err-valid"), text: "" }, exec), "ERR_VALIDATION", "research_hypothesis 缺 text");
await expectThrow(() => loopTools.research_hypothesis.execute({ root: sub("t-err-valid"), text: "x", status: "supported" }, exec), "ERR_VALIDATION", "research_hypothesis 初始状态不得为结论态");
const tValid = sub("t-err-valid");
await loopTools.research_init.execute({ root: tValid, title: "校验测试" }, exec);
await expectThrow(() => loopTools.research_findings.execute({ root: tValid, experiment: "E99", finding: "x" }, exec), "ERR_NOT_FOUND", "research_findings 未知实验");
await expectThrow(() => loopTools.research_phase.execute({ root: tValid, phase: "nope" }, exec), "ERR_VALIDATION", "research_phase 未知阶段");
await expectThrow(() => loopTools.research_review.execute({ root: tValid, target: "c", verdict: "maybe" }, exec), "ERR_VALIDATION", "research_review verdict 枚举");
await expectThrow(() => artTools.artifact_save.execute({ root: sub("t-err-path"), name: "a", sources: ["../escape.txt"] }, exec), "ERR_PATH", "artifact_save 路径越界");

// 阶段回退（正向先建项目）
const tPhase = sub("t-phase");
await loopTools.research_init.execute({ root: tPhase, title: "阶段测试" }, exec);
await loopTools.research_phase.execute({ root: tPhase, phase: "experiment" }, exec);
await expectThrow(() => loopTools.research_phase.execute({ root: tPhase, phase: "literature" }, exec), "ERR_VALIDATION", "research_phase 回退阶段被拒");

// 假设状态机：实验关联自动推进 testing；终态不能直跳另一结论
const tSm = sub("t-statemachine");
await loopTools.research_init.execute({ root: tSm, title: "状态机测试", question: "Q?" }, exec);
await loopTools.research_hypothesis.execute({ root: tSm, text: "H 需经 testing" }, exec);
await loopTools.research_experiment.execute({ root: tSm, title: "E", hypothesis: "H1" }, exec);
const mSm = JSON.parse(await fsp.readFile(path.join(tSm, "research-manifest.json"), "utf8"));
ok("关联实验自动推进 H1 → testing", mSm.hypotheses.find((h) => h.id === "H1")?.status === "testing");
const refOut = await loopTools.research_findings.execute({ root: tSm, experiment: "E01", finding: "f2", conclusion: "refuted" }, exec);
ok("状态机：testing → refuted 合法", typeof refOut === "string" && refOut.includes("被否定"));
await expectThrow(
  () => loopTools.research_findings.execute({ root: tSm, experiment: "E01", finding: "f3", conclusion: "supported" }, exec),
  "ERR_VALIDATION",
  "状态机：终态不可直跳另一结论（refuted → supported）"
);

// 配额
const { artTools: artQuota } = await registerEngines({ maxFileBytes: 100 });
const tQuota = sub("t-quota");
await fsp.mkdir(path.join(tQuota, "analyses"), { recursive: true });
await fsp.writeFile(path.join(tQuota, "analyses", "big.bin"), Buffer.alloc(500, 7), "utf8");
await expectThrow(
  () => artQuota.artifact_save.execute({ root: tQuota, name: "big", sources: ["analyses/big.bin"] }, exec),
  "ERR_QUOTA",
  "artifact_save 大小配额"
);

// ── 4. 端到端研究循环 + 工件（含迁移、去重、结构化输出）──────────────
console.log("\n== 4. 端到端演练：研究循环 + 工件 + 新工具 ==");
const tE2e = sub("t-e2e");
const steps = [
  ["research_init", { root: tE2e, title: "台阵背景噪声与地磁日变化监测（演示）", domain: "seismology", question: "台阵背景噪声水平与地磁日变化是否存在相关性？" }],
  ["research_hypothesis", { root: tE2e, text: "夜间地磁 Sq 日变化减弱期背景噪声水平更低", question: "背景噪声与地磁日变化是否相关？" }],
  ["research_experiment", { root: tE2e, title: "噪声功率谱与地磁指数联合分析", hypothesis: "H1", objective: "对 3 个台站连续波形与地磁分钟值做联合分析", plan: ["Obspy 读取 MiniSEED 并去仪器响应", "计算 PSD 与地磁 K 指数", "Spearman 相关与显著性检验"] }],
  ["research_findings", { root: tE2e, experiment: "E01", finding: "3 个台站均显示夜间背景噪声功率谱密度降低（-3~-5 dB），与 K 指数负相关（p<0.01）", conclusion: "supported", nextQuestion: "相关性是否受台站场地噪声（如交通）调制？" }],
  ["research_phase", { root: tE2e, phase: "manuscript" }],
];
for (const [name, args] of steps) {
  const out = await loopTools[name].execute(args, exec);
  console.log(`  ${name} -> ${String(out).split("\n")[0].slice(0, 90)}`);
  passed++;
}
ok("研究循环 5 步全部执行", true);

// 清单状态断言
const manifest = JSON.parse(await fsp.readFile(path.join(tE2e, "research-manifest.json"), "utf8"));
ok("manifest schema=2", manifest.schema === 2);
ok("假设 H1 → supported", manifest.hypotheses.find((h) => h.id === "H1")?.status === "supported");
ok("实验 E01 → concluded", manifest.experiments.find((e) => e.id === "E01")?.status === "concluded");
ok("iteration=1（nextQuestion 递增，统一语义）", manifest.loop.iteration === 1);
ok("phase=manuscript（正向推进）", manifest.loop.phase === "manuscript");
ok("manifest.artifacts 初始为空", Array.isArray(manifest.artifacts) && manifest.artifacts.length === 0);

// research_experiment 输出含下一步建议
const expOut = await loopTools.research_experiment.execute({ root: tE2e, title: "质粒定位", hypothesis: "H1" }, exec);
ok("research_experiment 返回下一步建议", typeof expOut === "string" && expOut.includes("下一步建议"));

// 工件：v1 保存 + 回写 manifest + 仪表盘联动
const artifactFile = path.join(tE2e, "experiments", "E01", "results", "noise-kcorr.tsv");
await fsp.mkdir(path.dirname(artifactFile), { recursive: true });
await fsp.writeFile(artifactFile, "station\tk_index\tpsd_db\tcorr\nSTA01\t3\t-118.5\t-0.72\nSTA02\t4\t-115.2\t-0.65\nSTA03\t2\t-121.0\t-0.81\n", "utf8");
const envFile = path.join(tE2e, "envs", "geo.yaml");
await fsp.writeFile(envFile, "name: geo\nchannels: [conda-forge]\ndependencies: [obspy=1.4.0]\n", "utf8");

const save1 = await artTools.artifact_save.execute(
  {
    root: tE2e,
    name: "noise-k-corr",
    description: "3 个台站噪声与地磁联合分析结果",
    sources: ["experiments/E01/results/noise-kcorr.tsv"],
    command: "obspy + scipy 谱估计与 Spearman 相关分析",
    inputs: ["data/raw/station01.mseed"],
    envFile: "envs/geo.yaml",
    notes: "ObsPy 1.4.0, Welch PSD + K 指数相关",
  },
  exec
);
ok("artifact_save v1", String(save1).includes("v1"));

const manifest2 = JSON.parse(await fsp.readFile(path.join(tE2e, "research-manifest.json"), "utf8"));
ok("artifact_save 回写 manifest.artifacts", manifest2.artifacts.some((a) => a.name === "noise-k-corr" && a.latestVersion === 1));

const stateOut = await loopTools.research_state.execute({ root: tE2e }, exec);
ok("research_state 仪表盘显示工件数（manifest↔artifacts 打通）", stateOut.includes("工件（1）"));

// v2：相同内容 → 去重（hardlink）
const save2 = await artTools.artifact_save.execute({ root: tE2e, name: "noise-k-corr", sources: ["experiments/E01/results/noise-kcorr.tsv"], command: "obspy ..." }, exec);
ok("artifact_save v2", String(save2).includes("v2"));
const meta = JSON.parse(await fsp.readFile(path.join(tE2e, "artifacts", "noise-k-corr", "artifact.json"), "utf8"));
ok("v2 去重：linkedFrom=v1", meta.versions[1].files[0]?.linkedFrom === "v1");
ok("v1 溯源含 envFile", meta.versions[0].provenance?.envFile?.path === "envs/geo.yaml");
ok("v2 溯源含 inputHashes 记录", Array.isArray(meta.versions[1].provenance?.inputHashes));
const shaA = meta.versions[0].files[0].sha256;
const shaB = meta.versions[1].files[0].sha256;
ok("v1/v2 内容哈希一致", shaA === shaB);

// artifact_diff：默认对比最新两版
const diff = await artTools.artifact_diff.execute({ root: tE2e, name: "noise-k-corr" }, exec);
ok("artifact_diff 结构化输出", diff && typeof diff === "object" && diff.from === 1 && diff.to === 2);
ok("artifact_diff unchanged 含文件", Array.isArray(diff.unchanged) && diff.unchanged.includes("noise-kcorr.tsv"));

// artifact_verify：重算哈希一致
const verify = await artTools.artifact_verify.execute({ root: tE2e, name: "noise-k-corr" }, exec);
ok("artifact_verify status=ok", verify && verify.status === "ok" && verify.checked === 1);

// 篡改后校验应报 mismatch
await fsp.appendFile(path.join(tE2e, "artifacts", "noise-k-corr", "v2", "noise-kcorr.tsv"), "\ntampered\n", "utf8");
const verifyBad = await artTools.artifact_verify.execute({ root: tE2e, name: "noise-k-corr" }, exec);
ok("artifact_verify 检出篡改", verifyBad.status === "mismatch" && verifyBad.mismatches.length === 1);
await fsp.writeFile(path.join(tE2e, "artifacts", "noise-k-corr", "v2", "noise-kcorr.tsv"), "station\tk_index\tpsd_db\tcorr\nSTA01\t3\t-118.5\t-0.72\nSTA02\t4\t-115.2\t-0.65\nSTA03\t2\t-121.0\t-0.81\n", "utf8");

// artifact_deprecate
const dep = await artTools.artifact_deprecate.execute({ root: tE2e, name: "noise-k-corr", reason: "已被 v2 取代" }, exec);
ok("artifact_deprecate", typeof dep === "string" && dep.includes("已标记废弃"));
const listOut = await artTools.artifact_list.execute({ root: tE2e }, exec);
ok("artifact_list 显示废弃标记", listOut.includes("已废弃"));

// research_review：枚举 + 假设联动（H2 处于 testing → 评审可终结）
await loopTools.research_hypothesis.execute({ root: tE2e, text: "相关性由区域场地响应（低频放大）调制" }, exec);
await loopTools.research_experiment.execute({ root: tE2e, title: "质粒分型", hypothesis: "H2" }, exec);
const rev = await loopTools.research_review.execute({ root: tE2e, target: "claim: blaNDM-5 位于质粒", verdict: "supported", hypothesis: "H2", experiment: "E02", issues: ["需补 S1 质粒组装验证"], summary: "命令与结果文件一致" }, exec);
ok("research_review 归档", typeof rev === "string" && rev.includes("R01"));
const manifest3 = JSON.parse(await fsp.readFile(path.join(tE2e, "research-manifest.json"), "utf8"));
ok("评审终结 testing 假设 H2 → supported", manifest3.hypotheses.find((h) => h.id === "H2")?.status === "supported");
ok("评审写入 reviews/R01/report.md", existsSync(path.join(tE2e, "reviews", "R01", "report.md")));

// research_report：结构化输出
const report = await loopTools.research_report.execute({ root: tE2e }, exec);
ok("research_report 结构化对象", report && typeof report === "object" && report.project?.title?.includes("台阵") && report.generatedAt);
ok("research_report artifacts ≥1", Array.isArray(report.artifacts) && report.artifacts.length >= 1);

// research_state detail + historyLimit 裁剪
const stateDetail = await loopTools.research_state.execute({ root: tE2e, detail: true, historyLimit: 2 }, exec);
const mJson = /```json\n([\s\S]*?)\n```/.exec(stateDetail)?.[1];
const detailParsed = mJson ? JSON.parse(mJson) : null;
ok("research_state detail 解析", !!detailParsed);
ok("historyLimit=2 生效", Array.isArray(detailParsed?.loop?.history) && detailParsed.loop.history.length <= 2);

// 审计日志：成功记录在 t-e2e，失败记录（错误码）在 tSm（有意的 ERR_VALIDATION）
const auditLog = await fsp.readFile(path.join(tE2e, ".science.log"), "utf8").catch(() => "");
const lines = auditLog.split("\n").filter(Boolean);
ok("审计日志 .science.log 存在且有记录", lines.length >= 8);
const auditFail = await fsp.readFile(path.join(tSm, ".science.log"), "utf8").catch(() => "");
ok("审计含失败记录（错误码）", auditFail.includes('"ok":false'));

// 空问题警告
const tWarn = sub("t-warn");
const initWarn = await loopTools.research_init.execute({ root: tWarn, title: "无问题项目" }, exec);
ok("research_init 空问题给出警告", String(initWarn).includes("未设置核心研究问题"));

// ── 5. schema 迁移（v1 → v2）───────────────────────────────────────
console.log("\n== 5. schema 迁移 ==");
const tMig = sub("t-migrate");
await fsp.mkdir(tMig, { recursive: true });
const v1Manifest = {
  schema: 1,
  project: { id: "old", title: "旧项目", domain: "seismology", created: "2024-01-01T00:00:00.000Z", status: "active" },
  question: { text: "旧问题", updatedAt: "2024-01-01T00:00:00.000Z" },
  hypotheses: [{ id: "H1", text: "旧假设", status: "proposed", experiments: [] }],
  loop: { phase: "literature", iteration: 0, history: [{ iteration: 0, phase: "literature", action: "a", detail: "b", at: "2024-01-01T00:00:00.000Z" }] },
  experiments: [],
  artifacts: [],
  reviews: [],
  updatedAt: "2024-01-01T00:00:00.000Z",
};
await fsp.writeFile(path.join(tMig, "research-manifest.json"), JSON.stringify(v1Manifest, null, 2), "utf8");
const migState = await loopTools.research_state.execute({ root: tMig }, exec);
ok("v1 清单可被读取", String(migState).includes("旧项目"));
await loopTools.research_hypothesis.execute({ root: tMig, text: "新假设" }, exec);
const migManifest = JSON.parse(await fsp.readFile(path.join(tMig, "research-manifest.json"), "utf8"));
ok("迁移在下次写入时持久化 schema=2", migManifest.schema === 2);
ok("迁移补齐字段（hypotheses[].reviews）", Array.isArray(migManifest.hypotheses[0].reviews) && migManifest.hypotheses[0].reviews.length === 0);
ok("迁移保留旧数据", migManifest.hypotheses.length === 2 && migManifest.hypotheses[1].id === "H2");

console.log(`\n结果: ${passed} 通过, ${failures} 失败`);
if (!process.argv[2]) await fsp.rm(work, { recursive: true, force: true });
process.exit(failures ? 1 : 0);

async function sha256(p) {
  const data = await fsp.readFile(p);
  return createHash("sha256").update(data).digest("hex");
}
