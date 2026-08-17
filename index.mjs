// dsh-science-geophysics —— 包入口（供工具链/校验解析与程序化使用）
// 引擎实际由 bundle patch 按子路径导出加载（engines/*.mjs），本入口提供
// 程序化表面：两个引擎插件的 apply 与共享核心工具。
export { apply as researchLoopApply, name as researchLoopName } from "./engines/research-loop.mjs";
export { apply as artifactRegistryApply, name as artifactRegistryName } from "./engines/artifact-registry.mjs";
export * from "./engines/core.mjs";
