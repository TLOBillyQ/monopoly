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

-- 车道守卫用:共享测试基线要求付费网关处于已配置态;spec teardown 拆到未配置态后
-- 不装回会让同进程后续 suite 撞「missing market paid gateway」(#217)。
function port.is_configured()
  return configured_gateway ~= nil
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
version=4
projectHash=8b08f78445637da5
scope.0.id=chunk:src/rules/ports/paid_purchase.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=46
scope.0.semanticHash=cc641c9ccab95460
scope.1.id=function:_assert_gateway_shape
scope.1.kind=function
scope.1.startLine=4
scope.1.endLine=10
scope.1.semanticHash=e2dbb62243115b84
scope.2.id=function:_resolve_gateway
scope.2.kind=function
scope.2.startLine=12
scope.2.endLine=17
scope.2.semanticHash=710cb48908ddcc1c
scope.3.id=function:port.configure
scope.3.kind=function
scope.3.startLine=19
scope.3.endLine=21
scope.3.semanticHash=4afb02f78251fcb2
scope.4.id=function:port.reset_for_tests
scope.4.kind=function
scope.4.startLine=23
scope.4.endLine=25
scope.4.semanticHash=f308d8708726be18
scope.5.id=function:port.is_configured
scope.5.kind=function
scope.5.startLine=29
scope.5.endLine=31
scope.5.semanticHash=70efc1221c5d6d62
scope.6.id=function:port.setup_for_game
scope.6.kind=function
scope.6.startLine=33
scope.6.endLine=35
scope.6.semanticHash=aba9250a8c6b104f
scope.7.id=function:port.can_start
scope.7.kind=function
scope.7.startLine=37
scope.7.endLine=39
scope.7.semanticHash=d590c542c8c308c5
scope.8.id=function:port.start
scope.8.kind=function
scope.8.startLine=41
scope.8.endLine=43
scope.8.semanticHash=d590c542c8c308c5
]]
