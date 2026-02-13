# 执行计划：TurnMove/UI 分发解耦、GameplayLoop Runner 合并、Router 去全局态与 IntentBuilder 模块化

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件遵循 `.agents/PLANS.md` 维护。

## 目的 / 全局视角

本计划分五阶段推进。第一阶段已完成 `TurnMove` 与 `UIIntentDispatcher` 的边界解耦。第二阶段完成 `GameplayLoop` 计时与锁职责下沉。第三阶段完成 `ai_runner` 与 `auto_runner` 合并。第四阶段完成 `UIEventRouter` 去全局 Provider 注册态，并通过 runtime 抽象统一角色上下文访问。第五阶段完成 `UIIntentBuilder` 按职责拆分为子模块，并保持对外 API 不变。验证标准是：行为不变、回归继续通过。

## 进度

- [x] (2026-02-13 09:20Z) 清空并重建 `PLAN_CURRENT.md`，切换到本次 SRP/DIP 解耦任务。
- [x] (2026-02-13 09:24Z) 修改 `TurnMove`：移除 `ui_port:push_popup` 直连，统一改为 `IntentDispatcher.dispatch`。
- [x] (2026-02-13 09:28Z) 修改 `UIIntentDispatcher`：拆分为 `dispatch_game_action` 与 `dispatch_view_command` 两条职责路径。
- [x] (2026-02-13 09:33Z) 新增 UI 分发器回归用例（market_confirm / market_select / popup_confirm）。
- [x] (2026-02-13 09:39Z) 运行回归测试并记录结果：`All regression checks passed (126)`。
- [x] (2026-02-13 09:40Z) 根据测试结果补充“结果与复盘”。
- [x] (2026-02-13 10:03Z) 新增 `GameplayLoopRuntime`，下沉输入锁/控制锁/按钮计时/detained 计时/阶段标记逻辑。
- [x] (2026-02-13 10:07Z) 精简 `GameplayLoop` 为编排入口，改为调用 `GameplayLoopRuntime`。
- [x] (2026-02-13 10:11Z) 新增回归用例：弹窗激活时阻断行动按钮超时自动推进。
- [x] (2026-02-13 10:15Z) 运行回归测试并记录第二阶段结果：`All regression checks passed (127)`。
- [x] (2026-02-13 10:16Z) 补充第二阶段“结果与复盘”。
- [x] (2026-02-13 10:29Z) 合并 `GameplayLoop` 的 `step_ai_turn_runner` 到 `step_auto_runner`，删除 AI runner 分支。
- [x] (2026-02-13 10:33Z) 清理遗留字段与初始化：移除 `ai_turn_runner` / `ai_turn_runner_active`。
- [x] (2026-02-13 10:37Z) 更新回归用例，统一改为验证单一 `step_auto_runner` 行为。
- [x] (2026-02-13 10:45Z) 运行回归测试并记录第三阶段结果：`All regression checks passed (127)`。
- [x] (2026-02-13 10:46Z) 补充第三阶段“结果与复盘”。
- [x] (2026-02-13 11:02Z) 重构 `UIEventRouter`：去除全局 Provider 注册态，改为按 bind 构建 route specs。
- [x] (2026-02-13 11:05Z) 新增 `runtime.get_client_role` 并迁移 Router 对 `UIManager.client_role` 的直接访问。
- [x] (2026-02-13 11:07Z) 删除废弃模块 `UIIntentProviders.lua` 并清理引用。
- [x] (2026-02-13 11:15Z) 新增 Router 调试按钮回归用例并通过全量回归：`All regression checks passed (128)`。
- [x] (2026-02-13 11:24Z) 新增 `intent_builders` 子模块：`BasicIntents/PopupIntents/ItemSlotIntents/ChoiceIntents/MarketIntents`。
- [x] (2026-02-13 11:27Z) 重写 `UIIntentBuilder` 为门面委托层，保留既有 `build_*_intents` 对外接口。
- [x] (2026-02-13 11:29Z) 执行全量回归验证第五阶段：`All regression checks passed (128)`。

## 意外与发现

- 观察：仓库测试入口文件注释仍以 `lua .agents/tests/regression.lua` 为基准。
  证据：`.agents/tests/regression.lua` 文件头注释。
- 观察：本轮新增 3 个 UI 分发器相关用例后，回归总通过数从 123 增至 126。
  证据：回归输出 `All regression checks passed (126)`。
- 观察：`GameplayLoop` 中计时和锁逻辑可独立成纯运行时辅助，不依赖 UI 具体实现细节。
  证据：提取后的 `GameplayLoopRuntime` 仅依赖 `ports` 抽象与回调。
- 观察：若 `tick` 仍传入“仅看 `player.auto`”的上下文，会让 AI 玩家在统一 runner 下不触发自动推进。
  证据：`GameplayLoop.tick` 的 `current_player_auto` 初值需纳入 `agent.is_auto_player(player)`。
- 观察：`UIEventRouter` 先前通过全局注册器持有 route provider，虽然可用，但会引入额外全局可变状态。
  证据：`_providers_registered + registry.register/build_specs` 仅在 Router 内部使用。
- 观察：`UIIntentBuilder` 的对外函数族（`build_basic_intents` 等）已被 `UIEventRouter` 直接依赖，适合采用“门面不变、实现下沉”的低风险重构。
  证据：`UIEventRouter._build_specs` 直接拼装上述函数返回值。

## 决策日志

- 决策：本轮采用“零行为变更优先”，先做边界解耦，不改变业务语义。
  理由：减少回归范围，优先解决 DIP/SRP 的结构风险。
  日期/作者：2026-02-13 / Copilot
- 决策：先改 `TurnMove` 再改 `UIIntentDispatcher`，暂不触达 `GameplayLoop` 大模块。
  理由：`TurnMove` 改造点集中、风险低、收益快，适合作为第一阶段。
  日期/作者：2026-02-13 / Copilot
- 决策：第二阶段采用“抽取运行时辅助模块”而非继续在 `GameplayLoop` 内部切私有函数。
  理由：模块边界更清晰，便于后续单测和维护，同时保持零行为变更。
  日期/作者：2026-02-13 / Copilot
- 决策：第三阶段移除 `step_ai_turn_runner` 与 `ai_turn_runner*` 状态，统一由 `step_auto_runner` 驱动 AI 与托管玩家。
  理由：避免双 runner 的状态分叉和重复逻辑，降低维护成本。
  日期/作者：2026-02-13 / Copilot
- 决策：第四阶段删除 `UIIntentProviders`，改为 `UIEventRouter` 局部构建 route specs。
  理由：减少全局状态与跨模块跳转，保持行为不变同时提升可读性。
  日期/作者：2026-02-13 / Copilot
- 决策：第五阶段对 `UIIntentBuilder` 采用“模块拆分 + 门面转发”策略，不改调用方。
  理由：在提升 SRP 的同时，把回归风险限制在实现细节层，避免扩散到 `UIEventRouter` 与绑定层。
  日期/作者：2026-02-13 / Copilot

## 结果与复盘

第一阶段目标已完成：`TurnMove` 去掉 UI 直连，`UIIntentDispatcher` 完成职责拆分，新增 3 条分发回归并全量通过（126）。

第二阶段已完成代码改造与测试补充：新增 `GameplayLoopRuntime` 并由 `GameplayLoop` 调用；新增“弹窗激活阻断按钮超时”回归用例，回归通过（127）。

第三阶段已完成代码改造：`GameplayLoop` 不再区分 AI/托管双 runner；`app/init` 与测试桩中的 `ai_turn_runner*` 遗留字段已清理；`gameplay` 回归用例已更新为统一 runner 语义。全量回归通过（127）。

最终结论：第三阶段回归通过（127），说明 runner 合并与遗留清理未引入行为回归。`GameplayLoop` 的自动推进逻辑现统一由 `step_auto_runner` 负责，后续维护将不再面临双路径一致性问题。

第四阶段结论：回归通过（128），`UIEventRouter` 已完成去全局态重构并删除遗留模块 `UIIntentProviders`，路由构建与角色上下文处理更直观且可测试性更高。

第五阶段结论：回归通过（128），`UIIntentBuilder` 已拆分为多个职责单一的子模块，原有门面函数保持不变，调用方无需修改。

## 背景与导读

核心文件如下：

- `src/game/flow/turn/TurnMove.lua`：移动阶段状态机，处理偷窃/黑市中断与落地衔接。
- `src/game/flow/intent/IntentDispatcher.lua`：游戏侧统一意图分发器，负责 `need_choice` 与 `push_popup`。
- `src/presentation/interaction/UIIntentDispatcher.lua`：表现层意图调度入口，连接 `TurnDispatch` 与 `UIView`。
- `src/game/flow/turn/GameplayLoop.lua`：主循环编排入口。
- `src/game/flow/turn/GameplayLoopRuntime.lua`：主循环运行时辅助（锁、计时、阶段标记）。
- `src/app/init.lua`：运行态状态初始化（runner 字段定义位置）。
- `src/presentation/interaction/UIEventRouter.lua`：UI 事件路由入口。
- `src/presentation/api/UIRuntimePort.lua`：角色上下文读写抽象。
- `.agents/tests/suites/presentation_ui.lua`：表现层回归集合，适合添加 UI 意图分发边界测试。
- `.agents/tests/suites/gameplay.lua`：回合循环与计时行为回归集合。

术语说明：

- “流程层”指 `game/flow` 中推进回合和状态转换的代码。
- “视图命令”指只影响 UI 本地状态的操作（如更新黑市选中项、关闭弹窗）。

## 工作计划

前三阶段已完成。第四阶段把 `UIEventRouter` 的 route 规格构建收敛到局部函数、删除全局 Provider 注册态，并将 Router 中角色上下文访问统一到 runtime 抽象，再执行全量回归验证。

## 具体步骤

在仓库根目录执行：

    lua .agents/tests/regression.lua

预期：全部测试通过，并输出通过总数。

## 验证与验收

验收标准：

1. `TurnMove` 不再直接调用 `ui_port:push_popup`。
2. `UIIntentDispatcher` 内部存在清晰的“游戏动作分发”和“视图命令分发”边界。
3. `GameplayLoop` 的锁与计时细节下沉到 `GameplayLoopRuntime`。
4. `GameplayLoop` 不再存在 `step_ai_turn_runner` 与 `ai_turn_runner*` 运行态依赖。
5. `UIEventRouter` 不再依赖全局 Provider 注册态，且 `UIIntentProviders` 已移除。
6. `UIIntentBuilder` 完成模块化拆分，且保留原有 `build_*_intents` 接口。
7. 新增/更新回归用例通过，且全量回归通过。

## 可重复性与恢复

本次修改为增量重构，可重复执行。若出现回归，按以下顺序回退：

1. 回退第三阶段 runner 合并与遗留清理。
2. 回退 `GameplayLoopRuntime` 抽取与 `GameplayLoop` 调用改造。
3. 回退 `UIIntentDispatcher` 拆分。
4. 回退 `TurnMove` 的意图分发改造。
5. 删除新增回归用例并复跑全量测试定位。
6. 若需要回退第四阶段，恢复 `UIIntentProviders` 并回退 `UIEventRouter` 局部 route 构建。

## 产物与备注

本轮预计产物：

- 修改：`src/game/flow/turn/TurnMove.lua`
- 修改：`src/presentation/interaction/UIIntentDispatcher.lua`
- 修改：`.agents/tests/suites/presentation_ui.lua`
- 新增：`src/game/flow/turn/GameplayLoopRuntime.lua`
- 修改：`src/game/flow/turn/GameplayLoop.lua`
- 修改：`src/app/init.lua`
- 修改：`.agents/tests/gameplay_loop_no_ui.lua`
- 修改：`.agents/tests/suites/gameplay.lua`
- 修改：`src/presentation/interaction/UIEventRouter.lua`
- 修改：`src/presentation/api/UIRuntimePort.lua`
- 删除：`src/presentation/interaction/UIIntentProviders.lua`
- 修改：`src/presentation/interaction/UIIntentBuilder.lua`
- 新增：`src/presentation/interaction/intent_builders/BasicIntents.lua`
- 新增：`src/presentation/interaction/intent_builders/PopupIntents.lua`
- 新增：`src/presentation/interaction/intent_builders/ItemSlotIntents.lua`
- 新增：`src/presentation/interaction/intent_builders/ChoiceIntents.lua`
- 新增：`src/presentation/interaction/intent_builders/MarketIntents.lua`

## 接口与依赖

保持现有接口不变：

- `intent_dispatcher.dispatch(game, payload, opts)`（游戏侧）
- `ui_intent_dispatcher.dispatch(state, game, intent, opts)`（表现层）

仅调整内部职责分配，不新增外部调用协议。

变更说明（2026-02-13 / Copilot）：新建本轮执行计划并记录首批已实施改动。
变更说明（2026-02-13 / Copilot）：补充回归执行结果与复盘结论，更新进度为全部完成。
变更说明（2026-02-13 / Copilot）：追加第二阶段（GameplayLoop 职责拆分）实施进展与验收项。
变更说明（2026-02-13 / Copilot）：追加第三阶段（runner 合并与遗留清理）实施进展与验收项。
变更说明（2026-02-13 / Copilot）：追加第四阶段（UIEventRouter 去全局态与遗留模块清理）实施进展与验收项。
变更说明（2026-02-13 / Copilot）：追加第五阶段（UIIntentBuilder 模块化与门面转发）实施进展与验收项。