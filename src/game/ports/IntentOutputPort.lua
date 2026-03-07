local intent_output_port = {}

local function _fallback_port()
  return require("src.game.flow.output_adapters.IntentOutputAdapter").build()
end

local function _resolve_port(game)
  if not game then
    return nil
  end
  local port = game.intent_output_port
  if type(port) == "table" then
    return port
  end
  return _fallback_port()
end

function intent_output_port.open_choice(game, choice_spec, opts)
  local port = _resolve_port(game)
  if not port or type(port.open_choice) ~= "function" then
    return nil
  end
  return port.open_choice(game, choice_spec, opts)
end

function intent_output_port.push_popup(game, payload, opts)
  local port = _resolve_port(game)
  if not port or type(port.push_popup) ~= "function" then
    return false
  end
  return port.push_popup(game, payload, opts)
end

function intent_output_port.dispatch(game, payload, opts)
  if type(payload) ~= "table" then
    return nil
  end
  local intent = payload.intent or payload
  if type(intent) ~= "table" then
    return nil
  end
  if intent.kind == "need_choice" and intent.choice_spec then
    return intent_output_port.open_choice(game, intent.choice_spec, opts)
  end
  if intent.kind == "push_popup" and intent.payload then
    local popup_opts = intent.popup_opts or intent.opts or opts
    return intent_output_port.push_popup(game, intent.payload, popup_opts)
  end
  return nil
end

return intent_output_port
