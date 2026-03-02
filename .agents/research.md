# Monopoly 代码库深度重写研究（2026-03-02，R8 执行后复盘版）

技能使用：`clean-architecture-reviewer` + `doc-coauthoring`

## 研究范围与证据

- 扫描范围：`src/*`、`tests/internal/*`、`tests/suites/*`、`.agents/plan.md`。
- 执行证据（R8 完成后）：
  - `lua tests/internal/dep_rules.lua` -> `dep_rules ok`
  - `lua tests/regression.lua` -> `All regression checks passed (204)` + `dep_rules ok / tick ok / forbidden_globals ok`
  - `rg -n "state\\.ui\\." src/game/flow/turn` -> 无命中（turn 用例层已去直读）
  - `rg -n "GameAPI\\.get_timestamp|GameAPI\\.get_timestamp_diff|os\\.clock" src/game/flow/turn/GameplayLoopPorts.lua` -> 无命中（默认 clock 已去环境直连）
- 热点模块规模（当前）：
  - `GameplayLoopPorts.lua`：319 行
  - `GameplayLoop.lua`：266 行
  - `TickTimeout.lua`：244 行
  - `TurnDispatchValidator.lua`：166 行

## 架构结论

R8（M32-M36）已执行完成，Use Case 对 UI 字段结构与默认时钟环境细节的直接耦合已收口。  
架构从“边界泄漏治理”进入“兼容写入逐步退役 + 热点进一步瘦身”阶段。  
依赖规则与全量回归保持全绿，当前主风险从“正确性”转向“复杂度与全局兼容债务”。

## 主要问题（P0-P3）

- P0（阻断级）：未发现。
  - 证据：`dep_rules`、`regression` 持续全绿。

- P1（高优先级）：运行时全局写入仍存在兼容债务。
  - 现状：已新增 `RuntimeCompat` 收敛读取入口（3 个函数：`get_roles`/`get_vehicle_helper`/`get_camera_helper`，均为"context 优先，legacy 全局回退"），但 `RuntimeContext.install_runtime_helper_globals()` 仍向 4 个全局符号写入（`all_roles`/`ALLROLES`/`vehicle_helper`/`camera_helper`）。
  - 调用方分布（共 9 个文件、20+ 调用点）：
    - `src/app/bootstrap/GameStartup.lua`（`get_roles`）
    - `src/presentation/render/status3d_service/scene.lua`（`get_roles`）
    - `src/presentation/render/MoveAnim.lua`（`get_vehicle_helper` ×5）
    - `src/presentation/render/board_runtime/player_units.lua`（`get_roles`）
    - `src/presentation/render/board_runtime/placement.lua`（`get_vehicle_helper`）
    - `src/presentation/interaction/ui_intent_dispatcher/ViewCommandDispatcher.lua`（`get_roles`）
    - `src/presentation/api/UIRuntimePort.lua`（`get_roles`）
    - `src/presentation/api/presentation_ports/UISyncPorts.lua`（`get_camera_helper`）
    - `src/game/core/runtime/player_state/StatusOps.lua`（`get_vehicle_helper` ×2）——注意此文件位于 game core 层，意味着 core 已依赖 compat 桥。
  - 风险：长期会抬高替换运行时/隔离测试上下文的成本。`StatusOps` 的位置使得 game core 对 compat 层产生了交叉依赖，后续收紧回退行为时需优先处理。

- P2（中优先级）：turn 链路热点文件仍偏大。
  - 现状：M35 已拆出 `TurnActionGate`（85 行）、`TickUIGate`（42 行），但 `GameplayLoopPorts`（319 行）与 `TickTimeout`（265 行）仍较长。
  - 结构分析：
    - `GameplayLoopPorts` 内部沿 6 个 port group（modal/anim/ui_sync/debug/clock/state）组织——其中 `_fill_ui_sync_defaults`（约 80 行）和 `_fill_clock_defaults`（约 15 行）是纯适配逻辑，可独立为 port 默认值填充模块。`_base_*_ports()` 工厂函数与 `_build_resolved_ports`/`_copy_group_ports` 的 merge 逻辑也可剥离。
    - `TickTimeout` 内部混合了三类职责：choice 超时策略（`step_choice_timeout` 约 55 行）、modal 超时策略（`step_modal_timeout` 约 35 行）和默认策略工厂（`default_policy`/`step_default_choice`/`step_default_modal` 约 50 行）。策略工厂与超时引擎可分离。
  - 风险：后续改动仍可能集中在少数大文件。

- P3（改进项）：契约测试已覆盖关键边界，但可继续扩“目录完整性”与“兼容退役条件”。
  - 现状：`ui_gate_contract` 已接入；可继续补运行时兼容退役契约。

## R8 实施结果（M32-M36）

1. M32（已完成）：UIGatePort 收口
   - 结果：`TurnDispatchValidator`、`TickTimeout`、`TickUISync` 不再直读 `state.ui.*`。
   - 新增能力：`ui_sync.resolve_ui_gate(state)` 作为统一门控 DTO 入口。

2. M33（已完成）：ClockPort 收口
   - 结果：`GameplayLoopPorts` 默认 clock 去除 `GameAPI/os.clock` 直连。
   - 新增能力：通过 `RuntimePorts` + `presentation_ports/ClockPorts` 注入时钟语义。

3. M34（已完成）：运行时读取收敛
   - 结果：新增 `src/core/RuntimeCompat.lua`，核心路径改为“context 优先，legacy 全局回退”。
   - 说明：本轮未强制移除 legacy 全局写入，采用低风险渐进策略。

4. M35（已完成）：热点职责拆分
   - 结果：新增 `TurnActionGate.lua`、`TickUIGate.lua`，`TurnDispatchValidator`/`TickTimeout` 职责下沉。
   - 说明：本轮聚焦职责切分，不做机械行数目标压缩。

5. M36（已完成）：契约与规则加固
   - 结果：新增 `tests/suites/ui_gate_contract.lua` 并接入 `tests/regression.lua`。
   - 结果：回归基线由 `202` 提升到 `204`（新增测试条目导致）。

## 测试建议（下一阶段维持项）

- 用例级测试：
  - 持续覆盖 `GameplayLoop.tick`、`TurnDispatch` 的节流/阻塞/超时联动。
- 边界契约测试：
  - 继续维护 `ui_gate_contract`、`usecase_boundary_contract`、`cross_module_contract`。
- 依赖规则测试：
  - 保持 `dep_rules` 中对 `src/game/flow/turn/*` 直接读取 `state.ui.*` 的禁用守护。

## 权衡说明

- 短期成本：
  - 模块数增加、端口/契约层变厚，理解入口增多。
- 长期收益：
  - UI 与时间源变更不再直接冲击 turn 用例层，回归稳定性提升。
  - 读取入口统一后，后续退役 legacy 全局写入的路径更清晰。
- 结论：
  - R8 的取舍正确，属于“先稳边界，再消兼容债务”的低风险演进。

## 下一轮研究重点（R9 建议）

1. 以 `RuntimeCompat` 为锚点，定义 legacy 全局写入退役清单与阶段性禁用规则。清单应包含上述 P1 中列出的 9 个调用方文件及其具体调用函数。特别注意 `StatusOps.lua` 位于 game core 层的交叉依赖——它应在契约收紧前被优先迁移或显式标注为白名单。
2. 继续拆分 `GameplayLoopPorts` / `TickTimeout` 的策略与适配职责，降低热点聚集度。建议拆分边界：
   - `GameplayLoopPorts`：将 `_fill_ui_sync_defaults` + `_fill_clock_defaults` 抽为 `GameplayLoopPortDefaults.lua`；将 `_base_*_ports()` 工厂和 `_copy_group_ports`/`_build_resolved_ports` merge 逻辑保留在主文件。
   - `TickTimeout`：将 `default_policy` + `step_default_choice` + `step_default_modal` 抽为 `TickTimeoutPolicy.lua`；主文件保留 `step_choice_timeout`/`step_modal_timeout` 引擎。
3. 为兼容退役建立契约测试（例如"context 可用时不得回退全局"）。建议设计：构造有效 `RuntimeContext` 并设置 `ctx.roles`，同时向全局 `all_roles` 写入不同值，调用 `runtime_compat.get_roles()` 后断言返回 `ctx.roles` 而非全局；`get_vehicle_helper`/`get_camera_helper` 同理。

## 最终评审结论

R8 目标已完成且被自动化验证证明有效。  
代码库已从“边界泄漏修复”阶段进入“兼容债务清理与复杂度持续下降”阶段。  
下一步应以可回滚、可验证方式推进全局兼容桥的渐进退役。
