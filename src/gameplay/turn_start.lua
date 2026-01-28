local logger = require("src.util.logger")
local ItemPhase = require("src.gameplay.item_phase")

local function phase_start(tm)
  local player = tm.game:current_player()
  local tc = tm.game.store:get({ "turn", "turn_count" })
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
  tc = tc + 1
  if tm.game.store then
    tm.game.store:set({ "turn", "turn_count" }, tc)
  end
  if player.status.stay_turns and player.status.stay_turns > 0 then
    tm.game:set_player_status(player, "stay_turns", player.status.stay_turns - 1)
    logger.event(player.name .. " 被扣留，剩余回合:", player.status.stay_turns)
    tm.game.last_turn.note = "被扣留"
    tm.game.last_turn.skipped = true
    tm.game.last_turn.stay_turns = player.status.stay_turns
    return "end_turn", { player = player }
  end

  local phase_res = ItemPhase.run(tm, "pre_action", {
    player = player,
    resume_state = "roll",
    resume_args = { player = player },
  })
  if phase_res and phase_res.waiting then
    local resume_state = phase_res.resume_state or "roll"
    local resume_args = phase_res.resume_args or { player = player }
    if phase_res.wait_action_anim then
      return "wait_action_anim", { resume_state = resume_state, resume_args = resume_args }
    end
    return "wait_choice", { resume_state = resume_state, resume_args = resume_args }
  end

  return "roll", { player = player }
end

return phase_start
