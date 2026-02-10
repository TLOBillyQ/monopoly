local market_ui = require("src.ui.MarketLayout")
local panel_presenter = require("src.ui.UIPanelPresenter")
local role_context = require("src.ui.UIRoleContext")

local input_lock_policy = {}

function input_lock_policy.apply(state, deps)
  assert(state ~= nil and state.ui ~= nil, "missing state.ui")
  assert(deps ~= nil and deps.runtime ~= nil, "missing deps.runtime")
  local runtime = deps.runtime
  local ui = state.ui

  if not ui.set_touch_enabled then
    return
  end

  if not ui.input_blocked then
    if ui.popup_active and ui.popup and ui.popup.confirm then
      ui:set_touch_enabled(ui.popup.confirm, true)
    end
    return
  end

  local model = state.ui_model or {}
  runtime.for_each_role_or_global(function(role)
    local ctx = role_context.resolve(role, model, { runtime = runtime })
    panel_presenter.apply_base_non_player_visibility(ui, false)
    panel_presenter.render_auto_controls_for_role(ui, ctx, model)
  end)
  runtime.set_client_role(nil)

  ui:set_touch_enabled("行动按钮", false)

  local slots = ui.item_slots or {}
  for _, slot_name in ipairs(slots) do
    ui:set_touch_enabled(slot_name, false)
  end

  if ui.choice then
    local option_nodes = ui.choice.option_buttons or {}
    for _, name in ipairs(option_nodes) do
      ui:set_touch_enabled(name, false)
    end
    if ui.choice.cancel then
      ui:set_touch_enabled(ui.choice.cancel, false)
    end
  end

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

  if ui.popup and ui.popup.confirm then
    ui:set_touch_enabled(ui.popup.confirm, false)
  end
end

return input_lock_policy
