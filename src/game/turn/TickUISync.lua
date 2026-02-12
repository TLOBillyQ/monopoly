local constants = require("Config.Generated.Constants")
local gameplay_rules = require("Config.GameplayRules")
local runtime_constants = require("Config.RuntimeConstants")
local logger = require("src.core.Logger")
local ui_view = require("src.ui.UIView")
local ui_model = require("src.ui.UIModel")
local ui_status_3d = require("src.ui.UIStatus3DLayer")
local number_utils = require("src.core.NumberUtils")

local tick_ui_sync = {}

local function _build_log_prefix()
  return "[Eggy]"
end

local function _log_once(state, level, key, ...)
  assert(state ~= nil, "missing state")
  assert(state._log_once ~= nil, "missing state._log_once")
  if state._log_once[key] then
    return
  end
  state._log_once[key] = true
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
      active = true
      local remaining = timeout - (state.ui_modal_elapsed or 0)
      if remaining < 0 then
        remaining = 0
      end
      seconds = math.ceil(remaining)
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

local function _resolve_debug_enabled(state)
  local ui = state and state.ui
  if ui and ui.debug_log_enabled_override ~= nil then
    return ui.debug_log_enabled_override == true
  end
  return gameplay_rules.debug_log_enabled == true
end

function tick_ui_sync.build_model(state, game)
  return ui_model.build(game, _build_ui_env(state, game))
end

local function _refresh_view(state, game, next_model)
  local model = next_model
  state.ui_model = model
  ui_view.render(state, model, _log_once, _build_log_prefix)

  assert(model ~= nil, "missing ui_model")
  local players = assert(game.players, "missing game.players")
  local turn = assert(game.turn, "missing game.turn")
  local current_index = assert(turn.current_player_index, "missing current_player_index")
  local current = assert(players[current_index], "missing current player: " .. tostring(current_index))
  local current_id = assert(current.id, "missing current player id")
  assert(GameAPI ~= nil and GameAPI.get_role ~= nil, "missing GameAPI.get_role")

  local turn_count = turn.turn_count
  local follow_ready = camera_helper
    and runtime_constants.eca_event
    and runtime_constants.eca_event.camera
    and runtime_constants.eca_event.camera.follow
    and TriggerCustomEvent
    and true
    or false

  if follow_ready then
    camera_helper.target_role_id = current_id
    TriggerCustomEvent(runtime_constants.eca_event.camera.follow, {})
  end

  return model
end

function tick_ui_sync.refresh_from_dirty(game, state, dirty)
  if state.ui_dirty then
    dirty.ui = true
  end
  local only_countdown = _is_only_turn_countdown(dirty)
  local ui_refreshed = false
  if dirty.any or dirty.ui then
    local env = _build_ui_env(state, game)
    local next_model = ui_model.update(state.ui_model, game, env, dirty)
    state.ui_model = next_model
    if only_countdown then
      ui_view.refresh_turn_label(state, next_model.panel and next_model.panel.turn_label or "")
    else
      _refresh_view(state, game, next_model)
      ui_refreshed = true
      if next_model.choice then
        ui_view.open_choice_modal(state, next_model.choice, next_model.market)
      end
    end
    state.ui_dirty = false
  end
  return ui_refreshed
end

function tick_ui_sync.sync_debug_log_panel(state)
  local debug_enabled = _resolve_debug_enabled(state)
  if state._debug_log_enabled ~= debug_enabled then
    state._debug_log_enabled = debug_enabled
    ui_view.set_debug_visible(state, debug_enabled)
    if debug_enabled then
      state._debug_log_seq = nil
    else
      ui_view.set_debug_log(state, "")
    end
  end
  if debug_enabled then
    local seq = logger.get_seq()
    if seq ~= state._debug_log_seq then
      state._debug_log_seq = seq
      local max_lines = gameplay_rules.debug_log_max_lines or 50
      ui_view.set_debug_log(state, logger.get_text(max_lines))
    end
  end
end

function tick_ui_sync.reset_status_3d(state)
  ui_status_3d.reset(state)
end

function tick_ui_sync.sync_status_3d(game, state, dirty)
  ui_status_3d.sync(game, state, dirty)
end

return tick_ui_sync
