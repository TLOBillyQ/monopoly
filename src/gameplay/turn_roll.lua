local Dice = require("src.core.dice")
local logger = require("src.util.logger")
local Choice = require("src.gameplay.choice")
local Inventory = require("src.gameplay.item_inventory")

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
  tm.game.last_turn.raw_total = raw_total

  local has_double = Inventory.find_index(player, 2003) ~= nil
  local can_prompt = has_double and (not player.status.pending_dice_multiplier or player.status.pending_dice_multiplier <= 1)
  if can_prompt then
    tm.game.last_turn.total = raw_total
    Choice.open(tm.game, {
      kind = "dice_double_prompt",
      title = "是否使用骰子加倍卡",
      body_lines = { "本次步数翻倍" },
      options = {
        { id = "use", label = "使用" },
        { id = "skip", label = "放弃" },
      },
      allow_cancel = false,
      meta = { player_id = player.id },
    })
    return "wait_choice", { resume_state = "move", resume_args = { player = player, raw_total = raw_total } }
  end

  tm.game.last_turn.total = total
  return "move", { player = player, total = total, raw_total = raw_total }
end

return phase_roll
