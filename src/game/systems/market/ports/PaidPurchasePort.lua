local runtime_ports = require("src.core.RuntimePorts")

local port = {}

local function _resolve_gateway()
  local resolver = runtime_ports.resolve_market_paid_gateway
  if type(resolver) ~= "function" then
    return nil
  end
  return resolver()
end

function port.setup_for_game(game, on_purchase)
  return assert(_resolve_gateway(), "missing market paid gateway").setup_for_game(game, on_purchase)
end

function port.can_start(game, player, entry)
  return assert(_resolve_gateway(), "missing market paid gateway").can_start(game, player, entry)
end

function port.start(game, player, entry)
  return assert(_resolve_gateway(), "missing market paid gateway").start(game, player, entry)
end

return port
