local settlement = require("src.rules.land.settlement")
local blocking = require("src.turn.waits.blocking")

-- 落地结算完成、无 res.waiting 时进入 post_action 的等待路由。
-- 等价于 wait_action_anim 路径对固定 post_action 目标的委托(见 Task 2 行为保持证明)。
local function _resolve_finished_landing_state(game, player)
  return blocking.next_wait_state(game, "post_action", { player = player }, true, false)
end

local function _resolve_landing_wait_args(res, player, move_result)
  return res.next_state or "landing", res.next_args or { player = player, move_result = move_result }
end

local function _resolve_waiting_landing_result(game, res, player, move_result)
  local next_state, next_args = _resolve_landing_wait_args(res, player, move_result)
  return blocking.next_wait_state(game, next_state, next_args, res.wait_action_anim, res.wait_move_anim)
end

local function _phase_land(turn_mgr, args)
  local player = args.player
  local move_result = args.move_result
  local game = turn_mgr.game
  local tile = game.board:get_tile(player.position)

  local res = settlement.begin_landing_settlement(game, player.id, {
    tile = tile,
    move_result = move_result,
  })
  if res and res.waiting then
    return _resolve_waiting_landing_result(game, res, player, move_result)
  end
  return _resolve_finished_landing_state(game, player)
end

return {
  run = _phase_land,
  _resolve_wait_state = blocking.next_wait_state,
  resolve_wait_state = blocking.next_wait_state,
}

--[[ mutate4lua-manifest
version=4
projectHash=aa1a4dbada98536c
scope.0.id=chunk:src/turn/phases/land.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=40
scope.0.semanticHash=687f5c789d616dd9
scope.1.id=function:_resolve_finished_landing_state
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=8
scope.1.semanticHash=80ca75c2b9043915
scope.2.id=function:_resolve_landing_wait_args
scope.2.kind=function
scope.2.startLine=10
scope.2.endLine=12
scope.2.semanticHash=39c5501c55d04d2b
scope.3.id=function:_resolve_waiting_landing_result
scope.3.kind=function
scope.3.startLine=14
scope.3.endLine=17
scope.3.semanticHash=d0724909f9fab21d
scope.4.id=function:_phase_land
scope.4.kind=function
scope.4.startLine=19
scope.4.endLine=33
scope.4.semanticHash=f411ee8dd55c1e06
]]
