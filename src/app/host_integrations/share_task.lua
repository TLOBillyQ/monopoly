local share_task = {
  host_pending = true,
  reward = { currency = "金币", amount = 1000 },
}

-- TODO_HOST_INTEGRATION: connect host share callback and completion state.
function share_task.is_available()
  return false
end

function share_task.claim()
  return { ok = false, reason = "host_pending" }
end

return share_task

--[[ mutate4lua-manifest
version=2
projectHash=a176448e31dd9f7f
scope.0.id=chunk:src/app/host_integrations/share_task.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=16
scope.0.semanticHash=fb590083d4f76c9d
scope.1.id=function:share_task.is_available:7
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=9
scope.1.semanticHash=bcac7ee0a0364e45
scope.2.id=function:share_task.claim:11
scope.2.kind=function
scope.2.startLine=11
scope.2.endLine=13
scope.2.semanticHash=91a6156db801a84d
]]
