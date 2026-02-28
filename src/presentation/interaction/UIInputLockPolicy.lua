local market_ui = require("src.presentation.shared.MarketLayout")
local base_nodes = require("src.presentation.canvas.base.nodes")
local ui_touch_policy = require("src.presentation.interaction.UITouchPolicy")

local input_lock_policy = {}

local function _set_base_hidden_nodes_visible(ui, visible)
  if not ui or not ui.set_visible then
    return
  end
  local nodes = ui.base_hidden_nodes or {}
  for _, name in ipairs(nodes) do
    ui:set_visible(name, visible == true)
  end
end

function input_lock_policy.apply(state, deps)
  assert(state ~= nil and state.ui ~= nil, "missing state.ui")
  assert(deps ~= nil, "missing deps")
  local ui = state.ui

  if not ui.set_touch_enabled then
    return
  end

  -- 未锁定：仅维护调试开关触控，不干预其他路径。
  if not ui.input_blocked then
    ui_touch_policy.set_action_log_toggle_touch(ui, true)
    return
  end

  _set_base_hidden_nodes_visible(ui, false)
  ui_touch_policy.set_many_touch_enabled(ui, ui.item_slots or {}, false)
  for _, slot_name in ipairs(ui.item_slots or {}) do
    ui:set_visible(slot_name, true)
  end

  -- 输入锁开启：先整体锁住回合内操作入口。
  ui:set_touch_enabled(base_nodes.action_button, false)

  local screens = ui.choice_screens or {}
  ui_touch_policy.set_choice_screen_locked(ui, screens.player)
  ui_touch_policy.set_choice_screen_locked(ui, screens.target)
  ui_touch_policy.set_choice_screen_locked(ui, screens.remote)
  ui_touch_policy.set_choice_screen_locked(ui, screens.building)

  ui_touch_policy.set_many_touch_enabled(ui, market_ui.item_buttons or {}, false)
  if market_ui.confirm_button then
    ui:set_touch_enabled(market_ui.confirm_button, false)
  end
  if market_ui.cancel_button then
    ui:set_touch_enabled(market_ui.cancel_button, false)
  end

  -- 业务例外：托管开关与调试开关在输入锁期间仍允许切换。
  ui_touch_policy.set_auto_controls_touch(ui, true)
  ui_touch_policy.set_action_log_toggle_touch(ui, true)
end

return input_lock_policy
