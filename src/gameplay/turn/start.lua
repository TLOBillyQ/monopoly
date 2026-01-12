local logger = require("src.util.logger")

local function get_service(game, key)
  return game and game.services and game.services[key]
end

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
    return "end_turn", { player = player }
  end
  if player.status.stay_turns and player.status.stay_turns > 0 then
    player.status.stay_turns = player.status.stay_turns - 1
    logger.event(player.name .. " 被扣留，剩余回合:", player.status.stay_turns)
    tm.game.last_turn.note = "被扣留"
    tm.game.last_turn.skipped = true
    tm.game.last_turn.stay_turns = player.status.stay_turns
    return "end_turn", { player = player }
  end
  local item = get_service(tm.game, "item")
  if item and item.auto_pre_action then
    local pre = item.auto_pre_action(tm.game, player)
    if pre and pre.waiting then
      return "wait_choice", { resume_state = "roll", resume_args = { player = player } }
    end
  else
    logger.warn("缺少 ItemService，跳过回合前自动道具")
  end
  return "roll", { player = player }
end

return phase_start
