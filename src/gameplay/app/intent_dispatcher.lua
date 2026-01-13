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
  if intent.kind == "push_popup" and intent.payload then
    if UI.is_available(game) then
      return UI.push_popup(game, intent.payload) ~= false
    end
    return false
  end
  return false
end

local function dispatch_many(game, intents)
  local handled = false
  for _, intent in ipairs(intents) do
    handled = dispatch_one(game, intent) or handled
  end
  return handled
end

function IntentDispatcher.dispatch(game, intent_or_list)
  if not intent_or_list then
    return false
  end
  if intent_or_list.intent or intent_or_list.intents then
    return IntentDispatcher.dispatch_from_result(game, intent_or_list)
  end
  if intent_or_list[1] then
    return dispatch_many(game, intent_or_list)
  end
  return dispatch_one(game, intent_or_list)
end

function IntentDispatcher.dispatch_from_result(game, res)
  if type(res) ~= "table" then
    return false
  end
  local handled = false
  if res.intent then
    handled = dispatch_one(game, res.intent) or handled
  end
  if res.intents then
    handled = dispatch_many(game, res.intents) or handled
  end
  return handled
end

return IntentDispatcher
