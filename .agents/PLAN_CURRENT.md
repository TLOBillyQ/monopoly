# 步骤2-5：可维护性重构可执行计划（流程层、输入层、选择/道具、地块规则）


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件遵循 `/Users/billyq/Dev/Github/Lua/monopoly/.agents/PLANS.md` 维护。

## 目的 / 全局视角

这次重构聚焦步骤2-5：拆分流程层与 UI 适配层、拆分 TurnDispatch 的输入校验与状态推进、拆分选择/道具系统的注册与执行、拆分地块规则计算与事件副作用。完成后，核心流程不再直接依赖 UI 实现，输入校验可独立测试，选择与道具处理具有更清晰的扩展点，地块规则逻辑更易验证。可见结果：跑现有脚本时行为不变，且新结构可通过更小的单元测试验证。

## 进度

- [x] (2025-03-04 12:00Z) 建立流程端口分层与适配器边界（步骤2）。
- [x] (2025-03-04 12:00Z) 拆分 TurnDispatch 的校验与执行（步骤3）。
- [x] (2025-03-04 12:00Z) 拆分选择/道具的注册与执行（步骤4）。
- [x] (2025-03-04 12:00Z) 拆分地块规则与事件副作用（步骤5）。
- [x] (2025-03-04 12:00Z) 回归验证与依赖检查。

## 意外与发现

- 观察：`GameplayLoop` 直接访问 `state.ui`，已改为通过端口访问。
  证据：`src/game/flow/turn/GameplayLoop.lua` 中 `state.ui` 访问已移除。
- 观察：回归失败来自缺省端口未提供 `is_input_blocked` 等方法。
  证据：补齐端口默认方法后 `regression.lua` 通过。

## 决策日志

- 决策：采用“接口先行、适配器收敛”的拆分策略。
  理由：在不改行为的前提下先切断依赖方向，降低改动风险。
  日期/作者：2025-03-04 / Codex
- 决策：选择/道具注册移动到 `CompositionRoot` 统一初始化。
  理由：避免在解析时隐式注册，保证生命周期清晰。
  日期/作者：2025-03-04 / Codex

## 结果与复盘

步骤2-5已完成结构拆分并通过回归验证，流程层依赖方向更清晰，地块规则与副作用分离。

## 背景与导读

关键模块与关系如下。

`src/game/flow/turn/GameplayLoop.lua` 是主循环，直接依赖 `GameplayLoopPorts`，当前默认端口 `src/presentation/api/GameplayLoopPortsAdapter.lua` 同时处理 UI、动画、日志与调试可视化。`src/game/flow/turn/TurnDispatch.lua` 同时负责输入校验与状态推进，导致逻辑混杂。`src/game/systems/choices/ChoiceResolver.lua` 与 `src/game/systems/items/ItemRegistry.lua` 同时承担注册、分发、执行与意图派发。`src/game/systems/land/LandActions.lua` 同时计算规则、修改状态、发事件。

本计划要求把“规则/流程”与“表现/副作用”分离。术语说明：

“端口”指流程层暴露的一组函数，由 UI 适配层实现；流程层只能依赖端口接口而不直接依赖 UI 代码。
“副作用”指事件广播、弹窗、动画、日志等对外表现或外部系统调用。

## 工作计划

先梳理当前端口定义，新增一个“流程端口接口文件”，并把默认适配器收敛到接口实现，确保流程层只依赖接口。随后拆分 TurnDispatch：把动作校验抽出为纯函数模块，执行器只负责状态推进。再拆分 ChoiceResolver/ItemRegistry：注册与执行分层，handler 不直接派发意图而是返回结构化结果，由上层统一派发。最后拆分 LandActions：把规则计算与事件副作用拆成两个模块，规则模块只返回结果，事件模块负责广播与弹窗。

为降低风险，拆分采用“先并行后替换”：先引入新模块并保持旧路径可用，完成单元验证后再切换主调用路径并删除冗余。

## 具体步骤

1) 步骤2：流程端口分层与适配器边界。

在 `src/game/flow/turn/GameplayLoopPorts.lua` 中补充明确的端口接口注释与默认空实现，并新增一个新文件 `src/game/flow/turn/GameplayLoopPortTypes.lua`（仅定义接口结构说明与字段含义，不含实现）。更新 `src/presentation/api/GameplayLoopPortsAdapter.lua`，让其成为接口的唯一默认实现；在 `GameplayLoop` 中避免直接访问 UI 字段，改为通过端口方法传递必要状态。若必须读取 UI 状态，先在端口接口中新增明确函数，如 `is_input_blocked(state)`、`is_popup_active(state)`，由 UI 适配器实现，流程层不再直接读 `state.ui`。

2) 步骤3：拆分 TurnDispatch 的校验与执行。

新增 `src/game/flow/turn/TurnDispatchValidator.lua`，包含纯函数：
- `should_block_action(state, action)`
- `validate_actor_role(game, action)`
- `validate_choice_actor(game, action, choice)`
- `validate_choice_action(game, action, choice)`

`TurnDispatch.lua` 保留 `dispatch_action` 与 `step_turn`，但内部先调用 Validator；校验失败只返回 `{ status = "rejected" }` 并不触发状态修改。保持现有行为与日志一致。确保 `TurnDispatch` 不再直接包含复杂校验逻辑，方便单测。

3) 步骤4：拆分选择/道具的注册与执行。

新增 `src/game/systems/choices/ChoiceRegistry.lua`，只负责注册与获取 handler；`ChoiceResolver` 改为只负责分发与基础校验，不直接构建 defaults。将默认 handler 注册移动到 `ChoiceRegistry.register_defaults`，由 `CompositionRoot.assemble` 在初始化时显式调用。

新增 `src/game/systems/items/ItemExecutor.lua` 保持现有职责，但 `ItemRegistry` 只负责注册与查找 handler，不再内含大段执行逻辑。将 `_handle_target_player_item`、`_handle_remote_dice`、`_handle_roadblock`、`_handle_demolish` 移到新文件 `src/game/systems/items/ItemHandlers.lua`，由 `ItemRegistry.register_defaults` 引用。

同时调整 ChoiceHandler 内部：尽量返回结构化结果（如 `{ intent = ... }`），由上层统一派发，减少 handler 直接调度 `IntentDispatcher` 的次数。保持行为不变，但集中派发位置更清晰。

4) 步骤5：拆分地块规则与事件副作用。

新增 `src/game/systems/land/LandRules.lua`，只包含规则计算与状态修改，返回结构化事件结果，例如 `{ event = monopoly_event.land.rent_paid, payload = {...} }`。新增 `src/game/systems/land/LandEvents.lua`，负责把规则结果转换为 `_emit_event` 调用与弹窗/日志。`LandActions.lua` 变为组合器：调用 `LandRules`，再调用 `LandEvents` 执行副作用。保持外部调用点不变。

5) 回归验证与依赖检查。

在完成每个步骤后运行回归脚本，确保行为一致；最后统一运行依赖检查脚本。若出现差异，优先回滚到上一步并记录在“意外与发现”。

## 验证与验收

在仓库根目录执行：

    lua .agents/tests/regression.lua
    lua .agents/tests/gameplay_loop_no_ui.lua
    lua .agents/tests/dep_rules.lua

预期：全部通过；`gameplay_loop_no_ui.lua` 输出 `tick ok`；依赖检查无违规提示。

## 可重复性与恢复

每个步骤均为增量改动，可独立回滚。若端口拆分导致 UI 走不通，可先切回旧端口实现，保留新接口文件以便后续继续。

## 产物与备注

预期新增/修改：

    src/game/flow/turn/GameplayLoopPortTypes.lua
    src/game/flow/turn/TurnDispatchValidator.lua
    src/game/systems/choices/ChoiceRegistry.lua
    src/game/systems/items/ItemHandlers.lua
    src/game/systems/land/LandRules.lua
    src/game/systems/land/LandEvents.lua
    src/game/flow/turn/GameplayLoopPorts.lua
    src/presentation/api/GameplayLoopPortsAdapter.lua
    src/game/flow/turn/GameplayLoop.lua
    src/game/flow/turn/TurnDispatch.lua
    src/game/systems/choices/ChoiceResolver.lua
    src/game/systems/items/ItemRegistry.lua
    src/game/systems/land/LandActions.lua
    src/game/core/runtime/CompositionRoot.lua

## 接口与依赖

- `GameplayLoop` 只能依赖 `GameplayLoopPorts` 与端口接口函数，禁止直接读取 `state.ui`。
- `TurnDispatchValidator` 为纯函数模块，不得修改游戏状态。
- `ChoiceRegistry` 与 `ItemRegistry` 只负责注册与查找，不处理业务副作用。
- `LandRules` 不允许调用 `_emit_event` 或弹窗；`LandEvents` 只执行副作用。

---

变更说明（2025-03-04 / Codex）：清空旧计划，写入步骤2-5可执行重构计划，强调端口分层、校验拆分、注册/执行分离与地块规则拆分。
变更说明（2025-03-04 / Codex）：完成步骤2-5代码改造，记录端口改造与注册初始化决策，待执行回归验证。
变更说明（2025-03-04 / Codex）：补齐端口默认方法并完成全部回归验证，更新进度与复盘。
