local dice_multiplier = require("src.turn.phases.dice_multiplier")
local event_kinds = require("src.config.gameplay.event_kinds")
local event_feed = require("src.rules.ports.event_feed")
local phase_wait = require("src.turn.phases.phase_wait")

local function _roll_dice(count, override_values, rng)
  local results = {}
  local total = 0
  if override_values and #override_values > 0 then
    for i = 1, count do
      local v = override_values[i] or override_values[#override_values]
      table.insert(results, v)
      total = total + v
    end
    return results, total
  end
  assert(rng and rng.next_int, "Dice.Roll requires rng")
  for _ = 1, count do
    local v = rng:next_int(1, 6)
    table.insert(results, v)
    total = total + v
  end
  return results, total
end

local function _resolve_dice_override(game, player)
  return game:peek_pending_remote_dice(player)
end

local function _log_roll_event(game, player, rolls, total)
  event_feed.publish(game, {
    kind = event_kinds.dice_roll,
    text = player.name .. " 投骰: [" .. table.concat(rolls, ",") .. "] => " .. tostring(total),
    tip = true,
  })
end

local function _store_roll_results(game, rolls, total, raw_total)
  game.last_turn.rolls = rolls
  game.last_turn.total = total
  game.last_turn.raw_total = raw_total
end

local function _perform_dice_roll(game, player)
  local dice_count = game:player_dice_count(player)
  local override = _resolve_dice_override(game, player)
  local rolls, raw_total = _roll_dice(dice_count, override, game.rng)
  local total = dice_multiplier.apply_roll_total(game, raw_total, player)
  _log_roll_event(game, player, rolls, total)
  _store_roll_results(game, rolls, total, raw_total)
  return rolls, raw_total, total
end

local function _should_wait_for_anim(game, skip_anim)
  if skip_anim then
    return false
  end
  local anim_gate_port = game.anim_gate_port
  return anim_gate_port and anim_gate_port.wait_action_anim or false
end

local function _build_anim_wait_result(player, rolls, raw_total, total)
  return "wait_action_anim", {
    next_state = "roll",
    next_args = {
      player = player,
      rolls = rolls,
      raw_total = raw_total,
      total = total,
      skip_anim = true,
    },
  }
end

local function _resolve_phase_wait_result(phase_res, player, total, raw_total)
  return phase_wait.resolve_result(phase_res, "move", player, total, raw_total)
end

local function _queue_roll_anim(game, player, rolls, total)
  game:queue_action_anim({
    kind = "roll",
    player_id = player.id,
    rolls = rolls,
    total = total,
  })
end

local function _phase_roll(turn_mgr, args)
  args = args or {}
  local game = turn_mgr.game
  local player = args.player or game:current_player()
  local rolls = args.rolls
  local raw_total = args.raw_total
  local total = args.total

  if not rolls then
    rolls, raw_total, total = _perform_dice_roll(game, player)
  end

  assert(game.anim_gate_port, "missing anim_gate_port")
  if _should_wait_for_anim(game, args.skip_anim) then
    _queue_roll_anim(game, player, rolls, total)
    return _build_anim_wait_result(player, rolls, raw_total, total)
  end

  return "pre_move", { player = player, total = total, raw_total = raw_total }
end

local function _phase_roll_direct(turn_mgr, args)
  local next_state, next_args = _phase_roll(turn_mgr, args)
  if next_state == "pre_move" then
    return "move", next_args
  end
  return next_state, next_args
end

local roll = {}
roll._roll_dice = _roll_dice
roll._phase_roll = _phase_roll_direct
roll._phase_roll_with_pre_move = _phase_roll
roll._resolve_phase_wait_result = _resolve_phase_wait_result
return roll

--[[ mutate4lua-manifest
version=2
projectHash=412f72b404d797d5
scope.0.id=chunk:src/turn/phases/roll.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=123
scope.0.semanticHash=a760234e3a005e77
scope.1.id=function:_resolve_dice_override:26
scope.1.kind=function
scope.1.startLine=26
scope.1.endLine=28
scope.1.semanticHash=6c6c03f1cc5c4baa
scope.2.id=function:_log_roll_event:30
scope.2.kind=function
scope.2.startLine=30
scope.2.endLine=36
scope.2.semanticHash=37124d3b08f36842
scope.3.id=function:_store_roll_results:38
scope.3.kind=function
scope.3.startLine=38
scope.3.endLine=42
scope.3.semanticHash=1833f7dbe12182e0
scope.4.id=function:_perform_dice_roll:44
scope.4.kind=function
scope.4.startLine=44
scope.4.endLine=52
scope.4.semanticHash=53c3ceb3a9b5afa5
scope.5.id=function:_should_wait_for_anim:54
scope.5.kind=function
scope.5.startLine=54
scope.5.endLine=60
scope.5.semanticHash=7b2a8d406e61a2a8
scope.6.id=function:_build_anim_wait_result:62
scope.6.kind=function
scope.6.startLine=62
scope.6.endLine=73
scope.6.semanticHash=6a1674e1a8af7237
scope.7.id=function:_resolve_phase_wait_result:75
scope.7.kind=function
scope.7.startLine=75
scope.7.endLine=77
scope.7.semanticHash=f519099868176db9
scope.8.id=function:_queue_roll_anim:79
scope.8.kind=function
scope.8.startLine=79
scope.8.endLine=86
scope.8.semanticHash=bc5aea10f274bc75
scope.9.id=function:_phase_roll:88
scope.9.kind=function
scope.9.startLine=88
scope.9.endLine=107
scope.9.semanticHash=f67872448dc4430c
scope.10.id=function:_phase_roll_direct:109
scope.10.kind=function
scope.10.startLine=109
scope.10.endLine=115
scope.10.semanticHash=efbee038bc9905b5
]]
