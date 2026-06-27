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
}

local function _set_base_hidden_nodes_visible(ui, visible)
  if not ui or not ui.set_visible then
    return
  end
  local nodes = ui.base_hidden_nodes or {}
  for _, name in ipairs(nodes) do
    if not INPUT_LOCK_VISIBILITY_EXEMPT_NODES[name] then
      ui:set_visible(name, visible == true)
    end
  end
end

local function _set_base_auxiliary_touch(ui, enabled)
  ui_touch_policy.set_auto_controls_touch(ui, enabled)
  ui_touch_policy.set_action_log_toggle_touch(ui, enabled)
  ui_touch_policy.set_many_touch_enabled(ui, BASE_AUXILIARY_TOUCH_NODES, enabled)
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

local function _apply_locked_state(ui, allow_always_show_touch)
  _set_base_hidden_nodes_visible(ui, false)
  ui_touch_policy.set_many_touch_enabled(ui, ui.item_slots or {}, false)
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
version=2
projectHash=d8011603ae0ed92c
scope.0.id=chunk:src/ui/input/lock.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=93
scope.0.semanticHash=0e21268e4175dac1
scope.0.lastMutatedAt=2026-06-23T03:24:02Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=25
scope.0.lastMutationKilled=25
scope.1.id=function:_set_base_auxiliary_touch:33
scope.1.kind=function
scope.1.startLine=33
scope.1.endLine=37
scope.1.semanticHash=819fb2d4c9494009
scope.1.lastMutatedAt=2026-06-23T03:24:02Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=3
scope.1.lastMutationKilled=3
scope.2.id=function:_apply_unlocked_state:39
scope.2.kind=function
scope.2.startLine=39
scope.2.endLine=41
scope.2.semanticHash=e0bef7a41cac3595
scope.2.lastMutatedAt=2026-06-23T03:24:02Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=1
scope.2.lastMutationKilled=1
scope.3.id=function:_lock_choice_screens:43
scope.3.kind=function
scope.3.startLine=43
scope.3.endLine=49
scope.3.semanticHash=7000d033466bf4a0
scope.3.lastMutatedAt=2026-06-23T03:24:02Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=5
scope.3.lastMutationKilled=5
scope.4.id=function:_lock_market_buttons:51
scope.4.kind=function
scope.4.startLine=51
scope.4.endLine=59
scope.4.semanticHash=26aee84d1bb886fa
scope.4.lastMutatedAt=2026-06-23T03:24:02Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=3
scope.4.lastMutationKilled=3
scope.5.id=function:lock_policy.apply:74
scope.5.kind=function
scope.5.startLine=74
scope.5.endLine=90
scope.5.semanticHash=42a72f660f4da8b6
scope.5.lastMutatedAt=2026-06-23T03:24:02Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=8
scope.5.lastMutationKilled=8
]]
