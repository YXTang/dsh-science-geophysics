/**
 * dsh-science-geophysics —— 包入口
 *
 * 机制（与 @linxin666/dsh-liangshen 一致）：
 * 本包在 profile 里只挂一条普通插件行（cordis.patch.yml 的 insert），
 * 激活时由下面的 apply 把 presets/geophysics/ 声明给 agent-preset registry。
 * preset 是「运行时注册的声明」，不是让 loader 去发现的目录 ——
 * 这正是旧版直接 insert 一条 preset 声明行却不出现在预设列表里的原因。
 *
 * 程序化表面仍保留：两个引擎的 apply/name 与共享核心工具。
 */
import { fileURLToPath } from "node:url";
import { readPresetDefinition } from "./src/composition.mjs";

export { apply as researchLoopApply, name as researchLoopName } from "./engines/research-loop.mjs";
export { apply as artifactRegistryApply, name as artifactRegistryName } from "./engines/artifact-registry.mjs";
export * from "./engines/core.mjs";

/** 本插件在 profile 组合里的插件名。 */
export const name = "dsh-science-geophysics";

/** preset 标识：registry 以此作为键，也是会话选择的身份。 */
export const PRESET_ID = "geophysics";

/** 打包的 preset 目录（含 preset.yml 与 agent.cordis.yml）。 */
export function bundledPresetDir() {
	return fileURLToPath(new URL("./presets/geophysics/", import.meta.url));
}

/**
 * 挂载插件：把地球物理模式声明到 agent-preset registry，卸载时撤回。
 * @param ctx 宿主插件上下文
 */
export function apply(ctx) {
	/** 活动的 registry，或部署未组合该服务时的 undefined。 */
	const registryOf = () => {
		try {
			return ctx.get("agentPresets");
		} catch {
			return undefined;
		}
	};

	/** 当前声明的 disposer，由声明者持有。 */
	let release;
	/** 声明代数：重新声明会取代上一代。 */
	let generation = 0;
	/** fiber 卸载后置真，迟到的声明不得再生效。 */
	let closed = false;
	/** 串行化声明工作，避免并发交错。 */
	let queue = Promise.resolve();
	/** 上次声明时 registry 尚不存在——只有这种状态才触发迟到补偿。 */
	let registryMissing = false;

	const warn = (message) => {
		ctx.logger?.warn?.(`dsh-science-geophysics: ${message}`);
	};

	/** 撤回当前声明，等待 registry 卸载其行。 */
	const undeclare = async () => {
		const dispose = release;
		release = undefined;
		if (dispose === undefined) return;
		try {
			await dispose();
		} catch (error) {
			warn(`undeclare failed: ${error instanceof Error ? error.message : String(error)}`);
		}
	};

	/** 读取 preset 目录并声明；重复调用安全（先撤回再声明）。 */
	const declare = () => {
		const myGeneration = ++generation;
		queue = queue.then(async () => {
			if (closed || myGeneration !== generation) return;
			const registry = registryOf();
			if (registry === undefined) {
				registryMissing = true;
				warn("agentPresets registry is not composed; preset not declared");
				return;
			}
			registryMissing = false;
			await undeclare();
			if (closed || myGeneration !== generation) return;
			try {
				const definition = readPresetDefinition(PRESET_ID, bundledPresetDir());
				release = await registry.register(definition);
				ctx.logger?.info?.(`dsh-science-geophysics: declared preset "${definition.name}" (${definition.id})`);
			} catch (error) {
				warn(`preset declaration failed: ${error instanceof Error ? error.message : String(error)}`);
			}
		});
		return queue;
	};

	// registry 晚到时的补偿：只在先前确实缺失时重新声明，避免重复注册。
	ctx.inject(["agentPresets"], () => {
		if (registryMissing) void declare();
	});

	ctx.effect(() => {
		void declare();
		return async () => {
			closed = true;
			generation += 1;
			await queue;
			await undeclare();
		};
	}, "dsh-science-geophysics: preset declaration");
}
