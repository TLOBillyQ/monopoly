local logger = require("src.core.Logger")
local item_phase = require("src.game.systems.items.ItemPhase")
local number_utils = require("src.core.NumberUtils")

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

local function _phase_roll(turn_mgr, args)
  args = args or {}
  local game = turn_mgr.game
  local player = args.player or game:current_player()
  local rolls = args.rolls
  local raw_total = args.raw_total
  local total = args.total

  if not rolls then
    local dice_count = game:player_dice_count(player)
    local override = nil
    if player.status.pending_remote_dice then
      override = player.status.pending_remote_dice.values
    end
    rolls, raw_total = _roll_dice(dice_count, override, game.rng)

    total = raw_total
    if player.status.pending_dice_multiplier and player.status.pending_dice_multiplier > 1 then
      total = total * player.status.pending_dice_multiplier
    end
    logger.event(player.name .. " 投骰: [" .. table.concat(rolls, ",") .. "] => " .. number_utils.format_integer_part(total))
    game.last_turn.rolls = rolls
    game.last_turn.total = total
    game.last_turn.raw_total = raw_total
  end

  local anim_gate_port = assert(game.anim_gate_port, "missing anim_gate_port")
  if not args.skip_anim and anim_gate_port.wait_action_anim then
    game:queue_action_anim({
      kind = "roll",
      player_id = player.id,
      rolls = rolls,
      total = total,
    })
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

  local phase_res = item_phase.run(turn_mgr, "pre_move", {
    player = player,
    next_state = "move",
    next_args = { player = player, total = total, raw_total = raw_total },
  })
  if phase_res and phase_res.waiting then
    local next_state = phase_res.next_state or "move"
    local next_args = phase_res.next_args or { player = player, total = total, raw_total = raw_total }
    if phase_res.wait_action_anim then
      return "wait_action_anim", { next_state = next_state, next_args = next_args }
    end
    return "wait_choice", { next_state = next_state, next_args = next_args }
  end
  return "move", { player = player, total = total, raw_total = raw_total }
end

return _phase_roll
