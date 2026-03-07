local constants = require("Config.Generated.Constants")
local runtime_constants = require("src.core.config.RuntimeConstants")
local logger = require("src.core.utils.Logger")
local number_utils = require("src.core.utils.NumberUtils")
local tick_timeout = require("src.game.flow.turn.TickTimeout")
local runtime_state = require("src.core.runtime_facade.RuntimeState")
local turn_ui_sync_shared = require("src.core.ports.TurnUISyncShared")

local tick_ui_sync = {}

local function _build_log_prefix()
  return "[Eggy]"
end

local function _log_once(state, level, key, ...)
  assert(state ~= nil, "missing state")
  local debug_runtime = runtime_state.ensure_debug_runtime(state)
  assert(debug_runtime.log_once ~= nil, "missing state.debug_runtime.log_once")
  if debug_runtime.log_once[key] then
    return
  end
  debug_runtime.log_once[key] = true
  if level == "warn" then
    logger.warn(...)
  else
    logger.info(...)
  end
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
  local timeout = tick_timeout.resolve_choice_timeout_seconds(game, state)
  local seconds = 0
  local active = false
  if game.turn and game.turn.detained_wait_active then
    active = true
    local turn = game.turn
    local remaining = (turn.detained_wait_seconds or 0) - (turn.detained_wait_elapsed or 0)
    if remaining < 0 then
      remaining = 0
    end
    seconds = math.ceil(remaining)
  elseif timeout > 0 then
    local pending_choice = runtime_state.get_pending_choice(state)
    local pending_choice_elapsed = runtime_state.get_pending_choice_elapsed(state)
    if pending_choice and pending_choice_elapsed then
      active = true
      local remaining = timeout - pending_choice_elapsed
      if remaining < 0 then
        remaining = 0
      end
      seconds = math.ceil(remaining)
    elseif tick_timeout.resolve_modal_gate(state).popup_active == true then
      local popup_timeout = tick_timeout.resolve_modal_timeout_seconds(game, state)
      if popup_timeout > 0 then
        active = true
        local remaining = popup_timeout - runtime_state.get_modal_elapsed(state)
        if remaining < 0 then
          remaining = 0
        end
        seconds = math.ceil(remaining)
      end
    elseif state.action_button_active then
      active = true
      local remaining = timeout - (state.action_button_elapsed or 0)
      if remaining < 0 then
        remaining = 0
      end
      seconds = math.ceil(remaining)
    end
  end
  if seconds ~= state.countdown_last then
    state.countdown_last = seconds
    game.turn.countdown_seconds = seconds
    game.dirty.turn_countdown = true
    game.dirty.any = true
  end
  if active ~= state.countdown_active_last then
    state.countdown_active_last = active
    game.turn.countdown_active = active
    game.dirty.turn_countdown = true
    game.dirty.any = true
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
