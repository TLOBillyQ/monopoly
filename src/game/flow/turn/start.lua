local logger = require("src.core.utils.logger")
local item_phase = require("src.game.systems.items.phase")
local item_auto_play_context = require("src.game.flow.turn.item_auto_play_context")
local monopoly_event = require("src.core.events.monopoly_events")
local gameplay_rules = require("src.core.config.gameplay_rules")

local function _clear_no_action_notice(turn)
  if not turn then
    return
  end
  turn.no_action_notice_active = false
  turn.no_action_notice_player_id = nil
  turn.no_action_notice_text = nil
end

local function _phase_start(turn_mgr)
  local player = turn_mgr.game:current_player()
  local turn = turn_mgr.game.turn
  _clear_no_action_notice(turn)
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
  monopoly_event.emit(monopoly_event.feedback.turn_started, {
    player = player,
    player_id = player.id,
    turn_count = tc,
  })
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
    local detained_wait_seconds = gameplay_rules.detained_turn_wait_seconds or 5.0
    turn_mgr.game:set_player_status(player, "stay_turns", player.status.stay_turns - 1)
    logger.event(player.name .. " 被扣留，剩余回合:", player.status.stay_turns)
    turn_mgr.game.last_turn.note = "被扣留"
    turn_mgr.game.last_turn.skipped = true
    turn_mgr.game.last_turn.stay_turns = player.status.stay_turns
    turn.detained_wait_active = detained_wait_seconds > 0
    turn.detained_wait_elapsed = 0
    turn.detained_wait_seconds = detained_wait_seconds
    turn.no_action_notice_active = true
    turn.no_action_notice_player_id = player.id
    turn.no_action_notice_text = "本回合无法行动"
    if detained_wait_seconds <= 0 then
      return "end_turn", { player = player }
    end
    return "detained_wait", { player = player }
  end

  local phase_res = item_phase.run(turn_mgr, "pre_action", {
    player = player,
    auto_play = item_auto_play_context.build(turn_mgr.game, player),
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
