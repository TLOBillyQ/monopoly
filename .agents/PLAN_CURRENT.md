# `src/` 热点深审落地：M0-M7 全部完成

本可执行计划是活文档。实施过程中必须持续更新“进度”“意外与发现”“决策日志”“结果与复盘”。

本文件遵循 `/.agents/PLANS.md` 维护。

## 目的 / 全局视角

本轮目标是把热点深审提出的 P1/P2/P3 结构风险按里程碑一次性推进完，且不牺牲可运行性。完成后用户可见结果是：

- 无 UI 场景下核心回合逻辑可稳定运行；
- Runtime 上下文绑定、UI 模型构建、超时策略、模态展示、运行时端口、付费货币桥接、市场渲染、UI 路由都完成拆分或收敛；
- 全量回归仍全绿。

验证标准以回归为准：`lua .agents/tests/regression.lua` 输出 `All regression checks passed (93)`。

## 进度

- [x] 里程碑 M0（2026-02-10 17:12）：完成审查结果入档与执行面收敛。
- [x] 里程碑 M1（2026-02-10 17:18-17:21）：完成 P1-01（`GameState` 地块归属通知解耦），回归 84 通过。
- [x] 里程碑 M2（2026-02-10 18:46-19:03）：完成 P1-02（`GameplayLoop` 端口化拆分），回归 87 通过。
- [x] 里程碑 M3（2026-02-10 19:04-19:17）：完成 P1-03（`RuntimeContext` 环境绑定与编辑器导出拆分）。
- [x] 里程碑 M4（2026-02-10 19:17-19:30）：完成高价值 P2（`UIModel` 职责拆分 + `TickTimeout` 超时策略显式化）。
- [x] 里程碑 M5（2026-02-10 19:30-19:52）：完成其余 P2/P3（`UIModalPresenter`、`UIRuntimePort`、`PaidCurrencyBridge`、`MarketView`、`UIEventRouter`）。
- [x] 里程碑 M6（2026-02-10 19:52-19:58）：完成全链路验收与复盘，回归 91 通过。
- [x] 里程碑 M7（2026-02-10 20:35-20:42）：完成单局尾部死代码清理（移除 `on_game_changed` 无消费扩展点），回归 93 通过。

## 意外与发现

- 观察：`TurnFlow` 才负责清空 `move_anim/action_anim`，`GameplayLoop.tick` 本身只会派发 `*_anim_done`，因此测试应断言“已派发 done action”，而不是“动画字段已清空”。
  证据：首轮 headless 用例失败后改为断言 `dispatch_action` 收到 `move_anim_done/action_anim_done`。

- 观察：`RuntimeContext` 拆分后仍需保留 `install_globals` 兼容入口，否则现有测试与调用点会大面积改动。
  证据：`.agents/tests/suites/gameplay.lua` 仍直接调用 `runtime_context.install_globals(ctx)`。

- 观察：`UIRuntimePort.with_client_role` 原实现在嵌套场景会把外层角色覆盖成 `nil`，这是潜在上下文污染点。
  证据：新增用例验证嵌套切换后必须恢复外层 role，再恢复原始 role。

- 观察：`PaidCurrencyBridge` 的模块级 `runtime_state.game` 会让“多局并存”场景发生串局风险，需要改成按 game 上下文隔离。
  证据：新增 `paid_currency` 用例验证 `setup_for_game(g1)` 与 `setup_for_game(g2)` 后消费只影响对应 game。

- 观察：在“永远单局”前提下，`restart` 链路属于无效分支，保留会增加维护噪音并放大分支复杂度。
  证据：`TurnDispatch` 与 `GameplayLoop` 中 `restart` 路径无测试覆盖，且运行入口只初始化单局。

- 观察：`RuntimeEnvBindings` 原先只断言 `LuaAPI` 存在，不断言关键函数签名，错误暴露偏晚。
  证据：新增 `install_environment` fail-fast 用例后，能直接命中缺失 `global_send_custom_event`。

## 决策日志

- 决策：`RuntimeContext` 按“三段式”拆分：`install_environment`、`install_runtime_helpers`、`install_editor_exports`，并保留 `install_globals` 聚合入口。
  理由：既满足职责拆分，又避免一次性改动所有调用方。
  日期/作者：2026-02-10 / Codex

- 决策：`UIModel` 拆成投影层与面板层，主模块只做编排。
  理由：把“数据投影”和“文案展示拼装”分开，降低联动改动成本。
  日期/作者：2026-02-10 / Codex

- 决策：`TickTimeout` 通过 `default_policy()` 显式暴露超时策略，并允许外部覆盖 timeout/min_visible。
  理由：消除“默认行为隐式写死”的维护风险，同时保持旧行为兼容。
  日期/作者：2026-02-10 / Codex

- 决策：`UIModalPresenter` 引入 `UICanvasCoordinator` 统一画布切换与弹窗返回目标解析。
  理由：去除 presenter 内多处重复分支，降低状态错配概率。
  日期/作者：2026-02-10 / Codex

- 决策：`PaidCurrencyBridge` 改为按 `game` 保存上下文，`active_context` 仅作为兼容兜底。
  理由：避免跨局状态污染，同时保持 `open_purchase_panel` 等旧签名可用。
  日期/作者：2026-02-10 / Codex

- 决策：`UIEventRouter` 改用运行态节点列表（`state.ui.item_slots`、`state.ui.choice.option_buttons`）构建路由，不再硬编码固定数量。
  理由：提升 UI 变体扩展性，减少核心路由改动。
  日期/作者：2026-02-10 / Codex

- 决策：按“单局运行模型”删除重开链路（`restart` action、`on_restart` wiring、`GameplayLoop.restart_game`）。
  理由：减少无效分支，避免未来改动误触不可达路径。
  日期/作者：2026-02-10 / Codex

- 决策：`PaidCurrencyBridge` 完全改为显式 `game` 上下文，不再依赖模块级 active context。
  理由：让上下文隔离从“部分成立”变成“语义闭环”。
  日期/作者：2026-02-10 / Codex

- 决策：`TickTimeout.default_policy()` 返回副本，防止外部修改污染全局默认策略。
  理由：降低隐式全局状态风险，保持默认策略可预测。
  日期/作者：2026-02-10 / Codex

- 决策：删除 `UIEventRouter.bind` 的 `opts/on_game_changed` 死扩展点，并收敛为固定关闭 choice 行为。
  理由：仓库内无调用方消费 `on_game_changed`，且单局模型不再需要运行时替换 game 的回调链路。
  日期/作者：2026-02-10 / Codex

## 结果与复盘

M0-M7 已全部完成，核心成果如下：

1. **P1 问题清零**  
   - `GameState` 与 UI 通知解耦；
   - `GameplayLoop` 副作用端口化；
   - `RuntimeContext` 运行环境绑定与编辑器导出职责拆分。

2. **高价值 P2 完成**  
   - `UIModel` 拆分为 `UIModelProjection` 与 `UIModelPanelBuilder`；
   - `TickTimeout` 默认策略显式化并支持外部覆盖。

3. **其余 P2/P3 完成**  
   - `UIModalPresenter` 画布协作拆分；
   - `UIRuntimePort` 嵌套角色恢复修正；
   - `PaidCurrencyBridge` 按 game 上下文隔离；
   - `MarketView` 槽位渲染收敛；
   - `UIEventRouter` 取消固定槽位/选项硬编码。

4. **回归结果**  
   - 全量回归通过，基线提升为 `All regression checks passed (93)`。

5. **死代码清理补充（M7）**  
   - 删除 `src/app/init.lua` 中未被消费的 `on_game_changed` 传参；
   - 收敛 `UIEventRouter.bind` 签名，移除无用 `opts` 透传，减少无效可选分支。

剩余缺口：本计划范围内无未完成里程碑。后续仅建议做增量清理（例如进一步细分端口能力域），不影响当前交付。

## 背景与导读

本计划对应一次“热点文件深审”的落地执行。重点不是增加玩法，而是把高耦合结构风险降到可维护状态。改动集中在：

- `src/core/`：运行环境绑定与编辑器导出；
- `src/game/turn/`：回合编排的副作用端口化与超时策略；
- `src/ui/`：模型构建、模态展示、运行时角色上下文、市场渲染、事件路由；
- `src/game/commerce/`：付费货币桥接的生命周期管理。

新增模块均为薄层拆分，原则是“保持旧行为 + 明确边界”。

## 工作计划

执行顺序为：先完成 P1（保稳定），再做高收益 P2（降耦合），最后清理剩余 P2/P3（提升扩展性），每步都以回归为闸门。所有改造都采用“先引入兼容层，再迁移调用”的方式，避免大爆炸重写。

## 具体步骤

工作目录：`C:\Users\Lzx_8\Desktop\dev\monopoly`

1. 完成 M3：拆分 `RuntimeContext` 责任并保持兼容入口。
2. 完成 M4：拆分 `UIModel`，显式化 `TickTimeout` 默认策略。
3. 完成 M5：治理 `UIModalPresenter`、`UIRuntimePort`、`PaidCurrencyBridge`、`MarketView`、`UIEventRouter`。
4. 补充回归用例（`gameplay`、`ui`、`paid_currency`）。
5. 运行全量回归并记录结果。
6. 清理单局下不可达/无消费扩展点，并再次回归。

## 验证与验收

验收结论：通过。

- 回归命令：`lua .agents/tests/regression.lua`
- 回归结果：`All regression checks passed (93)`
- 关键新增验证：
  - `RuntimeContext` 分段安装流程可用；
  - `TickTimeout` 显式超时策略可触发；
  - `UIRuntimePort` 嵌套 role 恢复正确；
  - `PaidCurrencyBridge` 跨 game 上下文隔离正确。

## 可重复性与恢复

本轮改造可重复执行；若需回退，按文件级回滚并清理新增文件：

- 回滚：`git checkout -- <file>`
- 清理新增：`git clean -f <new_file>`

回退后必须重新执行回归，确保基线恢复。

## 产物与备注

主要新增文件：

- `src/core/RuntimeEnvBindings.lua`
- `src/core/RuntimeEditorExports.lua`
- `src/ui/UIModelProjection.lua`
- `src/ui/UIModelPanelBuilder.lua`
- `src/ui/UICanvasCoordinator.lua`

主要改造文件：

- `src/core/RuntimeContext.lua`
- `src/app/init.lua`
- `src/ui/UIModel.lua`
- `src/game/turn/TickTimeout.lua`
- `src/ui/UIModalPresenter.lua`
- `src/ui/UIRuntimePort.lua`
- `src/game/commerce/PaidCurrencyBridge.lua`
- `src/ui/MarketView.lua`
- `src/ui/UIEventRouter.lua`
- `src/game/turn/TurnDispatch.lua`
- `src/game/market/Market.lua`
- `src/core/RuntimeEnvBindings.lua`

测试变更：

- `.agents/tests/suites/gameplay.lua`
- `.agents/tests/suites/ui.lua`
- `.agents/tests/suites/paid_currency.lua`

## 接口与依赖

本轮新增/调整接口（已落地）：

- `runtime_context.install_environment(ctx)`
- `runtime_context.install_runtime_helpers(ctx)`
- `runtime_context.install_editor_exports(ctx)`
- `tick_timeout.default_policy()`
- `state.gameplay_loop_ports`（承接 M2，保持兼容）

保持兼容：

- `runtime_context.install_globals(ctx)` 仍可用；
- 各模块对外调用语义保持不变，重点是内部职责边界更清晰。

计划更新说明（2026-02-10）：完成 M3-M6 全部实现与回归，重写计划文件以反映最终真实状态，并将后续入口从“继续实施”切换为“完成交付”。
计划更新说明（2026-02-10）：按单局约束执行审查后收口：删除重开链路、桥接强制显式 game 上下文、环境绑定 fail-fast、默认超时策略防篡改；回归更新为 93 通过。
计划更新说明（2026-02-10）：继续执行死代码清理：移除 `on_game_changed` 与 `UIEventRouter.bind` 无消费参数分支，降低接口噪音并保持回归 93 通过。
