-- cosmetics port:纯接口壳,不 require 上层实现(工单 #244 拆除 ui→app 上行依赖)。
-- transaction / transaction_state 实现由 app 组合根(compose_game,ADR 0001)经
-- install 注入;build 返回稳定转发代理,消费方可在装配前 require,真正取用未注入的
-- 实现字段时才断言失败。
local cosmetics_port = {}

local _impl = nil
local _pending = {}

local function _resolve(field)
  local impl = assert(_impl, "cosmetics port not installed: " .. field)
  return assert(impl[field], "cosmetics port impl missing field: " .. field)
end

local function _forwarding_proxy(field)
  return setmetatable({}, {
    __index = function(_, key)
      return _resolve(field)[key]
    end,
  })
end

local _port = {
  transaction = _forwarding_proxy("transaction"),
  transaction_state = _forwarding_proxy("transaction_state"),
}

function cosmetics_port.install(impl)
  assert(type(impl) == "table", "cosmetics_port.install: impl must be a table")
  _impl = impl
  local pending = _pending
  _pending = {}
  for _, callback in ipairs(pending) do
    callback(_port)
  end
  return _port
end

-- 注入完成后执行(已注入则立即执行):消费方模块加载期的初始化副作用挂这里,
-- 避免 require 顺序反向耦合装配顺序。
function cosmetics_port.when_installed(callback)
  if _impl ~= nil then
    callback(_port)
    return
  end
  _pending[#_pending + 1] = callback
end

function cosmetics_port.build()
  return _port
end

return cosmetics_port

--[[ mutate4lua-manifest
version=4
projectHash=8d1844189044fd04
scope.0.id=chunk:src/ui/seams/cosmetics.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=54
scope.0.semanticHash=4a9af564c3e77947
scope.1.id=function:_resolve
scope.1.kind=function
scope.1.startLine=10
scope.1.endLine=13
scope.1.semanticHash=f1f7f786b0efc5a9
scope.2.id=function:_forwarding_proxy
scope.2.kind=function
scope.2.startLine=15
scope.2.endLine=21
scope.2.semanticHash=29eaaa7de21074fe
scope.3.id=function:<anonymous>
scope.3.kind=function
scope.3.startLine=17
scope.3.endLine=19
scope.3.semanticHash=80395d47b3616254
scope.4.id=function:cosmetics_port.install
scope.4.kind=function
scope.4.startLine=28
scope.4.endLine=37
scope.4.semanticHash=b8df5863ed30ef47
scope.5.id=function:cosmetics_port.when_installed
scope.5.kind=function
scope.5.startLine=41
scope.5.endLine=47
scope.5.semanticHash=3d4da11f525efe1c
scope.6.id=function:cosmetics_port.build
scope.6.kind=function
scope.6.startLine=49
scope.6.endLine=51
scope.6.semanticHash=1136505bd37c301e
]]
