local movement = require("src.rules.movement")
local dice_multiplier = require("src.turn.phases.dice_multiplier")
local move_followup = require("src.turn.phases.move_followup")
local dirty_tracker = require("src.state.dirty_tracker")

local function _merge_move_args(out, extra)
  if extra == nil then
    return out
  end
  for key, value in pairs(extra) do
    out[key] = value
  end
  return out
end

local function _build_move_args(player, raw_total, extra)
  return _merge_move_args({
    player = player,
    raw_total = raw_total,
  }, extra)
end

local function _build_move_opts(args, raw_total)
  local move_opts = { branch_parity = raw_total }
  if args.continue_from_market then
    move_opts.direction = args.facing
    move_opts.branch_parity = args.branch_parity
    move_opts.entered_inner = args.entered_inner
  end
  return move_opts
end

local function _resolve_move_total(args, raw_total)
  if args.continue_from_market then
    return args.remaining_steps
  end
  return raw_total
end

local function _next_move_anim_seq(turn)
  local seq = (turn.move_anim_seq or 0) + 1
  turn.move_anim_seq = seq
  return seq
end

local function _build_move_anim_data(game, player, start_index, move_result)
  return {
    seq = _next_move_anim_seq(game.turn),
    player_id = player.id,
    from_index = start_index,
    to_index = player.position,
    visited = move_result.visited,
    steps = move_result.steps,
    stopped_on_roadblock = move_result.stopped_on_roadblock == true,
    market_interrupt = move_result.market_interrupt == true,
  }
end

local function _queue_move_anim(game, anim_data)
  game.turn.move_anim = anim_data
  dirty_tracker.mark_turn(game)
end

local function _build_wait_move_anim_result(player, raw_total, move_result)
  return "wait_move_anim", {
    next_state = "move_followup",
    next_args = _build_move_args(player, raw_total, {
      mode = "resume_turn_move",
      move_result = move_result,
      raw_total = raw_total,
    }),
  }
end

local function _run_move_followup(turn_mgr, player, raw_total, move_result)
  return move_followup.run(turn_mgr, {
    mode = "resume_turn_move",
    player = player,
    raw_total = raw_total,
    move_result = move_result,
  })
end

local function _perform_move(turn_mgr, game, player, total, move_opts)
  local start_index = player.position
  local move_result = movement.move(turn_mgr.game, player, total, move_opts)
  local anim_gate_port = assert(game.anim_gate_port, "missing anim_gate_port")
  if anim_gate_port.wait_move_anim == true then
    local anim_data = _build_move_anim_data(game, player, start_index, move_result)
    _queue_move_anim(game, anim_data)
    return _build_wait_move_anim_result(player, move_opts.branch_parity, move_result)
  end
  return _run_move_followup(turn_mgr, player, move_opts.branch_parity, move_result)
end

local function _phase_move(turn_mgr, args)
  local player = args.player
  local raw_total = args.raw_total
  assert(turn_mgr.game ~= nil, "missing game")
  local move_result = args.move_result
  local game = turn_mgr.game

  local total = dice_multiplier.apply_move_total(game, player, args.total, raw_total)
  local move_opts = _build_move_opts(args, raw_total)
  total = _resolve_move_total(args, total)

  if not move_result then
    return _perform_move(turn_mgr, game, player, total, move_opts)
  end

  return _run_move_followup(turn_mgr, player, raw_total, move_result)
end

return _phase_move

--[[ mutate4lua-manifest
version=2
projectHash=53ddbede0184ed0e
scope.0.id=chunk:src/turn/phases/move.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=115
scope.0.semanticHash=d66fc2640589b424
scope.1.id=function:_build_move_args:16
scope.1.kind=function
scope.1.startLine=16
scope.1.endLine=21
scope.1.semanticHash=3604bc5e58804120
scope.2.id=function:_build_move_opts:23
scope.2.kind=function
scope.2.startLine=23
scope.2.endLine=31
scope.2.semanticHash=aae7a4a6f6592d07
scope.3.id=function:_resolve_move_total:33
scope.3.kind=function
scope.3.startLine=33
scope.3.endLine=38
scope.3.semanticHash=66ba717c1a14635a
scope.4.id=function:_next_move_anim_seq:40
scope.4.kind=function
scope.4.startLine=40
scope.4.endLine=44
scope.4.semanticHash=f4a6c4b2434f5790
scope.5.id=function:_build_move_anim_data:46
scope.5.kind=function
scope.5.startLine=46
scope.5.endLine=57
scope.5.semanticHash=6ac5c76546a75016
scope.6.id=function:_queue_move_anim:59
scope.6.kind=function
scope.6.startLine=59
scope.6.endLine=62
scope.6.semanticHash=094b9d43b65516f7
scope.7.id=function:_build_wait_move_anim_result:64
scope.7.kind=function
scope.7.startLine=64
scope.7.endLine=73
scope.7.semanticHash=3199035e040453d3
scope.8.id=function:_run_move_followup:75
scope.8.kind=function
scope.8.startLine=75
scope.8.endLine=82
scope.8.semanticHash=412e0c7a81d6def7
scope.9.id=function:_perform_move:84
scope.9.kind=function
scope.9.startLine=84
scope.9.endLine=94
scope.9.semanticHash=5dba89093d360ff6
scope.10.id=function:_phase_move:96
scope.10.kind=function
scope.10.startLine=96
scope.10.endLine=112
scope.10.semanticHash=255572dee68a9416
]]
