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
    obstacle_snapshot = {},
    branches = {},
    distance = distance,
    parity = context.branch_parity or distance,
  }
end

local function _queue_anim(game, player, state)
  local longest = 0
  for _, branch in ipairs(state.branches) do
    longest = math.max(longest, #branch)
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
version=4
projectHash=5687b5b2ec2938ea
scope.0.id=chunk:src/rules/items/obstacle_clear.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=64
scope.0.semanticHash=9636bd1dfc5376c6
scope.1.id=function:_new_state
scope.1.kind=function
scope.1.startLine=11
scope.1.endLine=22
scope.1.semanticHash=22de69da9f7bffc2
scope.2.id=function:_queue_anim
scope.2.kind=function
scope.2.startLine=24
scope.2.endLine=47
scope.2.semanticHash=1aee9c91136ac488
scope.3.id=function:obstacle_clear.handle
scope.3.kind=function
scope.3.startLine=49
scope.3.endLine=61
scope.3.semanticHash=e52e9859d934b5d1
]]
