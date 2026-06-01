local tasks = require("src.config.content.share_tasks")

local share_task = {
  tasks = tasks,
}

function share_task.find_task(period, name)
  for _, task in ipairs(tasks) do
    if task.period == period and task.name == name then
      return task
    end
  end
  return nil
end

function share_task.reward_for(period, name)
  local task = share_task.find_task(period, name)
  return task and task.reward_amount or nil
end

-- The host task system tracks progress and pays rewards. Lua exposes the
-- mirrored config but must not grant extra currency for a share-task claim.
function share_task.claim()
  return { ok = false, reason = "host_managed" }
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
