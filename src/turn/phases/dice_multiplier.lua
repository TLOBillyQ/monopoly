local dice_multiplier = {}

local function _resolve_pending_multiplier(player)
  local pending_multiplier = player.status.pending_dice_multiplier
  if not pending_multiplier or pending_multiplier <= 1 then
    return 1
  end
  return pending_multiplier
end

function dice_multiplier.apply_roll_total(raw_total, player)
  local pending_multiplier = _resolve_pending_multiplier(player)
  if pending_multiplier <= 1 then
    return raw_total
  end
  return raw_total * pending_multiplier
end

function dice_multiplier.apply_move_total(game, player, total, raw_total)
  local pending_multiplier = _resolve_pending_multiplier(player)
  if pending_multiplier <= 1 or raw_total == nil or total ~= raw_total then
    return total
  end

  local new_total = raw_total * pending_multiplier
  if game.set_player_status then
    game:set_player_status(player, "pending_dice_multiplier", 1)
  else
    player.status.pending_dice_multiplier = 1
  end
  if game.last_turn then
    game.last_turn.total = new_total
  end
  return new_total
end

return dice_multiplier
