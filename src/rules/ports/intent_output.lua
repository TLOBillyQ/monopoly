local intent_output = {}
local contract_helper = require("src.rules.ports.contract_helper")
local logger = require("src.foundation.log.logger")

local function _call_optional(game, method_name, default_result, ...)
  return contract_helper.call_optional_method(game, "intent_output_port", method_name, {
    default_result = default_result,
  }, ...)
end

function intent_output.open_choice(game, choice_spec, opts)
  logger.info_unlimited(
    "[diag-firsttap-port] intent_output.open_choice enter spec_kind=", tostring(choice_spec and choice_spec.kind),
    " port_table=", tostring(type(game and game.intent_output_port)),
    " port.open_choice_fn=", tostring(type(game and game.intent_output_port and game.intent_output_port.open_choice))
  )
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
