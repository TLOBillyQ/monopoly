-- 皮肤交易请求/UI action 共用一套字段别名(type|action, slot_index|index|slot),
-- 归一化只住这里:别名链一变,transaction_actions 与 skin_panel 门面同步生效。
local request_shape = {}

function request_shape.kind(request)
  if type(request) == "table" then
    return request.type or request.action
  end
  return request
end

function request_shape.slot_index(request)
  if type(request) == "table" then
    return request.slot_index or request.index or request.slot or 1
  end
  return 1
end

function request_shape.unlock_source(request, fallback)
  if type(request) == "table" then
    return request.source
  end
  return fallback
end

return request_shape

--[[ mutate4lua-manifest
version=4
projectHash=c989b62004a2d461
scope.0.id=chunk:src/ui/schema/skin_request.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=27
scope.0.semanticHash=1625e6ce6032466b
scope.1.id=function:request_shape.kind
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=10
scope.1.semanticHash=ce12b9418feee1e5
scope.2.id=function:request_shape.slot_index
scope.2.kind=function
scope.2.startLine=12
scope.2.endLine=17
scope.2.semanticHash=26447ef5b24dbca8
scope.3.id=function:request_shape.unlock_source
scope.3.kind=function
scope.3.startLine=19
scope.3.endLine=24
scope.3.semanticHash=d1f811aca3ede5d0
]]
