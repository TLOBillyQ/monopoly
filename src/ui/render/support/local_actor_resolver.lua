local runtime = require("src.ui.render.support.runtime_ui")

local resolver = {}

local function _resolve_role_id_from_event(data)
  local role = data and data.role or nil
  return runtime.resolve_role_id(role)
end

local function _resolve_client_role_id()
  return runtime.resolve_role_id(runtime.get_client_role())
end

-- 解析链只到 client_role 为止(#341):事件解析不出身份即返回 nil(静默),不得
-- 把 A 的点击当成 B 的。「上一次点击者缓存」随 #601 整体退役——既不读也不写,
-- state 上不再出现 local_actor_role_id。
function resolver.resolve_from_event(state, data)
  local role_id = _resolve_role_id_from_event(data)
  if role_id ~= nil then
    return role_id
  end
  return _resolve_client_role_id()
end

resolver.resolve_turn_bound = resolver.resolve_from_event

return resolver

--[[ mutate4lua-manifest
version=4
projectHash=9cfbe5ee56bc4174
scope.0.id=chunk:src/ui/render/support/local_actor_resolver.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=28
scope.0.semanticHash=5746470d5bb7230d
scope.1.id=function:_resolve_role_id_from_event
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=8
scope.1.semanticHash=c96449d4e2d135bb
scope.2.id=function:_resolve_client_role_id
scope.2.kind=function
scope.2.startLine=10
scope.2.endLine=12
scope.2.semanticHash=4cbc7bdc8226bca5
scope.3.id=function:resolver.resolve_from_event
scope.3.kind=function
scope.3.startLine=17
scope.3.endLine=23
scope.3.semanticHash=e2cc5b066ce597dd
]]
