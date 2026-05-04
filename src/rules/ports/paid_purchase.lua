local port = {}
local configured_gateway = nil

local function _assert_gateway_shape(gateway)
  assert(type(gateway) == "table", "invalid market paid gateway")
  assert(type(gateway.setup_for_game) == "function", "market paid gateway missing setup_for_game")
  assert(type(gateway.can_start) == "function", "market paid gateway missing can_start")
  assert(type(gateway.start) == "function", "market paid gateway missing start")
  return gateway
end

local function _resolve_gateway()
  if configured_gateway == nil then
    return nil
  end
  return configured_gateway
end

function port.configure(gateway)
  configured_gateway = _assert_gateway_shape(gateway)
end

function port.reset_for_tests()
  configured_gateway = nil
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
