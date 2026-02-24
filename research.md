# 托管按钮输入锁定逻辑调研

## 1. 概述

托管按钮允许玩家将当前回合控制权交给 AI 自动执行。该功能涉及多个层面的锁定机制：

1. **输入锁定（Input Lock）** - 控制 UI 触控是否响应
2. **角色控制锁定（Role Control Lock）** - 控制角色是否可被操作
3. **托管状态管理** - 记录玩家是否处于托管模式

### 1.1 产品期望（最新）

1. 所有角色视角下，托管按钮都应始终可点击（含输入锁开启期间）。
2. 点击托管按钮只切换**当前点击角色自身**的 `player.auto`，不影响其他角色。
3. 托管按钮触控权限不应依赖“是否本地角色”的限制逻辑。

---

## 2. 核心文件与逻辑

### 2.1 托管按钮 UI 定义

**`src/presentation/shared/UINodes.lua`**
```lua
nodes.buttons = {
  action = "行动按钮",
  auto = "托管按钮",        -- 托管按钮
  close = "关闭",
  -- ...
}

nodes.labels = {
  auto = "托管_文本",       -- 托管文本标签
}

nodes.effects = {
  auto = "基础屏-AI托管光效",  -- 托管光效
}
```

### 2.2 托管按钮点击事件

**`src/presentation/interaction/intent_builders/BasicIntents.lua`**
```lua
{
  name = ui_nodes.buttons.auto,
  build_intent = function()
    return { type = "ui_button", id = "auto" }
  end,
}
```

### 2.3 托管意图处理与标准化

**`src/presentation/interaction/UIIntentDispatcher.lua:63-75`**
```lua
local function _normalize_auto_intent(intent)
  local local_role_id = _resolve_local_role_id()
  if local_role_id == nil then
    logger.warn("auto intent ignored without local role_id")
    return nil
  end
  local action = {}
  for k, v in pairs(intent) do
    action[k] = v
  end
  action.actor_role_id = local_role_id  -- 绑定当前角色ID
  return action
end
```

**`src/presentation/interaction/UIIntentDispatcher.lua:109-114`**
```lua
if intent_type == "ui_button" and intent.id == "auto" then
  action = _normalize_auto_intent(intent)
  if action == nil then
    return true
  end
end
```

### 2.4 托管状态切换

**`src/game/flow/turn/TurnDispatch.lua:100-108`**
```lua
if action.id == "auto" then
  local player = _resolve_actor_player(game, action)
  if not player then
    return { status = "rejected" }
  end
  player.auto = not (player.auto == true)  -- 切换auto状态
  return { status = "applied" }
end
```

---

## 3. 输入锁定机制

### 3.1 输入锁状态定义

**`src/presentation/api/ui_view_service/state.lua`**
```lua
function M.build_ui_state()
  return {
    input_blocked = false,  -- 默认未锁定
    -- ...
  }
end
```

### 3.2 输入锁启用时机

**`src/game/flow/turn/GameplayLoopRuntime.lua:6-8`**
```lua
function runtime.is_phase_input_blocked(phase)
  return phase == "wait_move_anim" or phase == "wait_action_anim" or phase == "detained_wait"
end
```

在动画播放阶段（移动动画、行动动画、拘留等待）会启用输入锁定。

### 3.3 输入锁应用策略

**`src/presentation/interaction/UIInputLockPolicy.lua`**

```lua
-- 未锁定状态：仅维护弹窗确认与调试开关触控
if not ui.input_blocked then
  if ui.popup_active and ui.popup_screen and ui.popup_screen.confirm then
    ui:set_touch_enabled(ui.popup_screen.confirm, _can_popup_confirm())
  end
  ui_touch_policy.set_action_log_toggle_touch(ui, true)
  return
end

-- 输入锁开启：锁住回合内操作入口
ui:set_touch_enabled(ui_nodes.buttons.action, false)

-- 锁住选择屏幕
ui_touch_policy.set_choice_screen_locked(ui, screens.player)
ui_touch_policy.set_choice_screen_locked(ui, screens.target)
ui_touch_policy.set_choice_screen_locked(ui, screens.remote)
ui_touch_policy.set_choice_screen_locked(ui, screens.building)

-- 锁住黑市按钮
ui_touch_policy.set_many_touch_enabled(ui, market_ui.item_buttons or {}, false)
if market_ui.confirm_button then
  ui:set_touch_enabled(market_ui.confirm_button, false)
end
if market_ui.cancel_button then
  ui:set_touch_enabled(market_ui.cancel_button, false)
end

-- 弹窗确认按钮保持可点（超时/确认链路依赖）
if ui.popup_active and ui.popup_screen and ui.popup_screen.confirm then
  ui:set_touch_enabled(ui.popup_screen.confirm, true)
end

-- 关键：托管按钮在输入锁期间仍可点击！
ui_touch_policy.set_auto_controls_touch(ui, true)
ui_touch_policy.set_action_log_toggle_touch(ui, true)
```

**重点**：托管按钮是输入锁的例外，即使输入被锁定，托管按钮仍然可以点击。这是由 `UIInputLockPolicy` 保证的。

**注意**：`UIPanelPresenter.render_auto_controls_for_role` 中使用“本地角色匹配”来控制托管按钮触控，会与“所有角色都可点击”的产品期望冲突。

---

## 4. 完整调用链分析

### 4.1 事件触发阶段

**`src/presentation/interaction/UIEventRouter.lua:67-111`**

```lua
function ui_event_router.bind(state, get_game)
  -- ...
  local function dispatch_intent(intent, data)
    if intent and intent.actor_role_id == nil then
      intent.actor_role_id = _resolve_actor_role_id(data)
    end
    -- ...
    ui_intent_dispatcher.dispatch(state, resolve_game(), intent, dispatch_opts)
  end

  local route_specs = _build_default_route_specs(state)
  for _, route in ipairs(route_specs) do
    ui_event_bindings.register_node_click(cache, route.name, function(data)
      local intent = route.build_intent(data)
      if intent then
        dispatch_intent(intent, data)
      end
    end, registered, listeners)
  end
end
```

托管按钮点击流程：
1. `UIEventBindings.register_node_click` 注册"托管按钮"节点点击监听
2. 点击时调用 `BasicIntents.build()` 中的 `build_intent` 生成 `{type="ui_button", id="auto"}`
3. `dispatch_intent` 补充 `actor_role_id` 后调用 `UIIntentDispatcher.dispatch`

### 4.2 意图分发与标准化

**`src/presentation/interaction/UIIntentDispatcher.lua:74-86`**

```lua
local function _normalize_auto_intent(intent)
  local local_role_id = _resolve_local_role_id()
  if local_role_id == nil then
    logger.warn("auto intent ignored without local role_id")
    return nil
  end
  local action = {}
  for k, v in pairs(intent) do
    action[k] = v
  end
  action.actor_role_id = local_role_id  -- 关键：绑定当前点击角色ID
  return action
end
```

关键逻辑：
- 托管意图必须通过 `_normalize_auto_intent` 标准化
- 若无法解析当前点击角色ID，意图被忽略（返回 `nil`）
- 标准化后的动作包含 `actor_role_id`，用于定位要切换托管状态的玩家

### 4.3 动作验证与分发

**`src/presentation/interaction/UIIntentDispatcher.lua:110-127`**

```lua
if intent_type == "ui_button"
    or intent_type == "choice_select"
    or intent_type == "choice_cancel" then
  local action = intent
  if intent_type == "ui_button" and intent.id == "auto" then
    action = _normalize_auto_intent(intent)
    if action == nil then
      return true  -- 已处理但无效
    end
  end
  action_port.dispatch_action(game, state, action, opts)
  return true
end
```

### 4.4 托管状态切换

**`src/game/flow/turn/TurnDispatch.lua:101-108`**

```lua
if action.id == "auto" then
  local player = _resolve_actor_player(game, action)
  if not player then
    return { status = "rejected" }
  end
  player.auto = not (player.auto == true)  -- 切换布尔状态
  return { status = "applied" }
end
```

状态切换后：
1. `TurnDispatch.dispatch_action` 返回 `{status = "applied"}`
2. 调用者设置 `state.ui_dirty = true` 标记UI需要刷新
3. 下次游戏循环 `tick` 时触发UI刷新

---

## 5. UI状态流转与更新

### 5.1 数据流向

```
游戏模型层 (Game Model)
    player.auto = true/false
           ↓
UIModelProjection (数据投影)
    build_auto_enabled_by_player()
           ↓
UIModel (UI模型)
    auto_enabled_by_player[player_id]
           ↓
UIPanelPresenter (表现层)
    更新托管光效可见性 + 托管标签文本
```

### 5.2 UIModel 构建

**`src/presentation/state/UIModel.lua:51-74`**

```lua
function M.update(prev_model, game, env, dirty)
  -- ...
  local auto_enabled_by_player = projection.build_auto_enabled_by_player(game.players)
  -- ...
  return {
    -- ...
    auto_enabled_by_player = auto_enabled_by_player,
    -- ...
  }
end
```

**`src/presentation/state/UIModelProjection.lua:91-100`**

```lua
function projection.build_auto_enabled_by_player(players)
  local out = {}
  for _, player in ipairs(players or {}) do
    local player_id = player and player.id
    if player_id then
      out[player_id] = player.auto == true
    end
  end
  return out
end
```

### 5.3 托管标签构建

**`src/presentation/state/UIModelPanelBuilder.lua`**

```lua
function M.build_auto_label_by_player(players, enabled_by_player)
  local out = {}
  for _, player in ipairs(players or {}) do
    if player and player.id then
      out[player.id] = M.build_auto_label(enabled_by_player and enabled_by_player[player.id] == true)
    end
  end
  return out
end

function M.build_auto_label(auto_play)
  if auto_play then
    return "自动：开"
  else
    return "自动：关"
  end
end
```

### 5.4 视觉效果更新

**`src/presentation/ui/UIPanelPresenter.lua:77-90`**

```lua
local function _resolve_auto_effect_visible(ui_model, ctx)
  if not ui_model or not ctx then
    return false
  end
  local role_id = ctx.role_id
  if role_id == nil then
    return false
  end
  if ctx.is_player_role ~= true then
    return false
  end
  local auto_by_player = ui_model.auto_enabled_by_player or {}
  return auto_by_player[role_id] == true
end
```

在 `refresh` 函数中调用：
```lua
ui:set_visible(ui_nodes.effects.auto, _resolve_auto_effect_visible(ui_model, ctx))
```

---

## 6. 触控策略深度分析

### 6.1 UITouchPolicy 实现

**`src/presentation/interaction/UITouchPolicy.lua:20-32`**

```lua
function touch_policy.set_auto_controls_touch(ui, auto_enabled, controls)
  if not ui or not ui.set_touch_enabled then
    return
  end
  controls = controls or ui.auto_control_nodes or { ui_nodes.buttons.auto, ui_nodes.labels.auto }
  for _, name in ipairs(controls) do
    if name == ui_nodes.buttons.auto then
      ui:set_touch_enabled(name, auto_enabled == true)
    else
      ui:set_touch_enabled(name, false)  -- 标签始终禁用触控
    end
  end
end
```

**关键细节**：
- 只有 `ui_nodes.buttons.auto`（"托管按钮"）会根据 `auto_enabled` 参数启用/禁用
- 其他节点（如标签）始终禁用触控（`false`）
- 这意味着托管按钮的可见性和触控性是分开控制的

### 6.2 UIPanelPresenter 中的问题实现

**`src/presentation/ui/UIPanelPresenter.lua:21-48`**

```lua
function panel_presenter.render_auto_controls_for_role(ui, ctx, ui_model, local_role_id)
  -- ...
  local auto_enabled = false
  if local_role_id ~= nil then
    auto_enabled = ctx ~= nil and ctx.role_id == local_role_id
  else
    auto_enabled = ctx and ctx.is_player_role == true or false
  end
  -- ...
  local allow_touch = auto_enabled  -- ❌ 问题：角色匹配 ≠ 按钮可点击
  ui_touch_policy.set_auto_controls_touch(ui, allow_touch, controls)
end
```

**语义混淆**：
- `auto_enabled` 实际含义：**"当前角色是否是本地角色"**
- 但变量名暗示：**"托管是否启用"**
- 结果是：非本地角色视角会被禁用托管按钮，不符合最新产品期望

**为什么这是问题**：
1. 托管按钮应在任何情况下都可点击（输入锁的例外）
2. 点击托管仅依赖 `actor_role_id` 定位玩家并切换 `player.auto`
3. UI层不应以“本地角色匹配”额外限制托管按钮触控

### 6.3 UIInputLockPolicy 的正确实现

**`src/presentation/interaction/UIInputLockPolicy.lua:68-70`**

```lua
-- 业务例外：托管开关与调试开关在输入锁期间仍允许切换。
ui_touch_policy.set_auto_controls_touch(ui, true)
ui_touch_policy.set_action_log_toggle_touch(ui, true)
```

这里明确将托管按钮设为始终可点击（`true`），无论输入锁状态如何，也不区分是否本地角色。

---

## 7. 角色控制锁定机制

### 7.1 配置开关

**`Config/GameplayRules.lua`**
```lua
local gameplay_rules = {
  role_control_lock_enabled = true,  -- 启用角色控制锁定
  -- ...
}
```

### 7.2 角色控制锁实现

**`src/presentation/interaction/UIRoleControlLockPolicy.lua`**

通过 `BUFF_FORBID_CONTROL` buff 状态禁止角色控制：

```lua
local function _sync_role_lock(lock_state, role_id, unit, buff_id)
  local entry = lock_state.by_role[role_id] or {}
  if entry.unit and entry.unit ~= unit and entry.owned then
    _remove_lock(entry.unit, buff_id)
  end

  if not unit then
    lock_state.by_role[role_id] = nil
    return
  end

  local count = unit.get_state_count(buff_id)
  if count == 0 then
    unit.add_state(buff_id)  -- 添加禁止控制状态
    entry.owned = true
  end
  -- ...
end
```

### 7.3 豁免机制

**`src/presentation/api/ui_view_service/state.lua`**
```lua
function M.build_ui_state()
  return {
    role_control_lock_exempt_by_role = {},      -- 按角色豁免
    role_control_lock_exempt_count_by_role = {}, -- 按角色豁免计数
    -- ...
  }
end
```

---

## 8. 动作验证器中的特殊处理

**`src/game/flow/turn/TurnDispatchValidator.lua:141-148`**

```lua
function validator.should_block_action(gate_state_or_flag, action_or_type)
  -- ...

  -- 托管按钮动作永远不被阻止（即使输入锁开启）
  if action_type == "ui_button"
      and type(action_or_type) == "table"
      and action_or_type.id == "auto" then
    return false
  end

  -- ... 其他检查
end
```

托管按钮动作在验证器层面也被明确豁免。

---

## 9. 自动执行逻辑

### 9.1 AutoRunner

**`src/game/flow/turn/AutoRunner.lua`**

```lua
function auto_runner:next_action(dt, env)
  if not self.enabled then
    return nil
  end

  -- 只有当前玩家处于托管状态时才自动执行
  if env.current_player_auto ~= true then
    return nil
  end

  self.timer = self.timer + dt
  if self.timer < self.interval then
    return nil
  end
  self.timer = 0

  if env.modal_active then
    if env.modal_buttons and #env.modal_buttons > 0 then
      return { type = "modal_button", index = 1 }
    end
    return { type = "modal_confirm" }
  end

  -- 托管状态下自动点击"next"按钮
  local actor_role_id = env.current_player_id or env.current_player_index
  return { type = "ui_button", id = "next", actor_role_id = actor_role_id }
end
```

### 9.2 游戏循环中的自动执行

**`src/game/flow/turn/GameplayLoop.lua:205-231`**

```lua
function gameplay_loop.step_auto_runner(game, state, dt, context)
  -- 输入锁开启时，跳过后续自动执行
  if ui_sync_ports.is_input_blocked and ui_sync_ports.is_input_blocked(state) then
    return nil
  end

  -- 托管弹窗最小可见时间检查
  local min_popup_visible = gameplay_rules.auto_popup_min_visible_seconds or 0
  -- ...

  local ctx = _build_auto_context(game, context)
  local auto_action = state.auto_runner:next_action(dt, ctx)

  if auto_action then
    _dispatch_action_with_close_choice(game, state, auto_action, ports)
  end
  return auto_action
end
```

**注意**：输入锁开启时，`step_auto_runner` 会跳过自动执行。这意味着即使玩家处于托管状态，在动画播放期间也不会自动点击 next。

---

## 10. 关键总结

### 10.1 锁定层次

| 层次 | 机制 | 控制范围 | 托管按钮例外 |
|------|------|----------|--------------|
| 输入锁 | `input_blocked` | UI 触控响应 | ✅ 是 |
| 角色控制锁 | `BUFF_FORBID_CONTROL` | 角色物理/逻辑控制 | N/A |
| 动作验证 | `should_block_action` | 动作是否被接受 | ✅ 是 |
| 自动执行 | `step_auto_runner` | AI 自动点击 next | 输入锁开启时暂停 |

### 10.2 托管按钮特殊性

托管按钮在以下层面都被特殊处理：

1. **UIInputLockPolicy**: `set_auto_controls_touch(ui, true)` 明确保持可触控
2. **TurnDispatchValidator**: 返回 `false` 不阻止托管动作
3. **GameplayLoop**: 输入锁开启时暂停 auto_runner，但托管按钮仍可点击切换状态

### 10.3 状态流转

```
玩家点击托管按钮
    ↓
生成 {type="ui_button", id="auto"} 意图
    ↓
UIIntentDispatcher 标准化意图（绑定 actor_role_id）
    ↓
TurnDispatch 切换 player.auto = not player.auto
    ↓
UIModelProjection 从 players 重新构建 auto_enabled_by_player
    ↓
UIPanelPresenter 根据 auto_enabled 更新托管按钮视觉效果
    ↓
若 player.auto == true:
    AutoRunner 开始自动点击 next 推进回合
```

---

## 11. 问题根因深度分析

### 11.1 触控权限的多层检查

托管按钮的触控状态受多层逻辑影响：

| 层级 | 文件 | 逻辑 | 当前行为 |
|------|------|------|----------|
| 输入锁策略 | UIInputLockPolicy.lua | `set_auto_controls_touch(ui, true)` | 始终允许 |
| 面板呈现器 | UIPanelPresenter.lua | `allow_touch = auto_enabled` | 角色匹配才允许 |
| 触控策略 | UITouchPolicy.lua | 根据参数设置按钮触控 | 按传入参数执行 |

### 11.2 根因分析

**`GameplayLoop.tick` 执行顺序**（简化）：

```lua
function gameplay_loop.tick(game, state, dt)
  -- 1. 同步输入锁状态
  gameplay_loop_runtime.sync_input_blocked(state, phase, ports)

  -- 2. 执行自动运行器（若输入锁开启则跳过）
  gameplay_loop.step_auto_runner(game, state, dt, auto_ctx)

  -- 3. 从脏状态刷新UI
  local ui_refreshed = ui_sync_ports.refresh_from_dirty(game, state, dirty)

  -- 4. 应用输入锁（条件性）
  if input_blocked_changed or (is_input_blocked and ui_refreshed) then
    ui_sync_ports.apply_input_lock(state)
  end
end
```

**问题本质**：

1. `refresh_from_dirty` 调用 `UIPanelPresenter.refresh`
2. `render_auto_controls_for_role` 用“本地角色匹配”覆盖托管按钮触控
3. 覆盖后的结果与产品期望冲突：非本地角色视角下托管按钮不可点

该问题核心是**权限语义错误**，不是输入锁时序本身。

### 11.3 语义混淆详解

**变量命名问题**：

```lua
-- UIPanelPresenter.lua
local auto_enabled = ctx ~= nil and ctx.role_id == local_role_id
-- 实际含义：当前角色是否是本地角色
-- 变量名暗示：托管功能是否启用
```

**与 UIModel 的命名对比**：

```lua
-- UIModelProjection.lua
out[player_id] = player.auto == true  -- 真正的托管启用状态

-- UIModel.lua 字段命名
auto_enabled_by_player  -- 按玩家ID索引的托管状态表
```

**UIPanelPresenter 应改为**：

```lua
local allow_touch = true  -- 托管按钮始终可点击
```

---

## 12. 修复方案对比

### 方案A：修改 UIPanelPresenter（推荐）

```lua
-- src/presentation/ui/UIPanelPresenter.lua:46
local allow_touch = true
```

**优点**：

- 与 `UIInputLockPolicy` 逻辑一致
- 满足产品期望：所有角色可随时点击托管按钮
- 改动最小，风险最低

### 方案B：移除 UIPanelPresenter 的触控控制

将 `render_auto_controls_for_role` 中的触控设置逻辑完全移除，仅依赖 `UIInputLockPolicy`。

```lua
function panel_presenter.render_auto_controls_for_role(...)
  -- ... 标签设置逻辑 ...
  -- 移除：ui_touch_policy.set_auto_controls_touch(...)
end
```

**优点**：

- 单一职责，`UIInputLockPolicy` 专门处理触控策略
- 避免未来再次出现权限覆盖冲突

### 方案C：统一触控策略入口

在 `UIInputLockPolicy.apply` 中增加参数，由外部传入托管按钮的触控状态。

**缺点**：

- 增加复杂性
- 需要修改多处调用

### 方案D：补强 auto 意图角色绑定（建议与方案A组合）

在 `_normalize_auto_intent` 中优先保留 `intent.actor_role_id`，仅在缺失时回退 `_resolve_local_role_id()`。

```lua
local actor_role_id = intent.actor_role_id or _resolve_local_role_id()
action.actor_role_id = actor_role_id
```

**收益**：

- 明确“谁点击，切谁的托管状态”
- 降低事件上下文变化导致的角色绑定风险

---

## 13. 相关测试用例

### 13.1 现有测试

**`.github/tests/suites/presentation_ui.lua:1514-1560`**

```lua
local function _test_apply_input_lock_keeps_auto_controls_enabled()
  -- 验证输入锁期间托管按钮仍可点击
  ui_view.apply_input_lock(state)
  -- 断言：托管按钮触控已启用
end
```

### 13.2 建议新增测试

```lua
-- 1) 所有角色视角下托管按钮都可点击（含 input_blocked=true）
function test_auto_button_enabled_for_all_roles_when_locked()
  assert(role1_touch["托管按钮"] == true)
  assert(role2_touch["托管按钮"] == true)
end

-- 2) 角色A点击只切换角色A的 player.auto，不影响角色B
function test_auto_toggle_only_affects_actor_role()
  dispatch_auto_click(role1)
  assert(player1.auto == true)
  assert(player2.auto == false)
end

-- 3) 角色A/B交替点击时，各自状态独立切换
function test_auto_toggle_is_independent_between_roles()
  dispatch_auto_click(role1)
  dispatch_auto_click(role2)
  assert(player1.auto == true)
  assert(player2.auto == true)
end

-- 4) actor_role_id 缺失时应拒绝，不应误切换他人状态
function test_auto_toggle_rejected_without_actor_role_id()
  local result = dispatch_auto_without_actor()
  assert(result.status == "rejected")
end
```
