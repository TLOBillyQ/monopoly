local bankruptcy_port = {}

local function _resolve_port(game)
  assert(game ~= nil, "missing game for bankruptcy_port")
  local port = game.bankruptcy_port
  assert(type(port) == "table", "missing game.bankruptcy_port")
  return port
end

function bankruptcy_port.eliminate(game, player, opts)
  local port = _resolve_port(game)
  local eliminate = port.eliminate
  assert(type(eliminate) == "function", "missing bankruptcy_port.eliminate")
  return eliminate(game, player, opts)
end

return bankruptcy_port
