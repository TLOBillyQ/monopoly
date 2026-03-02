# Monopoly 兼容层 P1 清理可执行计划（角色解析统一 + 载具事件命名收敛 + 注释噪音清理）

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件遵循 `./.agents/harness/PLANS.md` 维护，执行者可仅凭当前工作树与本文件从零恢复工作。

## 目的 / 全局视角

本计划解决的用户可见问题是：兼容层命名与角色解析路径存在历史包袱，导致状态 3D 模块重复回退、载具事件接口语义不直观、注释术语不一致。完成后，调用方将通过统一入口解析角色，载具事件接口命名更贴近业务语义，文档与测试注释中的 legacy/compat 噪音减少，同时保持行为与回归结果不变。生效证据是全量回归持续通过，且代码搜索结果显示 status3d 不再手写二次 fallback、调用方已迁移到语义化事件名。

## 进度

- [x] (2026-03-02T07:15Z) 完成现状核查并固化证据：`HostRuntimePort.resolve_role` 回退链、status3d 双轨 fallback、`forward_eca_event_*` 调用分布、legacy 注释分布。
- [x] (2026-03-02T07:26Z) 完成 P1.1：新增 `resolve_role_with(predicate)`，并迁移 `status3d_service/scene.lua` 与 `status.lua` 到统一入口。
- [x] (2026-03-02T07:27Z) 完成 P1.2：`RuntimeContext` 新增 `emit_vehicle_*`，保留 `forward_eca_event_*` 兼容别名，核心调用点完成迁移（兼容回退到旧名）。
- [x] (2026-03-02T07:28Z) 完成 P1.3：清理 tests/docs 注释层 legacy/compat 表述，不改行为代码。
- [x] (2026-03-02T07:29Z) 完成回归验收与文档回填（全量回归通过，研究文档回填执行证据）。

## 意外与发现

- 观察：`HostRuntimePort.resolve_role` 已经包含一次回退到 `resolve_game_role`，但 status3d 模块仍重复执行第二次回退，形成“功能可用但职责重复”的双轨实现。
  证据：`src/presentation/api/HostRuntimePort.lua:33-49`，`src/presentation/render/status3d_service/scene.lua:8-18`，`src/presentation/render/status3d_service/status.lua:7-17`。
- 观察：`forward_eca_event_*` 已跨 core/game/presentation 三层被直接调用，无法直接删除原名接口，只能走“别名兼容 + 分批迁移”。
  证据：`src/game/core/runtime/player_state/StatusOps.lua:25,28,79`，`src/presentation/render/MoveAnim.lua:117,122`，`src/presentation/render/board_runtime/placement.lua:123`。
- 观察：legacy/compat 术语仍存在于测试断言和架构文档注释，属于低风险可清理项。
  证据：`tests/suites/runtime_ports_contract.lua:65-67`，`docs/architecture/presentation_canvas_first.md:37,48`。
- 观察：核心调用点迁移到新命名时，测试桩与部分运行时注入仍可能只提供旧字段，因此调用方需要“优先新名、回退旧名”的兼容调用。
  证据：`StatusOps.lua`、`MoveAnim.lua`、`placement.lua` 已采用 `emit_vehicle_* or forward_eca_event_*` 双路径。

## 决策日志

- 决策：P1 先做角色解析统一，再做载具事件命名迁移，最后做注释清理。
  理由：角色解析统一改动面最小且可快速验证；事件命名迁移涉及跨层调用点，需在稳定解析链后进行；注释清理放最后避免干扰功能验证。
  日期/作者：2026-03-02 / Codex GPT-5.3-Codex。
- 决策：保留 `forward_eca_event_*` 作为兼容别名直到所有调用点迁移完成，并由回归测试守护。
  理由：当前调用面分散，立即硬删会引入高风险回归。
  日期/作者：2026-03-02 / Codex GPT-5.3-Codex。

## 结果与复盘

P1 已完成并通过回归验证。行为保持证据是 `lua tests/regression.lua` 继续全绿（209 项，含 dep_rules/tick/forbidden_globals）。接口收敛结果为：status3d 不再手写 `resolve_game_role` 二次 fallback，统一通过 `HostRuntimePort.resolve_role_with` 进行谓词校验；载具事件接口新增语义化 `emit_vehicle_*`，旧 `forward_eca_event_*` 保留为兼容别名并继续可用。剩余技术债是全仓仍有大量测试桩使用旧命名，后续可在独立批次中逐步迁移测试桩并最终评估是否退役别名。

## 背景与导读

本计划涉及四组关键文件。第一组是角色解析入口：`src/presentation/api/HostRuntimePort.lua`，它向表现层提供运行时能力封装。第二组是 status3d 模块：`src/presentation/render/status3d_service/scene.lua` 与 `status.lua`，当前各自实现 `_resolve_role` 并重复 fallback。第三组是载具事件转发：`src/core/RuntimeContext.lua` 定义 `forward_eca_event_*`，调用方主要分布在 `StatusOps.lua`、`MoveAnim.lua`、`placement.lua`。第四组是注释文本：`tests/suites/runtime_ports_contract.lua` 与 `docs/architecture/presentation_canvas_first.md`。

文中“谓词”指一个返回布尔值的函数，用来表达“角色对象是否具备某个方法能力”。例如 scene 需要 `role.get_ctrl_unit`，status 需要 `role.set_label_text`。本计划通过统一入口接收谓词，避免每个模块重复写 fallback 链。

## 工作计划

先在 `HostRuntimePort.lua` 新增 `resolve_role_with(player_id, predicate)`，内部复用既有 `resolve_role` 与 `resolve_game_role`，并在一个函数里完成能力校验。随后将 `scene.lua` 与 `status.lua` 的 `_resolve_role` 重写为仅调用该统一入口，删除重复 fallback 逻辑。此步骤完成后先跑全量回归，确保行为不变。

第二步在 `RuntimeContext.lua` 引入语义化接口 `emit_vehicle_enter/exit/move/stop/set_position`，实现直接复用现有逻辑；原 `forward_eca_event_*` 保留并转调到新接口，作为兼容层。接着迁移核心调用点（`StatusOps.lua`、`MoveAnim.lua`、`placement.lua`）使用新接口，避免一次性改测试桩之外的大范围文件。

第三步仅处理注释与文案，不改运行时行为。优先清理 `runtime_ports_contract.lua` 的断言文案和 `presentation_canvas_first.md` 的 compatibility 表述，保持语义一致并避免误导“可立即删除兼容层”的解读。

## 具体步骤

以下命令均在仓库根目录执行：`C:\Users\Lzx_8\Desktop\dev\repo\monopoly`。

先建立基线：

    lua tests/internal/dep_rules.lua
    lua tests/regression.lua

实现 P1.1 后验证：

    rg "resolve_game_role\\(" src/presentation/render/status3d_service -n
    lua tests/regression.lua

预期：status3d 目录内不再直接出现 `resolve_game_role(`，回归通过。

实现 P1.2 后验证：

    rg "forward_eca_event_|emit_vehicle_" src -n
    lua tests/regression.lua

预期：`RuntimeContext.lua` 同时存在新旧命名（旧名为兼容别名）；核心调用点迁移到 `emit_vehicle_*`；回归通过。

实现 P1.3 后验证：

    rg "legacy mode|compatibility wrappers|legacy bridge" tests docs -n -i
    lua tests/regression.lua

预期：仅保留必要术语，删除不必要历史噪音；回归通过。

最后收口：

    lua tests/internal/dep_rules.lua
    lua tests/regression.lua

## 验证与验收

验收标准以“行为不变 + 接口更清晰”为核心。行为不变由 `lua tests/regression.lua` 与 `lua tests/internal/dep_rules.lua` 共同证明。接口更清晰由三项可观察结果证明：其一，status3d 的角色解析通过统一入口完成；其二，核心调用点改用 `emit_vehicle_*` 命名且旧名仍可工作；其三，tests/docs 注释中不再保留误导性的 legacy/compat 表述。

验收记录必须写明最终回归通过数，并给出至少三条搜索证据：status3d 解析入口、事件命名迁移、注释清理结果。

## 可重复性与恢复

本计划按 P1.1 -> P1.2 -> P1.3 顺序执行，每步都可独立回归验证。若任一步失败，只回退该步骤触及文件并重新运行回归，不跨步骤打包回退。由于 P1.2 保留兼容别名，即使迁移未完成，也应保持主流程可运行。

若出现测试基线波动，优先记录在“意外与发现”，再决定是修正断言还是缩小改动面，不允许静默跳过失败测试。

## 产物与备注

    [evidence] lua tests/regression.lua -> All regression checks passed (209), dep_rules ok, tick ok, forbidden_globals ok
    [evidence] rg "resolve_game_role\\(" src/presentation/render/status3d_service -n -> No matches found
    [evidence] rg "forward_eca_event_|emit_vehicle_" src -n -> RuntimeContext 同时存在 emit_vehicle_* 与 forward_eca_event_*（别名转发），StatusOps/MoveAnim/placement 已迁移优先使用 emit_vehicle_*
    [evidence] rg "legacy mode|compatibility wrappers|legacy bridge" tests docs -n -i -> No matches found

## 接口与依赖

本计划不改变外部对 `RuntimePorts` 的契约，不删除 `set_legacy_global_fallback_enabled`，也不移除 `RuntimeEventBridge`、`MonopolyEvents`、`UIAliases`。新增接口应位于 `src/presentation/api/HostRuntimePort.lua` 与 `src/core/RuntimeContext.lua` 内，并复用既有依赖方向，不引入新的跨层全局依赖。

测试仍以仓库既有入口 `lua tests/regression.lua` 为主，`lua tests/internal/dep_rules.lua` 为守护补充。若需要补测试，优先在现有 suite 内增量补充，不新建无必要测试框架。

本次修订说明（2026-03-02）：按“修订 research.md，交付 .agents/plan.md”的请求，废弃旧的 tick 步骤4计划，重写为兼容层 P1 清理可执行计划，并补齐 PLANS.md 要求的活文档章节与可验证步骤。
本次修订说明（2026-03-02，执行回填）：已按计划完成 P1.1/P1.2/P1.3，更新进度、意外与发现、结果与复盘、产物证据；并记录“新命名优先 + 旧命名回退”的兼容迁移策略，以保证行为稳定与测试兼容。
