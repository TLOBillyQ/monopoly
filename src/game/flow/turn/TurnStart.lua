local logger = require("src.core.Logger")
local item_phase = require("src.game.systems.items.ItemPhase")

local function _phase_start(turn_mgr)
  local player = turn_mgr.game:current_player()
  local turn = turn_mgr.game.turn
  local tc = turn_mgr.game.turn.turn_count
  local current_index = turn_mgr.game.turn.current_player_index
  logger.info(
    "[Eggy]",
    "回合开始:",
    "current_player_index",
    tostring(current_index),
    "player_id",
    tostring(player.id)
  )
  turn_mgr.game.last_turn = {
    player_id = player.id,
    player_name = player.name,
    skipped = false,
    rolls = nil,
    total = nil,
    move_result = nil,
    note = nil,
  }
  if player.eliminated then
    turn_mgr.game.last_turn.note = "已出局，跳过"
    turn_mgr.game.last_turn.skipped = true
    return "end_turn", { player = player }
  end
  tc = tc + 1
  turn_mgr.game.turn.turn_count = tc
  turn_mgr.game.dirty.turn = true
  turn_mgr.game.dirty.any = true
  if player.status.stay_turns and player.status.stay_turns > 0 then
    turn_mgr.game:set_player_status(player, "stay_turns", player.status.stay_turns - 1)
    logger.event(player.name .. " 被扣留，剩余回合:", player.status.stay_turns)
    turn_mgr.game.last_turn.note = "被扣留"
    turn_mgr.game.last_turn.skipped = true
    turn_mgr.game.last_turn.stay_turns = player.status.stay_turns
    turn.detained_wait_active = true
    turn.detained_wait_elapsed = 0
    turn.detained_wait_seconds = 5
    return "detained_wait", { player = player }
  end

  local phase_res = item_phase.run(turn_mgr, "pre_action", {
    player = player,
    next_state = "roll",
    next_args = { player = player },
  })
  if phase_res and phase_res.waiting then
    local next_state = phase_res.next_state or "roll"
    local next_args = phase_res.next_args or { player = player }
    if phase_res.wait_action_anim then
      return "wait_action_anim", { next_state = next_state, next_args = next_args }
    end
    return "wait_choice", { next_state = next_state, next_args = next_args }
  end

  return "roll", { player = player }
end

return _phase_start
