# 基础屏交互异常修复计划（头像/日志按钮/托管/移动输入锁）

本可执行计划是活文档。实施过程中必须持续维护“进度”“意外与发现”“决策日志”“结果与复盘”四个章节。本文件遵循 `.github/PLANS.md`。

## 目的 / 全局视角

本次修复目标是恢复基础屏四项核心交互稳定性：头像显示不变形、行动日志按钮可稳定开关调试屏、托管按钮可随时开关、其他玩家移动时主控玩家不能输入移动。完成后可通过回归测试和实机交互复验直接观察到行为恢复。

## 进度

- [x] (2026-02-21 16:09Z) 完成故障链路排查，确认四项问题的入口与受影响模块。
- [x] (2026-02-21 16:09Z) 清空并重建 `PLAN_CURRENT.md` 为本任务计划。
- [x] (2026-02-21 16:12Z) 实施头像渲染修复（固定控件尺寸贴图路径）。
- [x] (2026-02-21 16:12Z) 实施调试屏开关修复（按角色状态同步，避免被全局默认覆盖）。
- [x] (2026-02-21 16:12Z) 实施托管按钮兜底修复（缺失事件角色时可回退到当前客户端角色）。
- [x] (2026-02-21 16:12Z) 实施移动期输入锁修复（仅移动者临时放行，其他角色保持禁止控制）。
- [x] (2026-02-21 16:13Z) 补充回归测试（新增 5 条）并执行 `lua .github/tests/regression.lua`。
- [x] (2026-02-21 16:13Z) 更新结果与复盘，补齐最终验证证据。
- [x] (2026-02-22 02:36Z) 头像二次修复：新增 `reset_then_keep_size` 贴图路径，修复基础屏头像持续拉伸。
- [x] (2026-02-22 02:36Z) 头像二次修复：补齐头像源失败告警与 `Empty` 缺失降级隐藏逻辑，避免串头像残留。
- [x] (2026-02-22 02:36Z) 回归验证通过：`lua .github/tests/regression.lua` -> `All regression checks passed (156)`。

## 意外与发现

- 观察：行动日志按钮点击事件已正确绑定并会派发 `toggle_action_log`，失效根因在后续 `DebugPorts.sync_debug_log` 以无角色上下文读取默认配置，覆盖了角色开关状态。
  证据：`src/presentation/interaction/UIIntentDispatcher.lua` + `src/presentation/api/ports/DebugPorts.lua`。

- 观察：头像渲染当前使用 `set_texture_native_size` 优先路径，和道具槽位的 keep-size 路径不一致，容易引起控件尺寸被贴图原尺寸影响。
  证据：`src/presentation/ui/UIPanelPresenter.lua` + `src/presentation/api/UIRuntimePort.lua`。

- 观察：`UIEventRouter` 在点击回调未携带 `data.role` 且 `UIManager.client_role=nil` 时，会丢失 `actor_role_id`，导致托管开关动作被 `TurnDispatch` 拒绝。
  证据：`src/presentation/interaction/UIEventRouter.lua` + `src/game/flow/turn/TurnDispatch.lua`。

- 观察：即使改成 keep-size，若历史上该 `EImage` 被 auto-resize 过，节点尺寸可能已污染；只换贴图不 reset 会延续拉伸结果。
  证据：`vendor/third_party/UIManager/EImage.lua`（`set_texture_native_size`/`reset_size` 语义）+ 实机复现。

- 观察：当 `refs[\"Empty\"]` 缺失且头像 key 无效时，旧逻辑会跳过写入，导致头像节点残留上一次贴图，看起来像“串头像”。
  证据：`src/presentation/ui/UIPanelPresenter.lua` 旧 `_set_player_avatar` 早退分支。

## 决策日志

- 决策：调试屏开关继续保持“按角色隔离”语义，不改为全局联动。
  理由：现有状态结构已按角色存储，且多角色并行 UI 环境下更安全。
  日期/作者：2026-02-21 / Codex。

- 决策：移动锁采用“仅放行当前移动角色，其余角色保持禁止控制 Buff”。
  理由：满足主控防误操作，同时不阻断移动中角色自身动画驱动。
  日期/作者：2026-02-21 / Codex。

- 决策：托管按钮在缺失 `data.role` 时，先回退 `UIManager.client_role`，并缓存上次有效角色作最后兜底。
  理由：兼容 UI 事件上下文不稳定场景，避免“按钮按了无响应”。
  日期/作者：2026-02-21 / Codex。

## 结果与复盘

本轮四项问题已全部实现并通过回归。实现方式保持最小侵入：头像仅切换贴图路径；调试日志同步改成按角色维度；托管按钮补上 actor 兜底；移动动画锁从全局 suppress 切换成“按角色豁免”。

自动化验证结果：

- `lua .github/tests/regression.lua` 通过，`All regression checks passed (154)`。
- 新增 5 条 UI 回归用例，覆盖头像 keep-size、调试角色状态同步、托管 actor 兜底、动画锁豁免、角色控制锁豁免。

本次经验：表现层“按角色状态”逻辑不能在无角色上下文下做全局覆盖；动画锁策略应优先建模为“角色集合”，避免布尔开关导致全局误放行。

头像二次修复后，关键经验是：头像节点更新需要“先 reset 再 keep-size”来消除历史尺寸污染；同时当空头像资源缺失时必须显式隐藏节点，不能静默跳过写入，否则会保留旧贴图产生错头像错觉。

## 背景与导读

本任务集中在表现层与回合同步层。

- 头像渲染：`src/presentation/ui/UIPanelPresenter.lua`，通过 `UIRuntimePort` 给玩家头像节点设置贴图。
- 行动日志按钮与调试屏：`src/presentation/interaction/UIIntentDispatcher.lua`、`src/presentation/interaction/UIEventState.lua`、`src/presentation/api/ports/DebugPorts.lua`。
- 托管按钮动作分发：`src/presentation/interaction/UIEventRouter.lua` -> `src/game/flow/turn/TurnDispatch.lua`。
- 移动期输入锁与角色控制锁：`src/presentation/api/ports/AnimPorts.lua`、`src/presentation/interaction/UIRoleControlLockPolicy.lua`、`src/game/flow/turn/GameplayLoopRuntime.lua`。
- 测试入口：`.github/tests/regression.lua`，UI 相关主套件在 `.github/tests/suites/presentation_ui.lua`。

## 工作计划

先改最小行为面：头像贴图路径与托管角色兜底。随后处理调试状态同步策略，确保点击后不会被 tick 覆盖。最后重构移动锁为角色豁免模型，避免全局解锁导致主控在他人移动中可输入。所有改动后补测试并跑全量回归。

## 具体步骤

1. 修改 `UIPanelPresenter` 的头像贴图调用，从 auto-size 路径改为 keep-size。
2. 在 `UIEventState` 增加按角色解析函数，并在 `DebugPorts.sync_debug_log` 按角色同步可见性与日志文本。
3. 在 `UIEventRouter` 增强 `actor_role_id` 解析兜底，记录 `last_actor_role_id`。
4. 在 `AnimPorts` 和 `UIRoleControlLockPolicy` 引入按角色豁免锁策略，并在 `GameplayLoopRuntime` 去除旧的全局 suppress 逻辑依赖。
5. 在 `presentation_ui` 套件新增/调整对应测试。
6. 运行：

    cd /Users/billyq/Dev/Github/Lua/monopoly
    lua .github/tests/regression.lua

## 验证与验收

- 回归要求：`lua .github/tests/regression.lua` 全绿。
- 行为验收：
  - 头像使用固定控件尺寸显示。
  - 行动日志按钮每次点击都能稳定切换调试屏显示状态。
  - 托管按钮可在输入锁与动画阶段正常开关。
  - 他人移动期间主控无法输入移动。

## 可重复性与恢复

本计划修改均为局部逻辑替换与测试补充，不涉及数据迁移。若某一步失败，可按文件级回退该步骤改动并重跑回归。

## 产物与备注

变更文件：

- `.github/PLAN_CURRENT.md`
- `src/presentation/ui/UIPanelPresenter.lua`
- `src/presentation/interaction/UIEventState.lua`
- `src/presentation/api/ports/DebugPorts.lua`
- `src/presentation/interaction/UIEventRouter.lua`
- `src/presentation/interaction/UIRoleControlLockPolicy.lua`
- `src/presentation/api/ports/AnimPorts.lua`
- `src/game/flow/turn/GameplayLoopRuntime.lua`
- `src/presentation/api/ui_view_service/state.lua`
- `src/presentation/api/UIRuntimePort.lua`
- `src/presentation/ui/UIPanel.lua`
- `.github/tests/suites/presentation_ui.lua`
- `.github/tests/suites/presentation_ui_registry.lua`
- `.github/tests/suites/presentation_ui_action_status.lua`

关键输出摘要：

    ............................................................................................................................................................
    All regression checks passed (156)
    dep_rules ok
    tick ok

## 接口与依赖

不新增外部依赖，仅调整现有模块内接口与调用关系；对外玩法协议不变。
