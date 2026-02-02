local Dice = require("Components.Dice")
local Logger = require("Components.Logger")
local ItemPhase = require("Manager.ItemManager.ItemPhase")

local function phase_roll(tm, args)
  args = args or {}
  local game = tm.game
  local player = args.player or game:current_player()
  local rolls = args.rolls
  local raw_total = args.raw_total
  local total = args.total

  if not rolls then
    local dice_count = player:dice_count()
    local override = nil
    if player.status.pending_remote_dice then
      override = player.status.pending_remote_dice.values
    end
    rolls, raw_total = Dice.roll(dice_count, override, game.rng)

    total = raw_total
    if player.status.pending_dice_multiplier and player.status.pending_dice_multiplier > 1 then
      total = total * player.status.pending_dice_multiplier
    end
    Logger.event(player.name .. " 投骰: [" .. table.concat(rolls, ",") .. "] => " .. total)
    game.last_turn.rolls = rolls
    game.last_turn.total = total
    game.last_turn.raw_total = raw_total
  end

  local ui_port = assert(game.ui_port, "missing ui_port")
  if not args.skip_anim and ui_port.wait_action_anim then
    game:queue_action_anim({
      kind = "roll",
      player_id = player.id,
      rolls = rolls,
      total = total,
    })
    return "wait_action_anim", {
      resume_state = "roll",
      resume_args = {
        player = player,
        rolls = rolls,
        raw_total = raw_total,
        total = total,
        skip_anim = true,
      },
    }
  end

  local phase_res = ItemPhase.run(tm, "pre_move", {
    player = player,
    resume_state = "move",
    resume_args = { player = player, total = total, raw_total = raw_total },
  })
  if phase_res and phase_res.waiting then
    local resume_state = phase_res.resume_state or "move"
    local resume_args = phase_res.resume_args or { player = player, total = total, raw_total = raw_total }
    if phase_res.wait_action_anim then
      return "wait_action_anim", { resume_state = resume_state, resume_args = resume_args }
    end
    return "wait_choice", { resume_state = resume_state, resume_args = resume_args }
  end
  return "move", { player = player, total = total, raw_total = raw_total }
end

return phase_roll


