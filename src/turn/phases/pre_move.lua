local item_phase = require("src.rules.items.phase")
local item_auto_play_context = require("src.turn.policies.item_play_context")
local dice_multiplier = require("src.turn.phases.dice_multiplier")
local phase_wait = require("src.turn.phases.phase_wait")

local function _resolve_phase_wait_result(phase_res, player, total, raw_total)
  return phase_wait.resolve_result(phase_res, "pre_move", player, total, raw_total)
end

local function _run_pre_move_item_phase(turn_mgr, player, total, raw_total)
  local phase_res = item_phase.run(turn_mgr, "pre_move", {
    player = player,
    auto_play = item_auto_play_context.build(turn_mgr.game, player),
    next_state = "pre_move",
    next_args = {
      player = player,
      total = total,
      raw_total = raw_total,
    },
  })
  if not (phase_res and phase_res.waiting) then
    return nil
  end
  return _resolve_phase_wait_result(phase_res, player, total, raw_total)
end

local function _phase_pre_move(turn_mgr, args)
  args = args or {}
  local game = turn_mgr.game
  local player = args.player or game:current_player()
  local raw_total = args.raw_total
  local total = args.total

  local waiting_state, waiting_args = _run_pre_move_item_phase(turn_mgr, player, total, raw_total)
  if waiting_state ~= nil then
    return waiting_state, waiting_args
  end

  local last_turn = assert(game.last_turn, "missing game.last_turn")
  local updated_total = dice_multiplier.apply_roll_total(assert(last_turn.raw_total, "missing game.last_turn.raw_total"), player)
  last_turn.total = updated_total
  return "move", { player = player, total = updated_total, raw_total = raw_total }
end

return _phase_pre_move

--[[ mutate4lua-manifest
version=2
projectHash=ca0af502e8c15dd6
scope.0.id=chunk:src/turn/phases/pre_move.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=46
scope.0.semanticHash=49e7598f62c3fcd5
scope.1.id=function:_resolve_phase_wait_result:6
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=8
scope.1.semanticHash=9fb1978e8ea473b3
scope.2.id=function:_run_pre_move_item_phase:10
scope.2.kind=function
scope.2.startLine=10
scope.2.endLine=25
scope.2.semanticHash=029855d9395584c5
scope.3.id=function:_phase_pre_move:27
scope.3.kind=function
scope.3.startLine=27
scope.3.endLine=43
scope.3.semanticHash=3b7677524b9a0430
]]
