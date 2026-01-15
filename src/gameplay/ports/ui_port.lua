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

function UI.push_popup(game, payload)
  local port = get_port(game)
  if port and port.push_popup then
    return port:push_popup(payload) ~= false
  end
  return false
end

return UI
