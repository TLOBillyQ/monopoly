local constants = require("Config.Generated.Constants")
local runtime_constants = require("Config.RuntimeConstants")
local logger = require("src.core.Logger")
local number_utils = require("src.core.NumberUtils")
local tick_timeout = require("src.game.flow.turn.TickTimeout")
local runtime_state = require("src.core.RuntimeState")

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
  local timeout = constants.action_timeout_seconds or 0
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
    if state.pending_choice and state.pending_choice_elapsed then
      active = true
      local remaining = timeout - state.pending_choice_elapsed
      if remaining < 0 then
        remaining = 0
      end
      seconds = math.ceil(remaining)
    elseif state.ui and state.ui.popup_active then
      local popup_timeout = tick_timeout.resolve_modal_timeout_seconds(game, state)
      if popup_timeout > 0 then
        active = true
        local remaining = popup_timeout - (state.ui_modal_elapsed or 0)
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

local function _is_only_turn_countdown(dirty)
  if not dirty or dirty.turn_countdown ~= true then
    return false
  end
  if dirty.players or dirty.board_tiles or dirty.turn or dirty.market or dirty.ui then
    return false
  end
  if dirty.inventory_ids then
    for _ in pairs(dirty.inventory_ids) do
      return false
    end
  end
  return true
end

local function _build_ui_env(state, game)
  local winner = game.winner
  local winner_name = game.winner_names or (winner and assert(winner.name, "missing winner name"))
  return {
    game = game,
    ui_state = state,
    last_turn = game.last_turn,
    finished = game.finished,
    winner_name = winner_name,
  }
end

function tick_ui_sync.build_ui_env(state, game)
  return _build_ui_env(state, game)
end

function tick_ui_sync.runtime_constants()
  return runtime_constants
end

function tick_ui_sync.is_only_turn_countdown(dirty)
  return _is_only_turn_countdown(dirty)
end

return tick_ui_sync
