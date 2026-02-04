# 修复 UI 事件到回合链路的输入门控与监听生命周期

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。本文件必须遵循仓库内 `.agents/PLANS.md` 的规范维护。

## 目的 / 全局视角

解决两类用户可见问题：第一是非道具阶段点击道具槽导致断言崩溃；第二是 UI 重载或节点重建后按钮不再响应。完成后，用户在非道具阶段点击道具槽不会崩溃，UI 监听可在重复绑定时安全重建，并且输入阻断规则集中一致。验证方式是运行回归脚本以及通过手动场景观察“点击不崩溃、重绑不失效”。

## 进度

- [x] (2026-02-04 10:05Z) 创建并初始化可执行计划
- [x] (2026-02-04 10:22Z) 实现统一输入门控与 item_slot 保护
- [x] (2026-02-04 10:23Z) 引入监听生命周期管理与重复绑定安全性
- [x] (2026-02-04 10:24Z) 让 UIEventHandlers 支持重复安装并更新 state/logger
- [x] (2026-02-04 10:24Z) 更新 UI 道具槽触摸可用性逻辑
- [x] (2026-02-04 10:26Z) 运行回归脚本并记录结果

## 意外与发现

暂无意外发现。

## 决策日志

- 决策：不新增单点使用的分层文件，优先在现有模块内完成门控与拆分。
  理由：遵守 CodingDiscipline 中“少于 2 个调用点不新增层”的要求，减少概念数量。
  日期/作者：2026-02-04 / Codex。

- 决策：将输入阻断逻辑抽为 `turn_dispatch.should_block_action`，供 UIEventRouter 与 TurnDispatch 共享。
  理由：消除重复规则并保持行为一致。
  日期/作者：2026-02-04 / Codex。

- 决策：在 UIEventRouter 与 TurnDispatch 双层保护 item_slot_*，避免非道具阶段崩溃。
  理由：UI 侧防误触，逻辑层防外部调用。
  日期/作者：2026-02-04 / Codex。

- 决策：UIEventHandlers 通过模块级引用更新 state/logger，避免重复注册。
  理由：保持事件注册单次且支持热更新。
  日期/作者：2026-02-04 / Codex。

## 结果与复盘

已完成输入门控统一、监听生命周期管理、item_slot 保护、UIEventHandlers 重入支持与道具槽触摸控制。回归脚本通过，未发现新增回归风险。后续若出现 UI 重建场景，可直接调用 `ui_event_router.unbind` + `bind` 验证监听可用性。

## 背景与导读

UI 事件绑定逻辑位于 `src/ui/UIEventRouter.lua`，它负责将按钮点击转换为 intent 并调用 `src/game/turn/TurnDispatch.lua` 或 `src/ui/UIView.lua`。回合与选择流由 `src/game/turn/TurnManager.lua` 与 `src/game/choice/ChoiceManager.lua` 驱动。当前 item_slot_* 的处理在 `TurnDispatch` 中断言依赖 `pending_choice.kind == "item_phase_choice"`，而 UI 无条件启用道具槽点击，导致误触崩溃。UI 监听由 `UIManager.ENode:listen` 创建 `UIManager.Listener`，但 UIEventRouter 未保存与销毁监听句柄，重复绑定时无法重建监听。

## 工作计划

先在 `src/game/turn/TurnDispatch.lua` 增加统一输入门控 helper，并在 UIEventRouter 使用它以移除重复判断。随后在 UIEventRouter 中保存 listener 列表，并新增 `unbind` 释放旧监听与注册表，保证重复绑定安全。接着修复 item_slot_* 的崩溃路径：UI 层在点击时判断当前是否处于 item_phase_choice，逻辑层在 dispatch 前再做保护。然后修改 `src/ui/UIEventHandlers.lua` 让 install 可重复调用，通过模块级引用更新 logger/state。最后调整 `src/ui/UIView.lua` 的道具槽触摸可用性，使非道具阶段禁用点击。完成后运行回归脚本记录结果。

## 具体步骤

在仓库根目录执行以下步骤并随实现更新：

1. 编辑 `src/game/turn/TurnDispatch.lua`，新增 `should_block_action(state, action_type)` 并复用到 `dispatch_action`。
2. 编辑 `src/ui/UIEventRouter.lua`，使用 `should_block_action` 统一阻断，并新增 listener 列表与 `unbind`。
3. 编辑 `src/game/turn/TurnDispatch.lua` 与 `src/ui/UIEventRouter.lua`，对 item_slot_* 增加非道具阶段保护。
4. 编辑 `src/ui/UIEventHandlers.lua`，把 logger/state 变为模块级引用，允许重复 install 更新引用。
5. 编辑 `src/ui/UIView.lua`，根据 pending_choice 类型控制道具槽 touch_enabled。
6. 运行 `lua .agents/tests/regression.lua`，记录通过结果或失败输出。
7. 若需验证 UI 监听重绑，重复调用 `ui_event_router.bind(state, ...)` 并观察按钮点击是否生效。

## 验证与验收

运行 `lua .agents/tests/regression.lua`，预期输出包含 `All regression checks passed`。手动验证时，在非道具阶段点击道具槽不会崩溃且不会触发选择；重复调用 `ui_event_router.bind` 后按钮仍可响应。

## 可重复性与恢复

所有修改可重复执行。若需回退，恢复以下文件到变更前版本即可：`src/ui/UIEventRouter.lua`、`src/game/turn/TurnDispatch.lua`、`src/ui/UIEventHandlers.lua`、`src/ui/UIView.lua`。若出现未知行为，优先回退 listener 管理与 item_slot 保护改动。

## 产物与备注

产物为 `src/ui/UIEventRouter.lua`、`src/game/turn/TurnDispatch.lua`、`src/ui/UIEventHandlers.lua`、`src/ui/UIView.lua` 的行为修复。回归脚本输出摘要如下：

  ....................................
  All regression checks passed (36)

## 接口与依赖

新增或修改的接口包括：

- `turn_dispatch.should_block_action(state, action_type)`：统一输入阻断规则。
- `ui_event_router.unbind(state)`：释放 UI 监听并重置注册表。
- `state.ui_event_router_listeners`：保存 listener 列表用于销毁。

计划变更说明：更新进度状态、补充测试输出与结果复盘，确保计划与实际实现一致。
