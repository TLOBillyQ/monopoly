local GameplayLoop = require("Manager.TurnManager.GameplayLoop")
local UIView = require("Manager.UIRoot.UIView")

local UIController = {}

function UIController.Dispatch(state, game, intent, opts)
  assert(intent ~= nil, "missing intent")
  local intent_type = intent.type
  if intent_type == "ui_button"
      or intent_type == "choice_select"
      or intent_type == "choice_cancel" then
    GameplayLoop.DispatchAction(game, state, intent, opts)
    return
  end

  if intent_type == "market_confirm" then
    GameplayLoop.DispatchAction(game, state, {
      type = "choice_select",
      choice_id = intent.choice_id,
      option_id = intent.option_id,
    }, opts)
    return
  end

  if intent_type == "market_select" then
    UIView.SelectMarketOption(state, intent.option_id)
    return
  end

  if intent_type == "popup_confirm" then
    UIView.ClosePopup(state)
  end
end

return UIController
