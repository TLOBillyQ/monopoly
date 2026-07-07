local logger = require("src.foundation.log")

local target_resolve = {}

local function _target_in_candidates(candidates, target_id)
  for _, cand in ipairs(candidates) do
    if cand.id == target_id then
      return true
    end
  end
  return false
end

function target_resolve.resolve_valid_target(game, player, item_id, context, resolve_candidates)
  local target = game:find_player_by_id(context.target_id)
  if not target or target.id == player.id or target.eliminated then
    logger.warn("目标玩家无效:", tostring(context.target_id))
    return nil
  end
  local candidates = resolve_candidates(game, player, item_id)
  if not _target_in_candidates(candidates, target.id) then
    logger.warn("目标玩家不在可选列表中:", tostring(context.target_id))
    return nil
  end
  return target
end

return target_resolve

--[[ mutate4lua-manifest
version=2
projectHash=0337b01e8ba8674a
scope.0.id=chunk:src/rules/items/target_resolve.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=29
scope.0.semanticHash=4a3e462d2fa6bb35
scope.0.lastMutatedAt=2026-07-07T02:09:59Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=5
scope.0.lastMutationKilled=5
scope.1.id=function:target_resolve.resolve_valid_target:14
scope.1.kind=function
scope.1.startLine=14
scope.1.endLine=26
scope.1.semanticHash=be15407b011db6e9
scope.1.lastMutatedAt=2026-07-07T02:09:59Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=10
scope.1.lastMutationKilled=10
]]
