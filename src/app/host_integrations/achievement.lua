local achievement = {
  host_pending = true,
}

-- TODO_HOST_INTEGRATION: connect host achievement progress APIs.
function achievement.add_progress(_event_id, _count)
  return false
end

function achievement.snapshot()
  return {}
end

return achievement

--[[ mutate4lua-manifest
version=2
projectHash=e06e12e6e42ee990
scope.0.id=chunk:src/app/host_integrations/achievement.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=15
scope.0.semanticHash=9183d97d5452bbbb
scope.1.id=function:achievement.add_progress:6
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=8
scope.1.semanticHash=661911099bef5177
scope.2.id=function:achievement.snapshot:10
scope.2.kind=function
scope.2.startLine=10
scope.2.endLine=12
scope.2.semanticHash=bb2a07830ae1c7dc
]]
