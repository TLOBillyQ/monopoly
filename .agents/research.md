# Role 用例全量研究与统一方案（基于 `docs/eggy/ui_manager_lib.md`）

本文件是研究结论，不是执行计划；不涉及代码改动。

## 1. 研究范围

- 核心输入文档：`docs/eggy/ui_manager_lib.md`
- 补充依据：
  - `docs/eggy/api/07_unit_entities.md`（Role API 列表）
  - `docs/eggy/api/09_events.md`（事件回调含 `data.role` / `data.role_id`）
- 代码范围：`src/` 与相关 `tests/` 中所有 role 相关链路

## 2. 基础事实（来自 UIManager 文档）

`ui_manager_lib.md` 明确了三条底层语义：

1. `UIManager.client_role` 是 **UI 属性写入作用域**。
- 为 `nil`：全局广播（所有玩家）。
- 为某个 role：仅该玩家客户端可见。

2. `node:listen("CLICK", cb)` 的回调 `data` 中包含 `data.role`（触发者）。

3. `role:send_ui_custom_event(event_name, data)` 是按玩家客户端定向发送 UI 事件的基础能力。

这三条是项目里所有 role 相关 UI 行为的“物理层约束”。

## 3. 现有用例盘点（按职责分层）

### 3.1 运行时上下文与角色来源

代表文件：
- `src/core/RuntimeContext.lua`
- `src/core/RuntimePorts.lua`
- `src/core/runtime_ports/DefaultPorts.lua`
- `src/presentation/api/host_runtime/RoleResolver.lua`
- `src/app/bootstrap/GameStartup.lua`
- `src/game/core/runtime/GameFactory.lua`

现状：
- 角色主来源是 `runtime_context.roles`；空时回退 `GameAPI.get_all_valid_roles()`。
- `runtime_ports.resolve_role(player_id)` 优先在 roles 列表按 `get_roleid()` 匹配，失败再 `GameAPI.get_role(player_id)`。
- 开局优先“角色驱动”建局（`role_roster`），玩家 `id` 直接取 `role_id`；无角色时回退调试玩家（1..N）。

结论：
- 项目当前主路径将 `player.id` 与 `role_id` 绑定在一起（角色驱动模式）。
- 仍保留了非角色驱动回退路径，所以“语义上”等价但“来源上”不完全同构。

### 3.2 UI 渲染隔离（谁看到什么）

代表文件：
- `src/presentation/api/UIRuntimePort.lua`
- `src/presentation/api/ui_view_service/core.lua`
- `src/presentation/ui/UIPanelPresenter.lua`
- `src/presentation/ui/UITurnEffects.lua`
- `src/presentation/ui/PopupRenderer.lua`
- `src/presentation/ui/MarketModalRenderer.lua`
- `src/presentation/ui/choice_screen_service/common.lua`

现状：
- `for_each_role_or_global(fn)` 是多角色 UI 渲染主循环。
- 多数模块遵循“遍历 role -> 设置 `UIManager.client_role` -> 写 UI -> 复位 nil”。
- `UIRoleContext.resolve()` 根据 `role_id` 是否可映射到 `ui_model.item_slots_by_player*`，决定该 role 是否可操作、显示哪个玩家视角。
- 未映射 role 会进入“观战回退”（`can_operate=false`，`display_player_id=current_player_id`）。

结论：
- UI 可见性/可操作性已形成“按 role 裁剪”的完整系统。
- `UIManager.client_role` 的生命周期正确性（是否复位）是高风险点。

### 3.3 UI 输入与 intent actor（谁触发了动作）

代表文件：
- `src/presentation/interaction/UIEventBindings.lua`
- `src/presentation/canvas_runtime/CanvasEventRouter.lua`
- `src/presentation/canvas_runtime/LocalActorResolver.lua`
- `src/presentation/interaction/UIIntentDispatcher.lua`
- `src/presentation/interaction/ui_intent_dispatcher/GameActionDispatcher.lua`
- `src/presentation/interaction/ui_intent_dispatcher/TurnActionPort.lua`

现状：
- UI click 来自 `node:listen(UIManager.EVENT.CLICK, function(data) ... end)`。
- actor 解析链路：
  - `data.role` -> `UIManager.client_role` -> `ui_model.current_player_id`（当前实现）
- `CanvasEventRouter` 对需要身份的 intent 注入 `actor_role_id`（`next/auto/item_slot_*`、`choice_*`、`market_confirm`、`toggle_action_log`）。
- 解析失败会提示并拒绝 intent。

结论：
- 输入身份采集已经与 UIManager 文档能力（`data.role`）对齐。
- 该层是“身份丢失”与“误归属”的主要防线。

### 3.4 回合/选择业务校验（actor 是否有权操作）

代表文件：
- `src/game/flow/turn/TurnDispatch.lua`
- `src/game/flow/turn/TurnDispatchValidator.lua`
- `src/game/flow/turn/ItemSlotData.lua`
- `src/game/flow/turn/TickChoiceTimeout.lua`
- `src/game/flow/turn/GameplayLoopTickSteps.lua`

现状：
- `next` 与 `item_slot_*` 都要求 `actor_role_id`。
- `next` 要求 actor 必须等于当前回合玩家。
- `choice_select/cancel` 要求 actor 等于 choice owner（`choice.meta.player_id` 或当前玩家）。
- 倒计时自动动作会主动补 actor（当前回合玩家）。

结论：
- 业务层已经把 `actor_role_id` 当成强约束，不再容忍“无身份动作”。

### 3.5 Role 定向事件与调试屏

代表文件：
- `src/presentation/shared/UIEvents.lua`
- `src/presentation/interaction/ui_intent_dispatcher/ViewCommandDispatcher.lua`
- `src/presentation/api/presentation_ports/DebugPorts.lua`

现状：
- `ui_events.send_to_all` 依赖 `ui_events.roles` 列表。
- `ui_events.send_to_role` 直接调用 `role.send_ui_custom_event`。
- 调试屏开关依赖 `toggle_action_log` 的 `actor_role_id`，按 role 维护独立显示状态。

结论：
- “UI 事件广播/单播”机制明确，但初始化角色列表缺失会影响广播效果。

### 3.6 场景/控制相关 role 用例

代表文件：
- `src/presentation/render/BoardScene.lua`
- `src/presentation/render/board_runtime/player_units.lua`
- `src/presentation/render/status3d_service/scene.lua`
- `src/presentation/render/status3d_service/status.lua`
- `src/presentation/render/TargetChoiceEffects.lua`
- `src/presentation/api/host_runtime/Raycast.lua`
- `src/game/flow/turn/TurnCameraPolicy.lua`
- `src/presentation/api/presentation_ports/ui_sync/CameraSync.lua`
- `src/core/RuntimeEditorExports.lua`

现状：
- 玩家单位、状态3D、射线检测、目标选择等都以 role 能力为执行体。
- 目标选择会校验 `payload.actor_role_id` 是否等于 owner。
- 相机跟随由 `camera_helper.target_role_id` + ECA `follow_camera` 事件驱动，编辑器再通过 `get_camera_target()`取 role。

结论：
- 场景层不是“player 文本状态机”，而是“role 能力调用层”。

### 3.7 商业/货币用例

代表文件：
- `src/game/systems/commerce/PaidCurrencyBridge.lua`

现状：
- 通过 `GameAPI.get_role(player.id)` 获取 role，调用 `get_commodity_count/consume_commodity/show_goods_purchase_panel`。
- 构建 `player_id_by_role_id` 映射，用于支付事件反查玩家。

结论：
- 这是一个“role 经济能力适配器”，但绕过了 `runtime_ports.resolve_role` 统一入口。

## 4. 当前不一致点与风险

1. 概念命名混用：`player_id`、`role_id`、`actor_role_id` 在不同层语义接近但命名不统一。
2. 身份来源分散：有的链路从 `data.role`，有的从 `UIManager.client_role`，有的从 `current_player_id` 或 `meta.player_id`。
3. 端口一致性不足：部分业务直接用 `GameAPI.get_role`，未经过统一 role resolver。
4. 作用域污染风险：任何遗漏 `runtime.set_client_role(nil)` 都可能导致 UI 串客户端。
5. 广播前置依赖：`ui_events.send_to_all` 在 roles 未注入时静默无效。

## 5. 统一一致方案（建议作为项目规范）

### 5.1 统一术语与数据契约

唯一身份主键：
- `actor_role_id`（整数）：所有“谁触发动作”的标准字段。

对象与主键区分：
- `role`：引擎能力对象（可调用 API），不能直接作为持久身份。
- `role_id`：`runtime.resolve_role_id(role)` 得到的稳定 id。
- `player.id`：领域玩家主键；在角色驱动模式下应等于 `role_id`。

choice 所有权：
- 统一字段：`choice.meta.player_id`（语义：owner role id）。

### 5.2 统一 actor 解析优先级

所有 UI 点击 intent 使用同一优先级：
1. 显式字段（intent 已带 `actor_role_id`）
2. 事件 `data.role`
3. `UIManager.client_role`
4. `ui_model.current_player_id`
5. 若仍为空：拒绝并提示，不进入业务 dispatch

说明：
- 第 4 步只作为“避免卡死”的容错，正常路径应在 1~3 命中。

### 5.3 统一“需要 actor”的 intent 白名单

下列 intent 必须携带 `actor_role_id`：
- `ui_button`: `next`、`auto`、`item_slot_*`
- `choice_select`
- `choice_cancel`
- `market_confirm`
- `toggle_action_log`

任何新增交互按钮，若会触发回合/选择状态变化，默认加入白名单。

### 5.4 统一 UI role 作用域写法

规则：
- 禁止散落式手动切换 `UIManager.client_role`。
- 统一使用：
  - `runtime.with_client_role(role, fn)`（单 role）
  - `runtime.for_each_role_or_global(fn)`（多 role）
- 退出逻辑必须复位为 nil。

### 5.5 统一 role 解析入口

规则：
- 业务层禁止直接 `GameAPI.get_role`（除 `runtime_ports/default` 或 host adapter 层）。
- 统一通过：
  - `runtime_ports.resolve_role(s)`（核心业务）
  - `host_runtime.resolve_role(_with)`（表现层/场景层）

### 5.6 统一数值规范

- 所有 role id / player id 输入必须经 `NumberUtils.to_integer` 归一。
- 禁止在业务代码中直接 `tonumber` 或 `type(x)=="number"` 做身份判断。

### 5.7 统一失败策略

- “身份缺失”属于可恢复错误：提示 + warn + 拒绝本次动作。
- “身份不匹配”属于安全错误：直接拒绝（不自动修正）。
- “角色未映射”属于观战降级：`can_operate=false`，保留可见但不可操作。

## 6. 推荐的角色身份模型（项目内）

建议固定一套逻辑模型：

- Identity 层：`actor_role_id`（数字）
- Capability 层：`role`（对象）
- Domain 层：`player`（领域实体，`player.id` 与 role 绑定）

转换函数仅保留三类：
- `role -> role_id`: `runtime.resolve_role_id(role)`
- `player_id -> role`: `runtime_ports.resolve_role(player_id)`
- `choice -> owner_role_id`: `choice.meta.player_id` / current player fallback

## 7. 与 `ui_manager_lib.md` 的对齐结论

已经对齐：
1. 使用 `UIManager.client_role` 做客户端隔离。
2. 输入事件使用 `data.role` 识别触发者。
3. 使用 `send_ui_custom_event` 做定向 UI 事件。

仍需长期守护：
1. `client_role` 生命周期（防污染）。
2. actor 必填契约的覆盖率（新入口别漏）。
3. role 解析入口统一（避免旁路 `GameAPI.get_role`）。

## 8. 验收基线（供后续开发/评审使用）

1. 任意能推进回合/选择的 UI 操作，日志中都应有可解析 `actor_role_id`。
2. 非当前回合玩家触发 `next/item_slot_*` 必须被拒绝。
3. choice owner 之外的玩家提交 `choice_select/cancel` 必须被拒绝。
4. 多客户端下 UI 差异显示应仅受 `client_role` 作用域控制，且不会串屏。
5. `send_to_all` / `send_to_role` 的事件目标要与预期角色集合一致。

---

如果后续要落地这套规范，建议先做一轮“静态契约清理”：
- 收敛命名（`actor_role_id` / `owner_role_id`）
- 收敛入口（role resolver）
- 收敛作用域（with_client_role / for_each_role_or_global）

以上不涉及行为变更时，可作为纯重构推进。
