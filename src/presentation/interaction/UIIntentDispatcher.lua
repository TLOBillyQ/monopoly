local logger = require("src.core.Logger")
local turn_dispatch = require("src.game.flow.turn.TurnDispatch")
local ui_view = require("src.presentation.api.UIView")

local intent_dispatcher = {}

local function _should_block_intent(state, intent)
  if turn_dispatch.should_block_action then
    return turn_dispatch.should_block_action(state, intent)
  end
  return false
end

function intent_dispatcher.dispatch(state, game, intent, opts)
  assert(intent ~= nil, "missing intent")
  local intent_type = intent.type
  if _should_block_intent(state, intent) then
    return
  end
  if not game then
    logger.warn("ui intent without game:", tostring(intent_type))
    return
  end

  if intent_dispatcher.dispatch_game_action(state, game, intent, opts) then
    return
  end

  intent_dispatcher.dispatch_view_command(state, intent)
end

function intent_dispatcher.dispatch_game_action(state, game, intent, opts)
  local intent_type = intent and intent.type
  if not intent_type then
    return false
  end

  if intent_type == "ui_button"
      or intent_type == "choice_select"
      or intent_type == "choice_cancel" then
    turn_dispatch.dispatch_action(game, state, intent, opts)
    return true
  end

  if intent_type == "market_confirm" then
    if not intent.choice_id or not intent.option_id then
      logger.warn("market_confirm missing ids:", tostring(intent.choice_id), tostring(intent.option_id))
      return true
    end
    turn_dispatch.dispatch_action(game, state, {
      type = "choice_select",
      choice_id = intent.choice_id,
      option_id = intent.option_id,
    }, opts)
    return true
  end

  return false
end

function intent_dispatcher.dispatch_view_command(state, intent)
  local intent_type = intent and intent.type
  if not intent_type then
    return false
  end

  if intent_type == "market_select" then
    ui_view.select_market_option(state, intent.option_id)
    return true
  end

  if intent_type == "popup_confirm" then
    ui_view.close_popup(state)
    return true
  end

  return false
end

return intent_dispatcher
