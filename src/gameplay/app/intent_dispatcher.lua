local Choice = require("src.gameplay.app.choice")
local UI = require("src.gameplay.ports.ui_port")

local IntentDispatcher = {}

local function dispatch_one(game, intent)
  if type(intent) ~= "table" then
    return false
  end
  if intent.kind == "need_choice" and intent.choice_spec then
    Choice.open(game, intent.choice_spec)
    return true
  end
  if intent.kind == "push_popup" and intent.payload and UI.is_available(game) then
    return UI.push_popup(game, intent.payload) ~= false
  end
  return false
end

function IntentDispatcher.dispatch(game, payload)
  if type(payload) ~= "table" then
    return false
  end

  if payload.intent then
    return dispatch_one(game, payload.intent)
  end

  if payload.kind then
    return dispatch_one(game, payload)
  end

  return false
end

IntentDispatcher.dispatch_from_result = IntentDispatcher.dispatch

return IntentDispatcher
