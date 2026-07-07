local event_kinds = require("src.config.gameplay.event_kinds")
local action_anim_port = require("src.foundation.ports.action_anim")
local runtime_constants = require("src.config.gameplay.runtime_constants")
local timing = require("src.config.gameplay.timing")
local event_feed = require("src.rules.ports.event_feed")
local obstacle_clear_walk = require("src.rules.items.obstacle_clear_walk")

local obstacle_clear = {}
local action_anim_duration = timing.action_anim_default_seconds or 1.0

local function _new_state(distance, context)
  assert(context ~= nil, "missing context")
  return {
    cleared = 0,
    roadblock_cleared = 0,
    mine_cleared = 0,
    cleared_map = {},
    obstacle_snapshot = {},
    branches = {},
    distance = distance,
    parity = context.branch_parity or distance,
  }
end

local function _queue_anim(game, player, state)
  local longest = 0
  for _, branch in ipairs(state.branches) do
    if #branch > longest then
      longest = #branch
    end
  end
  local step_time = 3.0 / runtime_constants.robot_speed
  local duration = longest * step_time
  if duration <= 0 then
    duration = action_anim_duration
  end

  local queued = action_anim_port.queue(game, {
    kind = "clear_obstacles",
    player_id = player.id,
    branches = state.branches,
    roadblock_cleared = state.roadblock_cleared,
    mine_cleared = state.mine_cleared,
    duration = duration,
  })
  if queued then
    return { ok = true, action_anim = true }
  end
  return true
end

function obstacle_clear.handle(game, player, cfg, context)
  local board = game.board
  local distance = cfg.distance or 12
  local state = _new_state(distance, context)
  obstacle_clear_walk.walk_and_clear(game, player, board, state, context)
  if state.cleared > 0 then
    event_feed.publish(game, {
      kind = event_kinds.obstacle_cleared,
      text = player.name .. " 清除前方障碍数：" .. state.cleared,
    })
  end
  return _queue_anim(game, player, state)
end

return obstacle_clear

--[[ mutate4lua-manifest
version=2
projectHash=08c804e2b2f0f335
scope.0.id=chunk:src/rules/items/obstacle_clear.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=67
scope.0.semanticHash=10ea3c5531828bd8
scope.0.lastMutatedAt=2026-07-07T02:44:06Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=survived
scope.0.lastMutationSites=18
scope.0.lastMutationKilled=16
scope.1.id=function:_new_state:11
scope.1.kind=function
scope.1.startLine=11
scope.1.endLine=23
scope.1.semanticHash=b1ea513c15726e16
scope.1.lastMutatedAt=2026-07-07T02:44:06Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=survived
scope.1.lastMutationSites=5
scope.1.lastMutationKilled=4
scope.2.id=function:obstacle_clear.handle:52
scope.2.kind=function
scope.2.startLine=52
scope.2.endLine=64
scope.2.semanticHash=e401146cea55962d
scope.2.lastMutatedAt=2026-07-07T02:44:06Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=7
scope.2.lastMutationKilled=7
]]
