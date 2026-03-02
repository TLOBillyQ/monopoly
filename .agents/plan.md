# Monopoly 兼容层 P1 清理可执行计划（格式重写版）

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件必须遵循 `./.agents/harness/PLANS.md` 维护。执行者只依赖当前工作树与本文件即可复现实施与验收过程。

## 目的 / 全局视角


本计划面向兼容层收敛，核心目标是减少重复角色解析路径、降低载具事件接口命名歧义、清理注释层历史术语噪音，并保证运行时语义不变。用户可观察到的结果是：状态 3D 模块只保留一个角色解析入口，载具事件调用点使用更直观的 `emit_vehicle_*` 语义名，同时旧接口仍可兼容。计划是否生效以回归测试持续通过和代码搜索证据为准。

## 进度


- [x] (2026-03-02T07:15Z) 完成基线核查，确认角色解析双轨、事件转发调用面与注释噪音分布。
- [x] (2026-03-02T07:26Z) 完成 P1.1：新增 `HostRuntimePort.resolve_role_with(player_id, predicate)`，并迁移 `status3d_service/scene.lua`、`status.lua` 到统一入口。
- [x] (2026-03-02T07:27Z) 完成 P1.2：在 `RuntimeContext` 引入 `emit_vehicle_*`，保留 `forward_eca_event_*` 兼容别名，迁移核心调用点为“优先新名、回退旧名”。
- [x] (2026-03-02T07:28Z) 完成 P1.3：清理 tests/docs 注释层 legacy/compat 术语，不改行为逻辑。
- [x] (2026-03-02T07:29Z) 完成收口验收与文档回填，回归保持全绿。
- [x] (2026-03-02T08:11Z) 按 PLANS.md 格式要求重写本计划文档结构与叙述方式。

## 意外与发现


实施中确认 `HostRuntimePort.resolve_role` 本身已经做了从 `runtime_ports.resolve_role` 到 `resolve_game_role` 的回退，但 `status3d` 的 `scene.lua` 与 `status.lua` 仍各自手写第二次回退，导致职责重复。对应证据来自 `src/presentation/api/HostRuntimePort.lua:33-57`、`src/presentation/render/status3d_service/scene.lua:8-12`、`src/presentation/render/status3d_service/status.lua:7-11` 的实现对比。

实施中还确认 `forward_eca_event_*` 已跨 `core/game/presentation` 多层调用，不能硬切接口名，否则会直接影响运行时注入和测试桩。因此迁移时必须采用并行兼容路径，即调用方优先使用 `emit_vehicle_*`，若仅提供旧字段则回退到 `forward_eca_event_*`。对应证据来自 `src/game/core/runtime/player_state/StatusOps.lua`、`src/presentation/render/MoveAnim.lua`、`src/presentation/render/board_runtime/placement.lua` 的迁移后代码。

## 决策日志


决策一：先做角色解析统一，再做事件命名迁移，最后做注释清理。理由是第一步改动面最小且收益直接，第二步跨层影响大需在稳定解析链后推进，第三步是低风险扫尾任务。日期/作者：2026-03-02 / Codex GPT-5.3-Codex。

决策二：保留 `forward_eca_event_*` 作为 `emit_vehicle_*` 的兼容别名，不在本批次删除。理由是当前仓库仍有测试桩和注入路径依赖旧字段，先完成行为兼容再规划退役窗口风险更低。日期/作者：2026-03-02 / Codex GPT-5.3-Codex。

## 结果与复盘


P1 已完成，功能行为保持稳定，回归结果未退化。角色解析链路已收敛到 `resolve_role_with`，status3d 不再直接调用 `resolve_game_role`。载具事件接口已完成语义化命名引入并保留兼容路径，达到“新名可用、旧名不断”的迁移目标。

剩余技术债是仓库内仍有部分测试和历史调用习惯围绕 `forward_eca_event_*` 编写，后续可在单独批次逐步迁移并最终评估是否移除别名。该后续工作不影响本批次交付正确性。

## 背景与导读


本计划涉及的关键路径包含四块。第一块是表现层宿主端口 `src/presentation/api/HostRuntimePort.lua`，它负责角色解析与运行时 API 封装。第二块是状态 3D 逻辑 `src/presentation/render/status3d_service/scene.lua` 与 `status.lua`，它们依赖角色能力（如 `get_ctrl_unit`、`set_label_text`）驱动渲染。第三块是载具事件发射链路 `src/core/RuntimeContext.lua` 及调用点 `StatusOps.lua`、`MoveAnim.lua`、`placement.lua`。第四块是文案层文件 `tests/suites/runtime_ports_contract.lua` 与 `docs/architecture/presentation_canvas_first.md`。

文中“谓词”是用于能力校验的布尔函数，用来表达“角色对象是否具备当前调用所需方法”。统一入口通过谓词把能力判断内聚，避免各模块重复写 fallback 分支。

## 里程碑


里程碑 M1 是角色解析统一。目标是让 status3d 只通过一个入口拿角色对象并做能力判断。完成标准是 `status3d_service` 目录中不再出现直接 `resolve_game_role` 调用，且回归通过。

里程碑 M2 是事件命名迁移。目标是建立 `emit_vehicle_*` 语义名并保留旧名别名，随后迁移核心调用点以降低命名歧义。完成标准是 `RuntimeContext` 同时具备新旧接口映射，调用方优先新名并保持兼容，且回归通过。

里程碑 M3 是注释噪音清理。目标是统一 tests/docs 的术语，避免把“可控降级策略”误写成“遗留模式默认行为”。完成标准是关键 legacy/compat 噪音词在目标范围内清理完成，且回归通过。

## 工作计划


实施顺序采用先内聚、后迁移、再清理的策略。首先在 `HostRuntimePort` 新增谓词化解析函数，并让 `resolve_role` 复用该新函数。随后改写 `status3d` 两处 `_resolve_role`，删除本地二次 fallback。接着在 `RuntimeContext` 增加 `emit_vehicle_*` 并让 `forward_eca_event_*` 转调到新函数，再迁移三个核心调用点到“新名优先、旧名回退”。最后修改 tests/docs 注释文案并执行回归收口。

## 具体步骤


所有命令均在仓库根目录 `C:\Users\Lzx_8\Desktop\dev\repo\monopoly` 执行。

先跑基线与收口测试：

    lua tests/internal/dep_rules.lua
    lua tests/regression.lua

验证角色解析收敛：

    rg "resolve_game_role\\(" src/presentation/render/status3d_service -n

验证事件接口迁移状态：

    rg "forward_eca_event_|emit_vehicle_" src -n

验证注释噪音清理状态：

    rg "legacy mode|compatibility wrappers|legacy bridge" tests docs -n -i

## 验证与验收


验收以行为证据为准而不是结构描述。第一，`lua tests/regression.lua` 与 `lua tests/internal/dep_rules.lua` 必须通过。第二，`status3d_service` 中不得再出现 `resolve_game_role` 直接调用。第三，`RuntimeContext` 中新旧命名必须并存且旧名为别名转调，新调用点可优先使用新名。第四，目标 tests/docs 中 legacy/compat 噪音词应清理完成。

## 可重复性与恢复


本计划可重复执行，不包含破坏性迁移命令。若某一步失败，应仅回退该步触及文件后重跑两条测试命令，不进行跨步骤整体回退。由于本方案保留旧接口别名，出现局部迁移未完成时仍可保持主流程可运行，这一兼容策略是恢复路径的一部分。

## 产物与备注


    [evidence] lua tests/internal/dep_rules.lua -> dep_rules ok
    [evidence] lua tests/regression.lua -> All regression checks passed (209), dep_rules ok, tick ok, forbidden_globals ok
    [evidence] rg "resolve_game_role\\(" src/presentation/render/status3d_service -n -> No matches found
    [evidence] rg "forward_eca_event_|emit_vehicle_" src -n -> RuntimeContext 同时存在 emit_vehicle_* 与 forward_eca_event_*，调用点已迁移为新名优先
    [evidence] rg "legacy mode|compatibility wrappers|legacy bridge" tests docs -n -i -> No matches found

## 接口与依赖


本计划保留 `RuntimePorts` 的既有契约，不删除 `set_legacy_global_fallback_enabled`，不移除 `RuntimeEventBridge`、`MonopolyEvents`、`UIAliases`。本批次新增能力只落在 `HostRuntimePort.resolve_role_with` 与 `RuntimeContext.emit_vehicle_*`，并通过兼容别名维持旧调用稳定。测试依赖仍使用 `lua tests/regression.lua` 和 `lua tests/internal/dep_rules.lua` 两个既有入口。

本次修订说明（2026-03-02）：按用户“计划按格式重写”要求，重写 `.agents/plan.md` 为严格对齐 `./.agents/harness/PLANS.md` 的结构化版本，保留已执行事实与验收证据，并将非进度章节统一为散文叙述以符合格式规范。
