local gameplay_loop = require("src.game.turn.GameplayLoop")
local ui_view = require("src.ui.UIView")

local ui_controller = {}

function ui_controller.dispatch(state, game, intent, opts)
  assert(intent ~= nil, "missing intent")
  local intent_type = intent.type
  if intent_type == "ui_button"
      or intent_type == "choice_select"
      or intent_type == "choice_cancel" then
    gameplay_loop.dispatch_action(game, state, intent, opts)
    return
  end

  if intent_type == "market_confirm" then
    gameplay_loop.dispatch_action(game, state, {
      type = "choice_select",
      choice_id = intent.choice_id,
      option_id = intent.option_id,
    }, opts)
    return
  end

  if intent_type == "market_select" then
    ui_view.select_market_option(state, intent.option_id)
    return
  end

  if intent_type == "popup_confirm" then
    ui_view.close_popup(state)
  end
end

return ui_controller
