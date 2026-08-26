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

-- payload 可以是 intent 本身,也可以是包着 intent 的信封;非表一律不认。
local function _resolve_intent(payload)
  if type(payload) ~= "table" then
    return nil
  end
  local intent = payload.intent or payload
  if type(intent) ~= "table" then
    return nil
  end
  return intent
end

local function _choice_intent(intent)
  return intent.kind == "need_choice" and intent.choice_spec
end

local function _popup_intent(intent)
  return intent.kind == "push_popup" and intent.payload
end

local function _popup_opts_of(intent, opts)
  return intent.popup_opts or intent.opts or opts
end

function intent_output.dispatch(game, payload, opts)
  local intent = _resolve_intent(payload)
  if intent == nil then
    return nil
  end
  if _choice_intent(intent) then
    return intent_output.open_choice(game, intent.choice_spec, opts)
  end
  if _popup_intent(intent) then
    return intent_output.push_popup(game, intent.payload, _popup_opts_of(intent, opts))
  end
  return nil
end

return intent_output

--[[ mutate4lua-manifest
version=4
projectHash=8b08f78445637da5
scope.0.id=chunk:src/rules/ports/intent_output.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=46
scope.0.semanticHash=03304902740ae718
scope.1.id=function:_call_optional
scope.1.kind=function
scope.1.startLine=4
scope.1.endLine=8
scope.1.semanticHash=c0adb2d80aa93455
scope.2.id=function:intent_output.open_choice
scope.2.kind=function
scope.2.startLine=10
scope.2.endLine=12
scope.2.semanticHash=1f86a7a73bccfed0
scope.3.id=function:intent_output.push_popup
scope.3.kind=function
scope.3.startLine=14
scope.3.endLine=16
scope.3.semanticHash=b5230bf8769ee3f1
scope.4.id=function:_resolve_intent
scope.4.kind=function
scope.4.startLine=19
scope.4.endLine=28
scope.4.semanticHash=3b1c9249040f53a7
scope.5.id=function:intent_output.dispatch
scope.5.kind=function
scope.5.startLine=30
scope.5.endLine=43
scope.5.semanticHash=ba55061fbd8fa6e2
]]
