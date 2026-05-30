local gift = {
  host_pending = true,
  skin_product_id = 5005,
  threshold = 100,
}

-- TODO_HOST_INTEGRATION: connect host gift counter and unlock callback.
function gift.is_unlocked()
  return false
end

function gift.resolve_reward()
  return {
    kind = "skin",
    product_id = gift.skin_product_id,
    threshold = gift.threshold,
    unlocked = gift.is_unlocked(),
  }
end

return gift

--[[ mutate4lua-manifest
version=2
projectHash=8ef5aec4f54458f8
scope.0.id=chunk:src/app/host_integrations/gift.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=22
scope.0.semanticHash=88e57d43c7b01217
scope.1.id=function:gift.is_unlocked:8
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=10
scope.1.semanticHash=8b2dcd6db7b394cc
scope.2.id=function:gift.resolve_reward:12
scope.2.kind=function
scope.2.startLine=12
scope.2.endLine=19
scope.2.semanticHash=76c90e65f4b2e6d2
]]
