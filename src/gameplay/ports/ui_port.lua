local UI = {}





local function get_port(game)
  if game and game.ui_port then
    return game.ui_port
  end
  return nil
end

function UI.is_available(game)
  local port = get_port(game)
  if port then
    return true
  end
  return game and game.ui_hooks ~= nil
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
  if game and game.ui_hooks and game.ui_hooks.push_popup then
    game.ui_hooks.push_popup({
      title = payload.title,
      body = payload.body,
      severity = payload.severity,
    })
    return true
  end
  return false
end

function UI.request_choice(game, payload)
  local port = get_port(game)
  if port and port.request_choice then
    return port:request_choice(payload) ~= false
  end
  if not game or not game.ui_hooks or not game.ui_hooks.request_choice then
    return false
  end
  game.ui_hooks.request_choice({
    title = payload.title,
    candidates = payload.candidates or payload.options,
    body_lines = payload.body_lines or {},
    on_select = payload.on_select,
    allow_cancel = payload.allow_cancel,
    cancel_label = payload.cancel_label,
  })
  return true
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
