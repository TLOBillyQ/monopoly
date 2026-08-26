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
version=4
projectHash=e4bbc4ec885e7ac3
scope.0.id=chunk:src/rules/items/target_resolve.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=29
scope.0.semanticHash=59f4685d32735a18
scope.1.id=function:_target_in_candidates
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=12
scope.1.semanticHash=c5f64229af83c49e
scope.2.id=function:target_resolve.resolve_valid_target
scope.2.kind=function
scope.2.startLine=14
scope.2.endLine=26
scope.2.semanticHash=d7c0328c1eecbbbd
]]
