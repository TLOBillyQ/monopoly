local constants = require("src.config.content.constants")
local runtime_constants = require("src.config.gameplay.runtime_constants")
local logger = require("src.core.utils.logger")
local number_utils = require("src.core.utils.number_utils")
local tick_timeout = require("src.turn.waits.timeout")
local wait_log_once = require("src.turn.waits.log_once")
local runtime_state = require("src.state.runtime_state")
local turn_ui_sync_shared = require("src.core.ui_sync.turn_ui_sync_shared")
local choice_auto_policy = require("src.turn.policies.choice_auto_policy")

local tick_ui_sync = {}

local function _build_log_prefix()
  return "[Eggy]"
end

local function _log_once(state, level, key, ...)
  if level == "warn" then
    wait_log_once.warn(state, key, ...)
  else
    wait_log_once.info(state, key, ...)
  end
end

local function _resolve_detained_countdown(turn)
  local remaining = (turn.detained_wait_seconds or 0) - (turn.detained_wait_elapsed or 0)
  if remaining < 0 then
    remaining = 0
  end
  return true, math.ceil(remaining)
end

local function _resolve_pending_choice_countdown(game, state, gate, timeout, pending_choice)
  local owner = game and choice_auto_policy.resolve_choice_owner(game, pending_choice) or nil
  local owner_auto = false
  if owner ~= nil then
    local auto_play_port = game and game.auto_play_port or nil
    if type(auto_play_port) == "table" and type(auto_play_port.is_auto_player) == "function" then
      local ok, is_auto = pcall(auto_play_port.is_auto_player, game, owner)
      if ok then
        owner_auto = is_auto == true
      end
    else
      owner_auto = owner.auto == true or owner.is_ai == true or owner.ai == true
    end
  end
  local pending_choice_elapsed = runtime_state.get_pending_choice_elapsed(state)
  if pending_choice_elapsed < 0 then
    pending_choice_elapsed = 0
  end
  if gate.choice_active ~= true and gate.market_active ~= true then
    _log_once(
      state,
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
    return _resolve_pending_choice_countdown(game, state, gate, timeout, pending_choice)
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
  _log_once(state, level, key, ...)
end

function tick_ui_sync.update_countdown(game, state)
  local turn = game and game.turn or nil
  if not turn then
    return
  end
  local timeout = tick_timeout.resolve_choice_timeout_seconds(game, state)
  local gate = tick_timeout.resolve_modal_gate(state)
  local active, seconds = _resolve_countdown_state(game, state, turn, timeout, gate)
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
