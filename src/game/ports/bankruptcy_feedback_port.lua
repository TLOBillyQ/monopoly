local bankruptcy_feedback_port = {}

local function _resolve_port(game)
  assert(game ~= nil, "missing game for bankruptcy_feedback_port")
  local port = game.bankruptcy_feedback_port
  assert(type(port) == "table", "missing game.bankruptcy_feedback_port")
  return port
end

function bankruptcy_feedback_port.on_tiles_cleared(game, player, owned_tile_ids)
  local port = _resolve_port(game)
  local on_tiles_cleared = port.on_tiles_cleared
  assert(type(on_tiles_cleared) == "function", "missing bankruptcy_feedback_port.on_tiles_cleared")
  return on_tiles_cleared(game, player, owned_tile_ids)
end

return bankruptcy_feedback_port
