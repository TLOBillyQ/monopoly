local runtime_constants = require("src.config.gameplay.runtime_constants")
local logger = require("src.foundation.log.logger")
local number_utils = require("src.foundation.lang.number")
local tick_timeout = require("src.turn.waits.timeout")
local runtime_state = require("src.state.runtime_state")
local turn_ui_sync_shared = require("src.state.ui_sync_shared")
local DeadlineService = require("src.turn.deadlines.service")

local tick_ui_sync = {}

local function _build_log_prefix()
  return "[Eggy]"
end

local function _resolve_detained_countdown(turn)
  local remaining = (turn.detained_wait_seconds or 0) - (turn.detained_wait_elapsed or 0)
  if remaining < 0 then
    remaining = 0
  end
  return true, math.ceil(remaining)
end

local function _resolve_pending_choice_countdown(state, gate, timeout, pending_choice)
  local pending_choice_elapsed = runtime_state.get_pending_choice_elapsed(state)
  if pending_choice_elapsed < 0 then
    pending_choice_elapsed = 0
  end
  if gate.choice_active ~= true and gate.market_active ~= true then
    runtime_state.log_once(
      state,
      "info",
      "countdown_runtime_choice_without_ui_" .. tostring(pending_choice.id),
      _build_log_prefix(),
      "countdown driven by runtime pending choice without ui choice screen",
      "choice_id=" .. tostring(pending_choice.id),
      "kind=" .. tostring(pending_choice.kind)
    )
  end
  local remaining = timeout - pending_choice_elapsed
  if remaining < 0 then
    remaining = 0
  end
  return true, math.ceil(remaining)
end

local function _resolve_popup_countdown(game, state)
  local popup_timeout = tick_timeout.resolve_modal_timeout_seconds(game, state)
  if popup_timeout <= 0 then
    return false, 0
  end
  local remaining = popup_timeout - runtime_state.get_modal_elapsed(state)
  if remaining < 0 then
    remaining = 0
  end
  return true, math.ceil(remaining)
end

local function _resolve_action_button_countdown(state, timeout)
  local remaining = timeout - (state.action_button_elapsed or 0)
  if remaining < 0 then
    remaining = 0
  end
  return true, math.ceil(remaining)
end

local function _resolve_countdown_state(game, state, turn, timeout, gate)
  local pending_choice = turn.pending_choice or runtime_state.get_pending_choice(state)
  if turn.detained_wait_active then
    return _resolve_detained_countdown(turn)
  end
  if timeout <= 0 then
    return false, 0
  end
  if pending_choice ~= nil then
    return _resolve_pending_choice_countdown(state, gate, timeout, pending_choice)
  end
  if gate.popup_active == true then
    return _resolve_popup_countdown(game, state)
  end
  if state.action_button_active then
    return _resolve_action_button_countdown(state, timeout)
  end
  return false, 0
end

local function _mark_countdown_dirty(game)
  game.dirty.turn_countdown = true
  game.dirty.any = true
end

function tick_ui_sync.log_status(view)
  assert(view ~= nil, "missing view")
  logger.info(
    _build_log_prefix(),
    "玩家:",
    tostring(view.current_player_name),
    "现金:",
    number_utils.format_integer_part(view.current_player_cash)
  )
end

function tick_ui_sync.log_prefix()
  return _build_log_prefix()
end

function tick_ui_sync.log_once(state, level, key, ...)
  runtime_state.log_once(state, level, key, ...)
end

local function _resolve_deadline_countdown(state)
  local primary = DeadlineService.peek(state, "primary")
  if primary == nil then
    return nil, nil, nil
  end
  return true, math.ceil(primary.remaining_seconds or 0), primary.level
end

function tick_ui_sync.update_countdown(game, state)
  local turn = game and game.turn or nil
  if not turn then
    return
  end
  local timeout = tick_timeout.resolve_choice_timeout_seconds(game, state)
  local gate = tick_timeout.resolve_modal_gate(state)
  local active, seconds, level = _resolve_deadline_countdown(state)
  if active == nil then
    active, seconds = _resolve_countdown_state(game, state, turn, timeout, gate)
  end
  if seconds ~= state.countdown_last then
    state.countdown_last = seconds
    turn.countdown_seconds = seconds
    _mark_countdown_dirty(game)
  end
  if active ~= state.countdown_active_last then
    state.countdown_active_last = active
    turn.countdown_active = active
    _mark_countdown_dirty(game)
  end
  if level ~= state.countdown_warn_level_last then
    state.countdown_warn_level_last = level
    turn.countdown_warn_level = level
    _mark_countdown_dirty(game)
  end
end

function tick_ui_sync.build_ui_env(state, game)
  return turn_ui_sync_shared.build_ui_env(state, game)
end

function tick_ui_sync.runtime_constants()
  return runtime_constants
end

function tick_ui_sync.is_only_turn_countdown(dirty)
  return turn_ui_sync_shared.is_only_turn_countdown(dirty)
end

return tick_ui_sync
