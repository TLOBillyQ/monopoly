local logger = require("src.core.utils.logger")
local item_phase = require("src.game.systems.items.phase")
local item_auto_play_context = require("src.game.flow.turn.item_auto_play_context")
local number_utils = require("src.core.utils.number_utils")

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

local function _resolve_dice_override(player)
  if player.status.pending_remote_dice then
    return player.status.pending_remote_dice.values
  end
  return nil
end

local function _apply_dice_multiplier(raw_total, player)
  local total = raw_total
  if player.status.pending_dice_multiplier and player.status.pending_dice_multiplier > 1 then
    total = total * player.status.pending_dice_multiplier
  end
  return total
end

local function _log_roll_event(player, rolls, total)
  logger.event(player.name .. " 投骰: [" .. table.concat(rolls, ",") .. "] => " .. number_utils.format_integer_part(total))
end

local function _store_roll_results(game, rolls, total, raw_total)
  game.last_turn.rolls = rolls
  game.last_turn.total = total
  game.last_turn.raw_total = raw_total
end

local function _perform_dice_roll(game, player)
  local dice_count = game:player_dice_count(player)
  local override = _resolve_dice_override(player)
  local rolls, raw_total = _roll_dice(dice_count, override, game.rng)
  local total = _apply_dice_multiplier(raw_total, player)
  _log_roll_event(player, rolls, total)
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

local function _queue_roll_anim(game, player, rolls, total)
  game:queue_action_anim({
    kind = "roll",
    player_id = player.id,
    rolls = rolls,
    total = total,
  })
end

local function _resolve_phase_wait_result(phase_res, player, total, raw_total)
  local next_state = phase_res.next_state or "move"
  local next_args = phase_res.next_args or { player = player, total = total, raw_total = raw_total }
  if phase_res.wait_action_anim then
    return "wait_action_anim", { next_state = next_state, next_args = next_args }
  end
  return "wait_choice", { next_state = next_state, next_args = next_args }
end

local function _run_pre_move_phase(turn_mgr, game, player, total, raw_total)
  return item_phase.run(turn_mgr, "pre_move", {
    player = player,
    auto_play = item_auto_play_context.build(game, player),
    next_state = "move",
    next_args = { player = player, total = total, raw_total = raw_total },
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

  local phase_res = _run_pre_move_phase(turn_mgr, game, player, total, raw_total)
  if phase_res and phase_res.waiting then
    return _resolve_phase_wait_result(phase_res, player, total, raw_total)
  end
  return "move", { player = player, total = total, raw_total = raw_total }
end

local roll = {}
roll._roll_dice = _roll_dice
roll._phase_roll = _phase_roll

return roll
