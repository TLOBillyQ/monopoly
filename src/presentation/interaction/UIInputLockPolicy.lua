local market_ui = require("src.presentation.shared.MarketLayout")
local panel_presenter = require("src.presentation.ui.UIPanelPresenter")
local role_context = require("src.presentation.state.UIRoleContext")

local input_lock_policy = {}

local function _set_debug_toggle_touch(ui, enabled)
  ui:set_touch_enabled("图片_82", enabled == true)
  ui:set_touch_enabled("基础_行动日志按钮", enabled == true)
end

local function _force_item_slots_visible_for_player(ui, ctx)
  if not ui or not ui.set_visible then
    return
  end
  if not ctx or ctx.is_player_role ~= true then
    return
  end
  local slots = ui.item_slots or {}
  for _, slot_name in ipairs(slots) do
    ui:set_visible(slot_name, true)
  end
end

local function _can_popup_confirm(ui)
  return true
end

local function _set_screen_locked(ui, screen)
  if not screen then
    return
  end
  local option_nodes = screen.option_buttons or {}
  for _, name in ipairs(option_nodes) do
    ui:set_touch_enabled(name, false)
  end
  if screen.under_button then
    ui:set_touch_enabled(screen.under_button, false)
  end
  if screen.confirm then
    ui:set_touch_enabled(screen.confirm, false)
  end
  if screen.cancel then
    ui:set_touch_enabled(screen.cancel, false)
  end
end

function input_lock_policy.apply(state, deps)
  assert(state ~= nil and state.ui ~= nil, "missing state.ui")
  assert(deps ~= nil and deps.runtime ~= nil, "missing deps.runtime")
  local runtime = deps.runtime
  local ui = state.ui

  if not ui.set_touch_enabled then
    return
  end

  if not ui.input_blocked then
    if ui.popup_active and ui.popup_screen and ui.popup_screen.confirm then
      ui:set_touch_enabled(ui.popup_screen.confirm, _can_popup_confirm(ui))
    end
    _set_debug_toggle_touch(ui, true)
    return
  end

  local model = state.ui_model or {}
  runtime.for_each_role_or_global(function(role)
    local ctx = role_context.resolve(role, model, { runtime = runtime })
    panel_presenter.apply_base_non_player_visibility(ui, false)
    _force_item_slots_visible_for_player(ui, ctx)
    panel_presenter.render_auto_controls_for_role(ui, ctx, model)
  end)
  runtime.set_client_role(nil)

  ui:set_touch_enabled("行动按钮", false)

  local slots = ui.item_slots or {}
  for _, slot_name in ipairs(slots) do
    ui:set_touch_enabled(slot_name, false)
  end

  local screens = ui.choice_screens or {}
  _set_screen_locked(ui, screens.player)
  _set_screen_locked(ui, screens.target)
  _set_screen_locked(ui, screens.remote)
  _set_screen_locked(ui, screens.building)

  local market_buttons = market_ui.item_buttons or {}
  for _, name in ipairs(market_buttons) do
    ui:set_touch_enabled(name, false)
  end
  if market_ui.confirm_button then
    ui:set_touch_enabled(market_ui.confirm_button, false)
  end
  if market_ui.cancel_button then
    ui:set_touch_enabled(market_ui.cancel_button, false)
  end

  if ui.popup_active and ui.popup_screen and ui.popup_screen.confirm then
    ui:set_touch_enabled(ui.popup_screen.confirm, true)
  end

  _set_debug_toggle_touch(ui, true)
end

return input_lock_policy
