local ItemService = require("src.gameplay.services.item_service")
local logger = require("src.gameplay.services.logger")

local function phase_start(tm)
  local player = tm.game:current_player()
  tm.game.turn_count = (tm.game.turn_count or 0) + 1
  tm.game.last_turn = {
    player_id = player.id,
    player_name = player.name,
    skipped = false,
    rolls = nil,
    total = nil,
    move_result = nil,
    note = nil,
  }
  if player.eliminated then
    tm.game.last_turn.note = "已出局，跳过"
    tm.game.last_turn.skipped = true
    tm:next_player()
    return nil
  end
  if player.status.stay_turns and player.status.stay_turns > 0 then
    player.status.stay_turns = player.status.stay_turns - 1
    logger.event(player.name .. " 被扣留，剩余回合:", player.status.stay_turns)
    tm.game.last_turn.note = "被扣留"
    tm.game.last_turn.skipped = true
    tm.game.last_turn.stay_turns = player.status.stay_turns
    tm:end_turn(player)
    return nil
  end
  ItemService.auto_pre_action(tm.game, player)
  return "roll", { player = player }
end

return phase_start
