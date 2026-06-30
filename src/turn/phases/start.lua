local logger = require("src.foundation.log")
local item_phase = require("src.rules.items.phase")
local item_auto_play_context = require("src.turn.policies.item_play_context")
local monopoly_event = require("src.foundation.events")
local timing = require("src.config.gameplay.timing")
local event_kinds = require("src.config.gameplay.event_kinds")
local event_feed = require("src.rules.ports.event_feed")
local dirty_tracker = require("src.state.dirty_tracker")

local function _clear_no_action_notice(turn)
  if not turn then
    return
  end
  turn.no_action_notice_active = false
  turn.no_action_notice_player_id = nil
  turn.no_action_notice_text = nil
end

local function _set_last_turn(game, player)
  game.last_turn = {
    player_id = player.id,
    player_name = player.name,
    skipped = false,
    rolls = nil,
    total = nil,
    move_result = nil,
    note = nil,
  }
end

local function _emit_turn_started(player, turn_count)
  monopoly_event.emit(monopoly_event.feedback.turn_started, {
    player = player,
    player_id = player.id,
    turn_count = turn_count,
  })
end

local function _increment_own_turn_started_count(game, player)
  local status = player and player.status or nil
  local current = status and status.own_turn_started_count or 0
  game:set_player_status(player, "own_turn_started_count", current + 1)
end

local function _skip_eliminated_player(game, player)
  if not player.eliminated then
    return nil
  end
  game.last_turn.note = "已出局，跳过"
  game.last_turn.skipped = true
  return "end_turn", { player = player }
end


local function _configure_detained_wait(game, turn, player)
  local detained_wait_seconds = timing.detained_turn_wait_seconds or 5.0
  -- 扣留剩余回合 uses the 含当前回合 (inclusive) convention (ADR 0024): the player-visible
  -- count includes the current frozen turn, so the tip reads the value BEFORE this turn's
  -- decrement and never shows 0 while detained. The internal stay_turns counter still
  -- decrements at turn start (pinned by the 减后回合 acceptance scenario).
  local remaining_inclusive = player.status.stay_turns
  game:set_player_status(player, "stay_turns", remaining_inclusive - 1)
  event_feed.publish(game, {
    kind = event_kinds.detained,
    text = player.name .. " 被扣留，剩余回合:" .. tostring(remaining_inclusive),
    tip = true,
  })
  game.last_turn.note = "被扣留"
  game.last_turn.skipped = true
  game.last_turn.stay_turns = player.status.stay_turns
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

local function _run_pre_action_item_phase(turn_mgr, player)
  local phase_res = item_phase.run(turn_mgr, "pre_action", {
    player = player,
    auto_play = item_auto_play_context.build(turn_mgr.game, player),
    next_state = "roll",
    next_args = { player = player },
  })
  if not (phase_res and phase_res.waiting) then
    return nil
  end
  local next_state = phase_res.next_state or "roll"
  local next_args = phase_res.next_args or { player = player }
  if phase_res.wait_action_anim then
    return "wait_action_anim", { next_state = next_state, next_args = next_args }
  end
  return "wait_choice", { next_state = next_state, next_args = next_args }
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
  _set_last_turn(turn_mgr.game, player)
  _increment_own_turn_started_count(turn_mgr.game, player)
  _emit_turn_started(player, tc)
  local eliminated_state, eliminated_args = _skip_eliminated_player(turn_mgr.game, player)
  if eliminated_state ~= nil then
    return eliminated_state, eliminated_args
  end
  tc = tc + 1
  turn_mgr.game.turn.turn_count = tc
  dirty_tracker.mark(turn_mgr.game.dirty, "turn")
  if player.status.stay_turns and player.status.stay_turns > 0 then
    return _configure_detained_wait(turn_mgr.game, turn, player)
  end

  local waiting_state, waiting_args = _run_pre_action_item_phase(turn_mgr, player)
  if waiting_state ~= nil then
    return "wait_action", { player = player, next_state = waiting_state, next_args = waiting_args }
  end

  return "wait_action", { player = player, next_state = "roll", next_args = { player = player } }
end

return _phase_start

--[[ mutate4lua-manifest
version=2
projectHash=10c84f19d46a15d5
scope.0.id=chunk:src/turn/phases/start.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=138
scope.0.semanticHash=f0c8663d9989e731
scope.1.id=function:_clear_no_action_notice:10
scope.1.kind=function
scope.1.startLine=10
scope.1.endLine=17
scope.1.semanticHash=5f098d1d9782a95a
scope.2.id=function:_set_last_turn:19
scope.2.kind=function
scope.2.startLine=19
scope.2.endLine=29
scope.2.semanticHash=643cbaa2541ea45c
scope.3.id=function:_emit_turn_started:31
scope.3.kind=function
scope.3.startLine=31
scope.3.endLine=37
scope.3.semanticHash=8007c5ab6dced2c5
scope.4.id=function:_increment_own_turn_started_count:39
scope.4.kind=function
scope.4.startLine=39
scope.4.endLine=43
scope.4.semanticHash=c7e49a15f711ba91
scope.5.id=function:_skip_eliminated_player:45
scope.5.kind=function
scope.5.startLine=45
scope.5.endLine=52
scope.5.semanticHash=c928ce11a107954e
scope.6.id=function:_configure_detained_wait:55
scope.6.kind=function
scope.6.startLine=55
scope.6.endLine=81
scope.6.semanticHash=bfd7e1ad14d2cf0d
scope.7.id=function:_run_pre_action_item_phase:83
scope.7.kind=function
scope.7.startLine=83
scope.7.endLine=99
scope.7.semanticHash=7b585307a93cb0bc
scope.8.id=function:_phase_start:101
scope.8.kind=function
scope.8.startLine=101
scope.8.endLine=135
scope.8.semanticHash=76e428b983c6dc1b
]]
