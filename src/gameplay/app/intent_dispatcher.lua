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

  local intents = nil
  if payload.intent or payload.intents then
    intents = {}
    if payload.intent then
      intents[#intents + 1] = payload.intent
    end
    if type(payload.intents) == "table" then
      for i = 1, #payload.intents do
        intents[#intents + 1] = payload.intents[i]
      end
    end
  elseif payload[1] then
    intents = payload
  end

  if intents then
    local handled = false
    for i = 1, #intents do
      handled = dispatch_one(game, intents[i]) or handled
    end
    return handled
  end

  return dispatch_one(game, payload)
end

IntentDispatcher.dispatch_from_result = IntentDispatcher.dispatch

return IntentDispatcher
