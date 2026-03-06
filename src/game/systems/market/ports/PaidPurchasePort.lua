local runtime_ports = require("src.core.RuntimePorts")

local port = {}

local function _resolve_gateway()
  local resolver = runtime_ports.resolve_market_paid_gateway
  if type(resolver) == "function" then
    local gateway = resolver()
    if gateway ~= nil then
      return gateway
    end
  end
  return require("src.app.bootstrap.payment.EggyPaidPurchaseGateway")
end

function port.setup_for_game(game, on_purchase)
  return _resolve_gateway().setup_for_game(game, on_purchase)
end

function port.can_start(game, player, entry)
  return _resolve_gateway().can_start(game, player, entry)
end

function port.start(game, player, entry)
  return _resolve_gateway().start(game, player, entry)
end

return port
