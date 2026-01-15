local Dice = require("src.core.dice")
local logger = require("src.util.logger")

local function phase_roll(tm, args)
  local player = args.player or tm.game:current_player()
  local dice_count = player:dice_count()
  local override = nil
  if player.status.pending_remote_dice then
    override = player.status.pending_remote_dice.values
  end
  local rolls, raw_total = Dice.roll(dice_count, override, tm.game.rng)

  local total = raw_total
  if player.status.pending_dice_multiplier and player.status.pending_dice_multiplier > 1 then
    total = total * player.status.pending_dice_multiplier
  end
  logger.event(player.name .. " 投骰: [" .. table.concat(rolls, ",") .. "] => " .. total)
  tm.game.last_turn.rolls = rolls
  tm.game.last_turn.total = total
  tm.game.last_turn.raw_total = raw_total
  return "move", { player = player, total = total, raw_total = raw_total }
end

return phase_roll
