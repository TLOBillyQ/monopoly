local market_ui = require("src.ui.schema.market_layout")
local base_nodes = require("src.ui.schema.base")
local ui_touch_policy = require("src.ui.input.touch")

local lock_policy = {}

local INPUT_LOCK_VISIBILITY_EXEMPT_NODES = {
  [base_nodes.auto_button] = true,
  [base_nodes.auto_label] = true,
  [base_nodes.action_log_button] = true,
  [base_nodes.skin_button] = true,
  [base_nodes.skin_label] = true,
  [base_nodes.gallery_button] = true,
}

local BASE_AUXILIARY_TOUCH_NODES = {
  base_nodes.skin_button,
  base_nodes.gallery_button,
  base_nodes.share_button,
}

local function _set_node_visible_unless_exempt(ui, name, visible)
  if not INPUT_LOCK_VISIBILITY_EXEMPT_NODES[name] then
    ui:set_visible(name, visible == true)
  end
end

local function _set_base_hidden_nodes_visible(ui, visible)
  if not ui or not ui.set_visible then
    return
  end
  local nodes = ui.base_hidden_nodes or {}
  for _, name in ipairs(nodes) do
    _set_node_visible_unless_exempt(ui, name, visible)
  end
end

local function _set_base_auxiliary_touch(ui, enabled)
  ui_touch_policy.set_auto_controls_touch(ui, enabled)
  ui_touch_policy.set_action_log_toggle_touch(ui, enabled)
  ui_touch_policy.set_many_touch_enabled(ui, BASE_AUXILIARY_TOUCH_NODES, enabled)
  ui_touch_policy.set_share_decor_touch(ui)
end

local function _apply_unlocked_state(ui, allow_always_show_touch)
  _set_base_auxiliary_touch(ui, allow_always_show_touch)
end

local function _lock_choice_screens(ui)
  local screens = ui.choice_screens or {}
  ui_touch_policy.set_choice_screen_locked(ui, screens.player)
  ui_touch_policy.set_choice_screen_locked(ui, screens.target)
  ui_touch_policy.set_choice_screen_locked(ui, screens.remote)
  ui_touch_policy.set_choice_screen_locked(ui, screens.building)
end

local function _set_market_cancel_touch(ui, enabled)
  local cancel_buttons = market_ui.cancel_buttons or {}
  ui_touch_policy.set_many_touch_enabled(ui, cancel_buttons, enabled)
end

local function _lock_market_buttons(ui, allow_cancel)
  ui_touch_policy.set_many_touch_enabled(ui, market_ui.item_buttons or {}, false)
  if market_ui.confirm_button then
    ui:set_touch_enabled(market_ui.confirm_button, false)
  end
  _set_market_cancel_touch(ui, allow_cancel == true)
end

-- 输入锁不关道具槽 touch：槽位是「全时段可点、点了必有反馈」口径(#162),
-- 移动动画等阶段位里点卡应当拿到「现阶段该卡无法使用」,而不是零反应。
-- 点击本身不会推进状态——item_slot_click 在 turn 闸上豁免,裁定后要么发提示
-- 要么转成 choice_select 再过一次闸。
local function _apply_locked_state(ui, allow_always_show_touch)
  _set_base_hidden_nodes_visible(ui, false)
  for _, slot_name in ipairs(ui.item_slots or {}) do
    ui:set_visible(slot_name, true)
  end
  ui:set_touch_enabled(base_nodes.action_button, false)
  ui:set_touch_enabled(base_nodes.end_button, false)
  _lock_choice_screens(ui)
  _lock_market_buttons(ui, ui.market_active == true)
  _set_base_auxiliary_touch(ui, allow_always_show_touch)
end

function lock_policy.apply(state, deps)
  assert(state ~= nil and state.ui ~= nil, "missing state.ui")
  assert(deps ~= nil, "missing deps")
  local ui = state.ui
  local allow_always_show_touch = ui.market_active ~= true

  if not ui.set_touch_enabled then
    return
  end

  if not ui.input_blocked then
    _apply_unlocked_state(ui, allow_always_show_touch)
    return
  end

  _apply_locked_state(ui, allow_always_show_touch)
end

return lock_policy

--[[ mutate4lua-manifest
version=4
projectHash=9ab13ae321d44b06
scope.0.id=chunk:src/ui/input/lock.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=105
scope.0.semanticHash=4d1de577c7d85cc8
scope.1.id=function:_set_node_visible_unless_exempt
scope.1.kind=function
scope.1.startLine=22
scope.1.endLine=26
scope.1.semanticHash=f47cec11680d4851
scope.2.id=function:_set_base_hidden_nodes_visible
scope.2.kind=function
scope.2.startLine=28
scope.2.endLine=36
scope.2.semanticHash=7daea2a770130ff3
scope.3.id=function:_set_base_auxiliary_touch
scope.3.kind=function
scope.3.startLine=38
scope.3.endLine=43
scope.3.semanticHash=31eaacd98a27e57a
scope.4.id=function:_apply_unlocked_state
scope.4.kind=function
scope.4.startLine=45
scope.4.endLine=47
scope.4.semanticHash=4ad1b5cb81e9ede6
scope.5.id=function:_lock_choice_screens
scope.5.kind=function
scope.5.startLine=49
scope.5.endLine=55
scope.5.semanticHash=4299455b9405a1a5
scope.6.id=function:_set_market_cancel_touch
scope.6.kind=function
scope.6.startLine=57
scope.6.endLine=60
scope.6.semanticHash=150ca82811872745
scope.7.id=function:_lock_market_buttons
scope.7.kind=function
scope.7.startLine=62
scope.7.endLine=68
scope.7.semanticHash=0a38f35e0f6d24f1
scope.8.id=function:_apply_locked_state
scope.8.kind=function
scope.8.startLine=74
scope.8.endLine=84
scope.8.semanticHash=850af4d9db3bf055
scope.9.id=function:lock_policy.apply
scope.9.kind=function
scope.9.startLine=86
scope.9.endLine=102
scope.9.semanticHash=d60c08a9bf27c6c1
]]
