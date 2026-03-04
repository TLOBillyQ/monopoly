# R19 始终显示屏与调试屏本地玩家作用域重构可执行计划


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件遵循 `.agents/harness/PLANS.md` 维护，实施者在修改代码前后都必须先回填本文件，再继续推进。

## 目的 / 全局视角


本轮工作的目标是修复并重构“始终显示屏”和“调试屏”的角色作用域，让它们在游戏运行期间始终可用，并且所有交互与显示目标始终严格绑定到客户端本地玩家（事件触发者），不再被“当前回合玩家”“全局 UI 写入”或历史缓存污染。

用户可见结果是：托管按钮与行动日志按钮在运行中任何阶段都能稳定点击；点击后只影响点击者本人，不会串到其他玩家；调试屏默认关闭，谁点谁开，互不干扰。验收时可通过回归测试与手动场景观察到该行为稳定成立。

## 进度


- [x] (2026-03-04 10:06 +08:00) 完成首轮只读排查，定位“始终显示屏/调试屏/actor 解析/Canvas 切换”主链路文件。
- [x] (2026-03-04 10:18 +08:00) 复核 `docs/eggy/ui_manager_lib.md` 并对照实现确认关键约束：`UIManager.client_role=nil` 会写全体玩家。
- [x] (2026-03-04 10:23 +08:00) 完成根因复现脚本：验证 `LocalActorResolver` 缓存回退可导致 actor_role_id 漂移。
- [x] (2026-03-04 10:25 +08:00) 生成并写入 R19 可执行计划，补齐活文档必需章节。
- [ ] 里程碑 1：收敛 actor 解析为“严格事件角色”，移除运行时缓存回退。
- [ ] 里程碑 2：重构始终显示屏交互可用性判定，确保全程可用且仅本地角色可操作。
- [ ] 里程碑 3：重构调试屏为按角色隔离状态，默认关闭，移除全局状态混用。
- [ ] 里程碑 4：收敛运行态 Canvas 切换到按角色路径，完成回归与文档回填。

## 意外与发现


- 观察：`ui_manager_lib.md` 明确规定 `UIManager.client_role=nil` 时对所有玩家生效，因此任何“无角色上下文的 UI 写入”都会天然有串扰风险。
  证据：`docs/eggy/ui_manager_lib.md:13` 与 `docs/eggy/ui_manager_lib.md:47-53`。

- 观察：`LocalActorResolver` 在无法从事件解析角色时会回退到 `state.ui.local_actor_role_id`，存在跨事件污染风险。
  证据：`src/presentation/canvas_runtime/LocalActorResolver.lua:29-33`，以及复现脚本输出 `intent_actor=2 normalized_actor=1`。

- 观察：调试开关当前是“全局字段 + 按角色字段”并行维护，`resolve_debug_enabled` 在无角色上下文时会回退全局规则，无法保证“永远本地玩家”。
  证据：`src/presentation/interaction/UIEventState.lua:17-31` 与 `src/presentation/api/ui_view_service/state.lua:63-66`。

- 观察：运行态仍存在 `canvas.switch(ui, ...)` 全局路径，可能覆盖按角色显示策略。
  证据：`src/presentation/ui/MarketModalRenderer.lua:8`、`src/presentation/ui/UIModalPresenter.lua:76,107`。

## 决策日志


- 决策：采用“分层迁移”而不是一次性全量替换。
  理由：该链路跨 UI 事件、状态模型、Canvas 切换与 gameplay tick，同步重写风险高；分层迁移更容易保回归稳定。
  日期/作者：2026-03-04 / Codex

- 决策：调试屏默认关闭，且仅按角色存储可见状态。
  理由：满足“谁点谁开”，避免全局默认态导致的误显示与串扰。
  日期/作者：2026-03-04 / Codex

- 决策：缺失 `role` 或 `role->player` 映射失败时严格拒绝交互，不做缓存回退。
  理由：用户目标是“目标总是客户端本地玩家”，可错过一次点击，但不能误操作他人。
  日期/作者：2026-03-04 / Codex

- 决策：除启动阶段外，运行态 UI 行为禁止使用“无角色上下文的全局可见性写入”控制调试屏。
  理由：与 UIManager 作用域模型一致，减少隐式全局副作用。
  日期/作者：2026-03-04 / Codex

## 结果与复盘


本计划刚完成设计与落盘，尚未进入代码实施阶段，因此当前没有“功能已交付”的结论。下一次更新本节时，需要对照“目的 / 全局视角”逐条复盘：始终显示屏是否全程可用、调试屏是否按玩家隔离、是否仍存在全局路径串扰。

## 背景与导读


本任务涉及的核心概念是“角色作用域”。在本仓库里，角色作用域由 `UIManager.client_role` 决定：设置某个角色后，UI 节点属性写入只影响该角色；设为 `nil` 则影响所有角色。这个机制由 `vendor/third_party/UIManager` 实现，项目侧通过 `src/presentation/api/UIRuntimePort.lua` 包装调用。

“始终显示屏”节点定义在 `src/presentation/canvas/always_show/nodes.lua`，包含托管按钮与行动日志按钮；“调试屏”节点定义在 `src/presentation/canvas/debug/nodes.lua`。两者的点击事件由 `src/presentation/canvas_runtime/CanvasEventRouter.lua` 统一注册，再通过 `src/presentation/interaction/UIIntentDispatcher.lua` 分发到视图命令或游戏动作。

当前风险分三层。第一层是 actor 解析层：`LocalActorResolver` 允许缓存回退。第二层是状态层：调试可见状态同时存在全局与按角色字段。第三层是渲染/切屏层：运行态仍混入全局 `canvas.switch`。这三层叠加后，容易出现“看起来本地操作，实际影响全体或错误玩家”的现象。

## 里程碑


里程碑 1 的范围是 actor 解析收敛。完成标准是：`toggle_action_log` 与 `auto` 相关 intent 在进入 dispatcher 前必须拿到事件角色；拿不到就拒绝，不再读取历史缓存，不再用 current player 兜底。这个里程碑完成后，交互目标不会再跨事件漂移。

里程碑 2 的范围是始终显示屏可用性重构。完成标准是：托管按钮与行动日志按钮在输入锁、动画等待与弹窗期间仍可点击；但点击权限仍受“是否本地玩家角色”约束。这个里程碑完成后，用户感知是“按钮一直能用，但只对自己生效”。

里程碑 3 的范围是调试状态模型重构。完成标准是：调试开关默认关闭；只存在按角色状态，不再依赖全局 `debug_visible` / `debug_log_enabled_override`；tick 同步按角色执行。这个里程碑完成后，不同玩家调试屏互不影响。

里程碑 4 的范围是运行态 Canvas 路径收敛与验收。完成标准是：运行态 modal/popup/market 切屏统一走 `switch_for_role`；全量回归通过；计划文档四个活文档章节更新齐全并附验证证据。

## 工作计划


第一步会修改 `src/presentation/canvas_runtime/LocalActorResolver.lua` 与 `src/presentation/canvas_runtime/CanvasEventRouter.lua`。`resolve_from_event` 仅接受 `data.role` 或当前监听回调上下文中的 `UIManager.client_role`，删除 `state.ui.local_actor_role_id` 回退。`CanvasEventRouter` 在分发 intent 前执行严格校验，校验失败时通过 `HostRuntimePort.show_tips` 提示并中止分发。

第二步会修改 `src/presentation/interaction/ui_intent_dispatcher/TurnActionPort.lua`。`normalize_auto_intent` 改为“只补齐，不覆盖”：若已有 `intent.actor_role_id`，原样保留；若缺失则尝试严格解析；仍缺失则返回 `nil` 并由上层终止动作。同步更新 `tests/suites/usecase_boundary_contract.lua` 合约断言。

第三步会改造始终显示屏触控链路，主要在 `src/presentation/ui/UIPanelPresenter.lua` 与 `src/presentation/interaction/UIInputLockPolicy.lua`。托管按钮的触控可用性不再取决于单次快照式 `runtime.get_client_role()`，而是显式依据当前遍历 role 的上下文；输入锁开关切换时都要重刷 `auto` 与 `action_log` 按钮触控，避免状态残留。

第四步会重构调试状态模型，修改 `src/presentation/api/ui_view_service/state.lua`、`src/presentation/interaction/UIEventState.lua`、`src/presentation/api/ui_view_service/debug.lua`、`src/presentation/api/presentation_ports/DebugPorts.lua`、`src/presentation/interaction/ui_intent_dispatcher/ViewCommandDispatcher.lua`。目标是保留唯一事实源 `ui.debug_visible_by_role`（命名可在实现时统一），移除全局 debug 可见字段在运行态决策中的参与。

第五步会收敛运行态切屏路径，修改 `src/presentation/ui/MarketModalRenderer.lua` 与 `src/presentation/ui/UIModalPresenter.lua`，把 `canvas.switch(ui, ...)` 运行态调用改为按角色循环 `canvas.switch_for_role(...)`。启动阶段（`UIBootstrap`）保留全局 show 行为。

第六步会补全与调整测试，重点在 `tests/suites/presentation_ui.lua`、`tests/suites/presentation_ui_event_bindings.lua`、`tests/suites/usecase_boundary_contract.lua`。新增“缺失 role 严格拒绝”“debug 默认关闭”“A 玩家开 debug 不影响 B 玩家”“auto intent 不覆盖 actor”等断言，删除与新策略冲突的旧断言。

## 具体步骤


所有命令在仓库根目录 `/Users/gangan/Dev/repo/monopoly` 执行。

先记录实施前快照并确认计划文件已更新。

    git status --short
    sed -n '1,220p' .agents/plan.md

实施里程碑 1 与 2 后，先跑定向测试，避免把问题扩散到全量回归阶段。

    lua tests/regression.lua

如果全量回归耗时较长，先执行最小相关套件（实现阶段按 TestHarness 入口临时脚本组织），再回到全量回归。

    lua -e "package.path=package.path..';./tests/?.lua;./tests/suites/?.lua'; local h=require('TestHarness'); h.run_all({require('presentation_ui_event_bindings'), require('usecase_boundary_contract')})"

实施里程碑 3 与 4 后执行全量回归与静态门禁。

    lua tests/regression.lua
    lua tests/internal/forbidden_globals.lua

最后整理差异并回填计划文档证据。

    git diff -- .agents/plan.md src tests
    git status --short

## 验证与验收


验收以“行为正确”优先于“代码结构变化”。

首先验证始终显示屏可用性：在输入锁、移动动画等待、动作动画等待、弹窗期间，托管按钮与行动日志按钮都可以点击，且点击方是本地玩家时行为生效，非本地玩家不生效。

其次验证目标隔离：两个玩家同时在线时，A 点击行动日志只改变 A 的调试屏，B 的调试屏与日志开关状态不变化；B 点击同理。这个验收必须包含“同一回合内连续切换”“跨回合切换”两个场景。

再次验证严格拒绝策略：人为构造缺失 `role` 的 click data，事件必须被拒绝并出现提示，不得触发任何 gameplay action 或调试状态变化。

最后跑 `lua tests/regression.lua`，预期输出 `All regression checks passed (...)`；并运行 `lua tests/internal/forbidden_globals.lua`，预期 `forbidden_globals ok`。

## 可重复性与恢复


本计划按里程碑增量推进，每个里程碑可独立提交。若中途失败，优先回退当前里程碑涉及文件，不回退已通过验收的前置里程碑。恢复方式使用普通反向提交或手工逆向 patch，不使用破坏性历史命令。

如果回归显示“调试状态读取路径”与旧测试夹层冲突，先保留一版兼容读路径（只读镜像，不参与写入决策），待所有调用点迁移完成后再移除兼容层。这样可以避免一次性切断导致的连锁失败。

## 产物与备注


实施前关键证据：

    docs/eggy/ui_manager_lib.md:13
    docs/eggy/ui_manager_lib.md:47-53
    src/presentation/canvas_runtime/LocalActorResolver.lua:29-33
    src/presentation/interaction/UIEventState.lua:17-31
    src/presentation/ui/MarketModalRenderer.lua:8
    src/presentation/ui/UIModalPresenter.lua:76,107

实施后应新增或更新的关键测试行为：

    1) 缺失 role 的 toggle_action_log 不再回退缓存角色，直接拒绝。
    2) auto intent 保留已有 actor_role_id，不被 resolver 覆盖。
    3) debug 默认关闭；按角色切换互不影响。
    4) 输入锁期间始终显示屏的托管/日志按钮仍可点击。

## 接口与依赖


本轮不引入第三方依赖。依赖仅包括现有 `UIManager`、`UIRuntimePort`、`UIViewService`、`DebugPorts` 与测试框架。

`src/presentation/interaction/UIEventState.lua` 的 `resolve_debug_enabled` 需要升级为显式角色参数接口，例如 `resolve_debug_enabled(state, role_id)`。实现完成后，不允许无角色上下文返回“开启”状态。

`src/presentation/api/ui_view_service/debug.lua` 需要新增按角色写接口（示例命名：`set_debug_visible_for_role(state, role, visible)`），并把旧的全局可见性写路径降级为仅启动兼容，不参与运行态控制。

`src/presentation/canvas_runtime/LocalActorResolver.lua` 需要改为无缓存副作用设计，不再写入或读取 `state.ui.local_actor_role_id`。

`src/presentation/interaction/ui_intent_dispatcher/TurnActionPort.lua` 的 `normalize_auto_intent(state, intent)` 需保持原签名，但语义改为“已有 actor 不覆盖，缺失 actor 严格解析，失败返回 nil”。

## 文档更新记录


2026-03-04（R19 创建）：基于当前代码与 `docs/eggy/ui_manager_lib.md` 重新定位“始终显示屏/调试屏”本地玩家作用域问题，确认根因是 actor 缓存回退、debug 全局与按角色状态混用、运行态全局切屏路径并存。新建本计划用于指导分层迁移与回归验收。

2026-03-04（R19 覆盖写入）：按用户要求将本轮方案正式写入 `.agents/plan.md`，并按 `.agents/harness/PLANS.md` 补齐活文档必需章节、执行步骤、验收标准与更新记录。改动原因是把会话内达成的设计决策转化为可直接实施的仓库内执行文档。
