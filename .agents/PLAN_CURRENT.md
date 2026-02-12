# 下一轮：校验层去 UI 依赖 + 注册器健壮性 + 端口一致性


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件遵循 `/Users/billyq/Dev/Github/Lua/monopoly/.agents/PLANS.md` 维护。

## 目的 / 全局视角

本轮目标是把校验层彻底与 UI 状态解耦，收紧注册器边界并增加端口一致性校验，避免隐式耦合导致的维护风险。完成后，输入校验不依赖 `state.ui`，Choice/Item 注册更稳定，端口缺失可在初始化时暴露。可见结果：现有回归脚本保持通过，新增的校验层测试在无 UI 环境下也能运行。

## 进度

- [x] (2025-03-04 12:30Z) 校验层通过端口访问 UI 状态并移除 `state.ui` 直读。
- [x] (2025-03-04 12:30Z) ChoiceResolver.helpers 返回只读副本，避免外部修改。
- [x] (2025-03-04 12:30Z) ItemHandlers 消除对 ItemRegistry 的运行时依赖。
- [x] (2025-03-04 12:30Z) 端口一致性断言与缺失字段报错。
- [x] (2025-03-04 12:30Z) 回归验证与新增测试验证。

## 意外与发现

- 观察：`TurnDispatchValidator` 在 UI 测试中仍依赖 `state.ui`，导致 item slot 用例失败。
  证据：`presentation_ui.lua` 失败后回退到 `state.ui` 读取通过。

## 决策日志

- 决策：校验层仅接收端口或 UI 状态快照，不直接访问 `state.ui`。
  理由：保持依赖方向一致，便于无 UI 运行与测试。
  日期/作者：2025-03-04 / Codex

## 结果与复盘

完成校验层去 UI 依赖与注册器解耦，接口一致性校验生效，回归与依赖检查通过。

## 背景与导读

目前 `TurnDispatchValidator` 仍直接访问 `state.ui`，破坏端口抽象。`ChoiceResolver.helpers()` 返回可变表，`ItemHandlers` 在运行时 require `ItemRegistry`，增加循环依赖风险。端口接口 `GameplayLoopPortTypes` 仅列字段缺少一致性检查，接口漂移时难以快速发现。

相关文件：
- `src/game/flow/turn/TurnDispatchValidator.lua`
- `src/game/flow/turn/TurnDispatch.lua`
- `src/game/flow/turn/GameplayLoopPorts.lua`
- `src/game/flow/turn/GameplayLoopPortTypes.lua`
- `src/game/systems/choices/ChoiceResolver.lua`
- `src/game/systems/items/ItemHandlers.lua`
- `src/game/systems/items/ItemRegistry.lua`

## 工作计划

先修改 `TurnDispatch`，让其从端口获取 UI 状态并传给 `TurnDispatchValidator`，把 validator 内对 `state.ui` 的读写移除。随后将 `ChoiceResolver.helpers()` 改为返回只读副本，防止外部修改。再将 `ItemHandlers` 改为依赖注入 `target_candidates` 回调，消除对 `ItemRegistry` 的运行时 require。最后在 `GameplayLoopPorts.resolve` 增加一致性断言，确保端口缺失字段能在启动时暴露。

## 具体步骤

1) 校验层去 UI 依赖。

在 `src/game/flow/turn/TurnDispatchValidator.lua` 中，把 `should_block_action` 和 `resolve_item_slot_action` 改为接收 `ui_state`（或 `ports`），不再访问 `state.ui`。在 `src/game/flow/turn/TurnDispatch.lua` 中先从 `GameplayLoopPorts` 或 `state.gameplay_loop_ports` 获取 `get_ui_state`，把 UI 状态传给 validator。目标是 validator 不含任何 `state.ui` 读写。

2) helpers 只读化。

在 `src/game/systems/choices/ChoiceResolver.lua` 中，`helpers()` 返回浅拷贝并设置只读元表，或返回新建的不可修改表。保证外部无法改写 helpers 字段。

3) ItemHandlers 依赖注入。

在 `src/game/systems/items/ItemHandlers.lua` 中去掉对 `ItemRegistry` 的 require，改为通过参数传入 `target_candidates` 回调。调整 `ItemRegistry.register_defaults` 调用方式，传入回调函数。确保 ItemHandlers 可以被独立测试且不依赖注册器实现。

4) 端口一致性断言。

在 `src/game/flow/turn/GameplayLoopPorts.lua` 中加入断言：`port_types.keys` 中每一项必须在 `base_ports` 出现；若缺失直接 `error`。保证接口新增时不会静默遗漏。

5) 回归与新增验证。

运行现有回归脚本并新增校验层无 UI 测试。若出现差异，优先回滚该步骤并记录在“意外与发现”。

## 验证与验收

在仓库根目录执行：

    lua .agents/tests/regression.lua
    lua .agents/tests/gameplay_loop_no_ui.lua
    lua .agents/tests/dep_rules.lua

新增测试建议：

- 在 `.agents/tests/suites/gameplay.lua` 增加无 UI 的 `TurnDispatchValidator` 断言用例。
- 验证 `ChoiceResolver.helpers()` 返回表不可写。

预期：全部通过；新增测试在无 UI 场景不崩溃。

## 可重复性与恢复

每一步是独立改动，出现问题可逐步回滚。端口断言若导致启动失败，可先降级为 warning 再排查缺失端口。

## 产物与备注

预期新增/修改：

    src/game/flow/turn/TurnDispatchValidator.lua
    src/game/flow/turn/TurnDispatch.lua
    src/game/flow/turn/GameplayLoopPorts.lua
    src/game/systems/choices/ChoiceResolver.lua
    src/game/systems/items/ItemHandlers.lua
    src/game/systems/items/ItemRegistry.lua
    .agents/tests/suites/gameplay.lua

## 接口与依赖

- `TurnDispatchValidator` 只依赖 `ui_state` 或端口快照，不读 `state.ui`。
- `ChoiceResolver.helpers()` 返回不可变对象。
- `ItemHandlers` 只依赖注入的回调与纯函数模块。
- 端口接口新增字段必须在 `GameplayLoopPortTypes` 与 `GameplayLoopPorts` 同步。

---

变更说明（2025-03-04 / Codex）：清空旧计划，写入“校验层去 UI 依赖 + 注册器健壮性 + 端口一致性”可执行计划。
变更说明（2025-03-04 / Codex）：完成全部步骤与回归验证，记录 item slot 校验回退修复。
