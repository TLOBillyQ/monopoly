local UI = {}

local function get_port(game)
  if game and game.ui_port then
    return game.ui_port
  end
  return nil
end

function UI.is_available(game)
  return get_port(game) ~= nil
end

function UI.set_port(game, port)
  if not game then
    return
  end
  game.ui_port = port
end

function UI.push_popup(game, payload)
  local port = get_port(game)
  if port and port.push_popup then
    return port:push_popup(payload) ~= false
  end
  return false
end

function UI.request_choice(game, payload)
  local port = get_port(game)
  if port and port.request_choice then
    return port:request_choice(payload) ~= false
  end
  return false
end

function UI.play_animation(game, payload)
  local port = get_port(game)
  if port and port.play_animation then
    return port:play_animation(payload) ~= false
  end
  
  if payload and payload.on_complete then
    payload.on_complete()
  end
  return false
end

return UI
