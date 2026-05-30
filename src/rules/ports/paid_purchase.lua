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

--[[ mutate4lua-manifest
version=2
projectHash=9f468a6292223f9c
scope.0.id=chunk:src/rules/ports/paid_purchase.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=40
scope.0.semanticHash=7d5dc252a58a0ba0
scope.1.id=function:_assert_gateway_shape:4
scope.1.kind=function
scope.1.startLine=4
scope.1.endLine=10
scope.1.semanticHash=1218bb73998e147a
scope.2.id=function:_resolve_gateway:12
scope.2.kind=function
scope.2.startLine=12
scope.2.endLine=17
scope.2.semanticHash=c6083157f6b4c97c
scope.3.id=function:port.configure:19
scope.3.kind=function
scope.3.startLine=19
scope.3.endLine=21
scope.3.semanticHash=23024e2414ebc07f
scope.4.id=function:port.reset_for_tests:23
scope.4.kind=function
scope.4.startLine=23
scope.4.endLine=25
scope.4.semanticHash=a7242f021cb60f90
scope.5.id=function:port.setup_for_game:27
scope.5.kind=function
scope.5.startLine=27
scope.5.endLine=29
scope.5.semanticHash=f9c411dc995fc1a3
scope.6.id=function:port.can_start:31
scope.6.kind=function
scope.6.startLine=31
scope.6.endLine=33
scope.6.semanticHash=81acd166736a5b11
scope.7.id=function:port.start:35
scope.7.kind=function
scope.7.startLine=35
scope.7.endLine=37
scope.7.semanticHash=d1b169ae1995a47b
]]
