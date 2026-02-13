# 执行计划：UI 交互职责解耦（InputLock / Router）

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件遵循 `.agents/PLANS.md` 维护。

## 目的 / 全局视角

本轮改造要完成上一轮评审提出的“职责边界收口”：输入锁策略不再直接依赖面板呈现器，事件路由层不再直接改 UI 状态。完成后，用户可继续使用现有按钮交互（行动日志、托管、输入锁期间弹窗确认等）且行为不变，但代码结构会更稳定：触控策略集中在策略模块，路由层专注“事件 -> intent”。可见结果是全量回归通过，并且新增/修改调试开关行为时只需改 intent/handler，不必改 router 内部状态逻辑。

## 进度

- [x] (2026-02-13 19:20Z) 清空并重建 `PLAN_CURRENT.md`，切换到本轮“职责解耦”主题。
- [x] (2026-02-13 19:22Z) 读取并确认 `UIIntentBuilder` / `UIIntentDispatcher` 当前调试开关处理路径。
- [x] (2026-02-13 19:24Z) 解耦 `UIInputLockPolicy` 对 `UIPanelPresenter` 与 `UIRoleContext` 的依赖，改为纯触控策略编排。
- [x] (2026-02-13 19:25Z) 调整 `UIEventRouter`：debug 点击仅产出 intent，不直接调用 `UIView.set_debug_visible`。
- [x] (2026-02-13 19:26Z) 在 `UIIntentDispatcher` 落地 debug 切换处理，保持按角色切换行为。
- [x] (2026-02-13 19:27Z) 收敛 `UINodes.required_click_nodes` 与 `debug.toggle_targets`，移除双源列表。
- [x] (2026-02-13 19:29Z) 补充测试：新增 `toggle_debug` dispatcher 角色上下文用例。
- [x] (2026-02-13 19:31Z) 首次回归失败后修复 fallback，再次运行通过：`All regression checks passed (132)`。
- [x] (2026-02-13 20:05Z) 删除调试屏“3秒10击”历史残留字段：`debug_toggle_first_click_timestamp` 与 `debug_toggle_click_count`。
- [x] (2026-02-13 20:07Z) 第二轮收口：新增 `DebugIntents`，`UIEventRouter` 不再本地拼装 debug route specs。
- [x] (2026-02-13 20:09Z) 运行全量回归通过：`All regression checks passed (132)`。

## 意外与发现

- 观察：`UIInputLockPolicy.apply` 目前仍调用 `panel_presenter` 与 `role_context`，属于策略层依赖呈现细节。
  证据：`src/presentation/interaction/UIInputLockPolicy.lua` 顶部 require 与 `runtime.for_each_role_or_global` 代码段。

- 观察：`UIEventRouter` 当前 debug 切换在路由层直接调用 `ui_view.set_debug_visible`，路由职责偏重。
  证据：`src/presentation/interaction/UIEventRouter.lua` 的 `_toggle_debug_visible_for_role`。

- 观察：把 debug 切换下沉到 dispatcher 后，`all_roles=nil` 场景会丢失 role context，导致按角色状态未写入。
  证据：首次回归报错 `debug toggle should invert role visibility | expected=false got=nil`。

- 观察：在 dispatcher 增加“伪 role 回退（仅实现 get_roleid）”后，按角色切换行为恢复。
  证据：二次回归输出 `All regression checks passed (132)`。

- 观察：仓库已不存在“3秒内点击10次才开启调试屏”的执行逻辑，仅剩 UI state 残留字段。
  证据：`UIView.build_ui_state` 字段定义 + 全仓无其他引用。

- 观察：将 debug route specs 下沉到独立 builder 后，router 仅负责汇总 builder 输出，职责更单一。
  证据：`UIEventRouter._build_default_route_specs` 改为 `_append(ui_intent_builder.build_debug_intents(state))`。

## 决策日志

- 决策：先做“行为不变重构”，不改 UI 可见行为与按钮语义。
  理由：该任务目标是结构收口，不是产品行为变更；可降低回归风险。
  日期/作者：2026-02-13 / Copilot

- 决策：输入锁阶段的“托管可点、调试可点、弹窗确认可点”保持不变，作为硬约束写入测试。
  理由：这三项是现有功能契约，之前已发生过回归。
  日期/作者：2026-02-13 / Copilot

- 决策：`toggle_debug` 在缺少 `all_roles` 时使用最小伪 role 回退，而不是降级为 global 切换。
  理由：需要维持既有“按 actor_role_id 写入 debug_visible_by_role”的测试契约与运行时语义。
  日期/作者：2026-02-13 / Copilot

- 决策：本轮“删除该功能”按 A 路径执行为“删除3秒10击残留，不删除当前 debug toggle 功能”。
  理由：当前门槛逻辑已退役，仅有残留字段；保留现有点击 toggle 行为可避免产品行为回归。
  日期/作者：2026-02-13 / Copilot

- 决策：第二轮收口采用新增 `DebugIntents` 文件，而不是继续塞进 `BasicIntents`。
  理由：避免基础按钮意图与调试入口耦合，后续维护更清晰。
  日期/作者：2026-02-13 / Copilot

## 结果与复盘

本轮“职责解耦”已完成并通过全量回归（132）。

完成项：

1. `UIInputLockPolicy` 移除对 `UIPanelPresenter`、`UIRoleContext` 的直接依赖，改为纯触控编排；
2. `UIEventRouter` 不再直接切换 debug 可见性，改为发出 `toggle_debug` intent；
3. `UIIntentDispatcher` 承接 debug 切换执行，并保持按角色上下文生效；
4. `UINodes.required_click_nodes` 复用 `debug.toggle_targets`，避免双源；
5. 新增 dispatcher 级测试覆盖 toggle_debug 角色上下文行为。

新增完成项：

6. 删除 `UIView` 中“3秒10击”未使用残留状态字段；
7. 新增 `intent_builders/DebugIntents.lua`，并由 `UIIntentBuilder` 暴露 `build_debug_intents`；
8. `UIEventRouter` 删除本地 debug spec 拼装，改为消费 builder 输出；
9. 全量回归保持通过（132）。

收益：路由层职责更单一，输入锁策略与呈现实现边界更清晰，后续扩展 debug 行为时改动点集中。

## 背景与导读

本轮只涉及 `src/presentation` 的交互链路与配置源：

- `src/presentation/interaction/UIInputLockPolicy.lua`：输入锁期间触控规则编排。
- `src/presentation/interaction/UITouchPolicy.lua`：触控策略细节实现。
- `src/presentation/interaction/UIEventRouter.lua`：UI 点击路由入口。
- `src/presentation/interaction/UIIntentBuilder.lua` 与 `UIIntentDispatcher.lua`：intent 构建与分发。
- `src/presentation/shared/UINodes.lua`：节点常量与 required click nodes 配置。

“路由纯 intent”是指：router 只负责收集事件并产出 intent，真正状态写入在 dispatcher/handler 执行。

## 工作计划

先定位 debug toggle 的 intent 处理位置，把 `UIEventRouter` 的直接 UI 调用下沉到 intent 执行端。随后将 `UIInputLockPolicy` 中与面板渲染相关的依赖移除，仅保留触控锁定/放行策略调用。最后补充测试并跑全量回归，确保行为不变。

## 具体步骤

在仓库根目录按顺序执行：

    lua .agents/tests/regression.lua

预期输出片段：

    All regression checks passed (N)

其中 `N` 应不低于当前基线 131。

## 验证与验收

验收标准：

1. `UIInputLockPolicy.lua` 不再 require `UIPanelPresenter` 与 `UIRoleContext`。
2. `UIEventRouter.lua` 不再直接调用 `UIView.set_debug_visible`。
3. debug toggle 点击后行为保持与当前一致（可切换显示状态，按角色上下文生效）。
4. `UINodes.required_click_nodes` 复用 `debug.toggle_targets`，避免双源。
5. 全量回归通过。

## 可重复性与恢复

本方案采用小步修改，每一步都可独立回滚。若失败，按模块回退：

1. 回退 router 的 debug intent 路由改动；
2. 回退 input lock 的依赖删除；
3. 回退 UINodes 清单收敛；
4. 重跑回归，定位最小失败集。

## 产物与备注

预计修改文件：

- `src/presentation/interaction/UIInputLockPolicy.lua`
- `src/presentation/interaction/UIEventRouter.lua`
- `src/presentation/interaction/UIIntentBuilder.lua`（如需）
- `src/presentation/interaction/UIIntentDispatcher.lua`（如需）
- `src/presentation/shared/UINodes.lua`
- `.agents/tests/suites/presentation_ui.lua`（如需）

## 接口与依赖

目标接口约束：

- 路由层只负责组装 intent，不执行 UI 状态写入。
- 输入锁策略层只负责调用 `UITouchPolicy` 与最小 UI 触控 API。
- `required_click_nodes` 与 `debug.toggle_targets` 共享同一配置源。

变更说明（2026-02-13 / Copilot）：重建执行计划，进入“职责解耦”实施阶段。
