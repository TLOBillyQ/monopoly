local intent_output = {}
local contract_helper = require("src.rules.ports.contract_helper")

local function _call_optional(game, method_name, default_result, ...)
  return contract_helper.call_optional_method(game, "intent_output_port", method_name, {
    default_result = default_result,
  }, ...)
end

function intent_output.open_choice(game, choice_spec, opts)
  return _call_optional(game, "open_choice", nil, game, choice_spec, opts)
end

function intent_output.push_popup(game, payload, opts)
  return _call_optional(game, "push_popup", false, game, payload, opts)
end

function intent_output.dispatch(game, payload, opts)
  if type(payload) ~= "table" then
    return nil
  end
  local intent = payload.intent or payload
  if type(intent) ~= "table" then
    return nil
  end
  if intent.kind == "need_choice" and intent.choice_spec then
    return intent_output.open_choice(game, intent.choice_spec, opts)
  end
  if intent.kind == "push_popup" and intent.payload then
    local popup_opts = intent.popup_opts or intent.opts or opts
    return intent_output.push_popup(game, intent.payload, popup_opts)
  end
  return nil
end

return intent_output

--[[ mutate4lua-manifest
version=2
projectHash=e881eeb99d5bdab9
scope.0.id=chunk:src/rules/ports/intent_output.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=37
scope.0.semanticHash=be18eef7670a9d19
scope.1.id=function:_call_optional:4
scope.1.kind=function
scope.1.startLine=4
scope.1.endLine=8
scope.1.semanticHash=0388d89897b06d86
scope.2.id=function:intent_output.open_choice:10
scope.2.kind=function
scope.2.startLine=10
scope.2.endLine=12
scope.2.semanticHash=d01cf99bfcc7b383
scope.3.id=function:intent_output.push_popup:14
scope.3.kind=function
scope.3.startLine=14
scope.3.endLine=16
scope.3.semanticHash=a39603eeca9102e9
scope.4.id=function:intent_output.dispatch:18
scope.4.kind=function
scope.4.startLine=18
scope.4.endLine=34
scope.4.semanticHash=c1045f9b1b125036
]]
