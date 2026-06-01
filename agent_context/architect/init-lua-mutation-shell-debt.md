# src/app/init.lua 变异覆盖：bootstrap-only manifest + 宿主壳债（backlog）

测量：HEAD `a6261e97`（sign-in-host-wiring 合并后）。`lua tools/quality/mutate.lua src/app/init.lua --mutate-all` → **52/121 killed（43%）**。

## 现象
- init.lua 的 manifest 是 **bootstrap-only**（每个 scope 缺 `last_mutation_status`）→ 差分变异直接 bail（"manifest is bootstrap-only"），即 init.lua 在常规差分流里**变异覆盖被禁用**，触碰它的 handoff 不会被 mutate 网住。
- `--mutate-all` 跑出 69 survivor，集中在宿主适配壳：`type(GlobalAPI.show_message_marquee) == "function"` 等 L141/144 宿主 API 存在性 guard——属环境不适边界（`.luacov` 已排除 src/app，见 [[reference_luacov_excludes_ui_crap_separate_coverage]]）。

## 与 sign-in-host-wiring 的边界
本周期 init.lua delta 仅 +9（sign-in 惰性 accessor + `runtime_install.install({...})` 接线）。该接线调用 L161 经集成/e2e 宿主冒烟（ADR 0013）杀掉（1/1）；sign-in 接线逻辑本体在 host_install/sign_in 层 100% killed。69 survivor 全为**先于本周期**的宿主壳债，非 sign-in 债。

## backlog（独立任务，非 sign-in）
init.lua 是组合根 + 宿主 bootstrap，应按宪法「拆可测模块 / 缩环境不适边界」做一次 testable/unsuitable 切分：把可测的组合/解析逻辑抽出闭到变异，宿主 GlobalAPI guard 留薄壳。关联 [[project_src_app_module_level_state]]（init.lua 模块级 captured ref 债）。切分后再写 init.lua 经验 manifest（消除 bootstrap-only）。
