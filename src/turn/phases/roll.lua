local dice_multiplier = require("src.turn.phases.dice_multiplier")
local event_kinds = require("src.config.gameplay.event_kinds")
local event_feed = require("src.rules.ports.event_feed")
local phase_wait = require("src.turn.phases.phase_wait")

-- 覆盖值不足 count 时，末位值重复填满。
local function _roll_from_override(count, override_values)
  local results = {}
  local total = 0
  for i = 1, count do
    local v = override_values[i] or override_values[#override_values]
    table.insert(results, v)
    total = total + v
  end
  return results, total
end

local function _roll_from_rng(count, rng)
  assert(rng and rng.next_int, "Dice.Roll requires rng")
  local results = {}
  local total = 0
  for _ = 1, count do
    local v = rng:next_int(1, 6)
    table.insert(results, v)
    total = total + v
  end
  return results, total
end

local function _roll_dice(count, override_values, rng)
  if override_values and #override_values > 0 then
    return _roll_from_override(count, override_values)
  end
  return _roll_from_rng(count, rng)
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
version=4
projectHash=6a5ce408c2c2f838
scope.0.id=chunk:src/turn/phases/roll.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=134
scope.0.semanticHash=08a66a18265fd558
scope.1.id=function:_roll_from_override
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=16
scope.1.semanticHash=f99d02d2f0e78028
scope.2.id=function:_roll_from_rng
scope.2.kind=function
scope.2.startLine=18
scope.2.endLine=28
scope.2.semanticHash=6edbfae5a9c6dc8f
scope.3.id=function:_roll_dice
scope.3.kind=function
scope.3.startLine=30
scope.3.endLine=35
scope.3.semanticHash=3e9ab611fbbd20d2
scope.4.id=function:_resolve_dice_override
scope.4.kind=function
scope.4.startLine=37
scope.4.endLine=39
scope.4.semanticHash=8cbdcb158f83ad60
scope.5.id=function:_log_roll_event
scope.5.kind=function
scope.5.startLine=41
scope.5.endLine=47
scope.5.semanticHash=d044e30c87c17cd2
scope.6.id=function:_store_roll_results
scope.6.kind=function
scope.6.startLine=49
scope.6.endLine=53
scope.6.semanticHash=8e7d1afc6374a405
scope.7.id=function:_perform_dice_roll
scope.7.kind=function
scope.7.startLine=55
scope.7.endLine=63
scope.7.semanticHash=518f17904d8b7353
scope.8.id=function:_should_wait_for_anim
scope.8.kind=function
scope.8.startLine=65
scope.8.endLine=71
scope.8.semanticHash=2f1eceff9983c7a0
scope.9.id=function:_build_anim_wait_result
scope.9.kind=function
scope.9.startLine=73
scope.9.endLine=84
scope.9.semanticHash=fc56cdf7d0d7c661
scope.10.id=function:_resolve_phase_wait_result
scope.10.kind=function
scope.10.startLine=86
scope.10.endLine=88
scope.10.semanticHash=406bfcaa2a0f654b
scope.11.id=function:_queue_roll_anim
scope.11.kind=function
scope.11.startLine=90
scope.11.endLine=97
scope.11.semanticHash=4d2f943125f29175
scope.12.id=function:_phase_roll
scope.12.kind=function
scope.12.startLine=99
scope.12.endLine=118
scope.12.semanticHash=b9399386ba270ba0
scope.13.id=function:_phase_roll_direct
scope.13.kind=function
scope.13.startLine=120
scope.13.endLine=126
scope.13.semanticHash=66f226816b076160
]]
