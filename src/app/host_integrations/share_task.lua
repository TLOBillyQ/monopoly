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
version=4
projectHash=3bff46627855d825
scope.0.id=chunk:src/app/host_integrations/share_task.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=28
scope.0.semanticHash=0cd738befdbfaa26
scope.1.id=function:share_task.find_task
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=14
scope.1.semanticHash=14068a46f54d4dd7
scope.2.id=function:share_task.reward_for
scope.2.kind=function
scope.2.startLine=16
scope.2.endLine=19
scope.2.semanticHash=cd47e17bb06dc8f9
scope.3.id=function:share_task.claim
scope.3.kind=function
scope.3.startLine=23
scope.3.endLine=25
scope.3.semanticHash=33ef2bc04e4b382d
]]
