local gameplay_rules = require("Config.GameplayRules")
local runtime_constants = require("Config.RuntimeConstants")
local logger = require("src.core.Logger")
local tick_timeout = require("src.game.flow.turn.TickTimeout")
local tick_ui_sync = require("src.game.flow.turn.TickUISync")
local ui_event_state = require("src.presentation.interaction.UIEventState")
local move_anim = require("src.presentation.render.MoveAnim")

local adapter = {}

local _action_anim_player = nil

local function _load_action_anim_player()
  if _action_anim_player then
    return _action_anim_player
  end
  _action_anim_player = require("src.presentation.render.ActionAnim")
  return _action_anim_player
end

local function _default_close_choice_modal(state)
  local ui_view = require("src.presentation.api.UIView")
  ui_view.close_choice_modal(state)
end

local function _default_open_choice_modal(state, choice, market)
  local ui_view = require("src.presentation.api.UIView")
  ui_view.open_choice_modal(state, choice, market)
end

local function _default_close_popup(state)
  local ui_view = require("src.presentation.api.UIView")
  ui_view.close_popup(state)
end

local function _default_apply_input_lock(state)
  local ui_view = require("src.presentation.api.UIView")
  ui_view.apply_input_lock(state)
end

local function _default_get_ui_state(state)
  return state and state.ui or nil
end

local function _default_is_input_blocked(state)
  local ui = _default_get_ui_state(state)
  return ui and ui.input_blocked == true or false
end

local function _default_is_popup_active(state)
  local ui = _default_get_ui_state(state)
  return ui and ui.popup_active == true or false
end

local function _default_is_choice_active(state)
  local ui = _default_get_ui_state(state)
  return ui and ui.choice_active == true or false
end

local function _default_is_market_active(state)
  local ui = _default_get_ui_state(state)
  return ui and ui.market_active == true or false
end

local function _default_get_popup_owner_index(state)
  local ui = _default_get_ui_state(state)
  return ui and ui.popup_owner_index or nil
end

local function _default_set_input_blocked(state, blocked)
  local ui = _default_get_ui_state(state)
  if not ui then
    return false
  end
  if ui.input_blocked == blocked then
    return false
  end
  ui.input_blocked = blocked
  return true
end

local function _default_apply_role_control_lock(state, enabled)
  local ui_view = require("src.presentation.api.UIView")
  ui_view.apply_role_control_lock(state, enabled)
end

local function _apply_role_control_lock_suppress(state, enabled, lock_fn)
  if state.role_control_lock_suppress == nil then
    state.role_control_lock_suppress = 0
  end
  if enabled == true then
    state.role_control_lock_suppress = math.max(0, state.role_control_lock_suppress - 1)
  else
    state.role_control_lock_suppress = state.role_control_lock_suppress + 1
  end
  local should_lock = state.role_control_lock_suppress == 0
  lock_fn(state, should_lock)
end

local function _default_play_move_anim(state, anim_ctx)
  if anim_ctx then
    local prev = anim_ctx.on_step_lock
    anim_ctx.on_step_lock = function(enabled, step_time, meta)
      if prev then
        prev(enabled, step_time, meta)
      end
      _apply_role_control_lock_suppress(state, enabled, _default_apply_role_control_lock)
    end
  end
  return move_anim.play_sequence(state.board_scene, anim_ctx)
end

local function _default_play_action_anim(state, anim_ctx)
  local player = _load_action_anim_player()
  return player.play(state, anim_ctx)
end

local function _default_step_choice_timeout(game, state, dt)
  tick_timeout.step_default_choice(game, state, dt)
end

local function _default_step_modal_timeout(game, state, dt)
  tick_timeout.step_default_modal(game, state, dt)
end

local function _default_update_countdown(game, state)
  tick_ui_sync.update_countdown(game, state)
end

local function _default_build_model(state, game)
  local ui_model = require("src.presentation.state.UIModel")
  local env = tick_ui_sync.build_ui_env(state, game)
  return ui_model.build(game, env)
end

local function _default_refresh_from_dirty(game, state, dirty)
  if state.ui_dirty then
    dirty.ui = true
  end
  local only_countdown = tick_ui_sync.is_only_turn_countdown(dirty)
  local ui_refreshed = false
  if dirty.any or dirty.ui then
    local ui_model = require("src.presentation.state.UIModel")
    local ui_view = require("src.presentation.api.UIView")
    local env = tick_ui_sync.build_ui_env(state, game)
    local next_model = ui_model.update(state.ui_model, game, env, dirty)
    state.ui_model = next_model
    if only_countdown then
      ui_view.refresh_turn_label(state, next_model.panel and next_model.panel.turn_label or "")
    else
      ui_view.render(state, next_model, tick_ui_sync.log_once, tick_ui_sync.log_prefix)
      ui_refreshed = true
      if next_model.choice then
        ui_view.open_choice_modal(state, next_model.choice, next_model.market)
      end
      local players = assert(game.players, "missing game.players")
      local turn = assert(game.turn, "missing game.turn")
      local current_index = assert(turn.current_player_index, "missing current_player_index")
      local current = assert(players[current_index], "missing current player: " .. tostring(current_index))
      local current_id = assert(current.id, "missing current player id")
      assert(GameAPI ~= nil and GameAPI.get_role ~= nil, "missing GameAPI.get_role")

      local follow_ready = camera_helper
        and runtime_constants
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
    end
    state.ui_dirty = false
  end
  return ui_refreshed
end

local function _default_log_status(view)
  tick_ui_sync.log_status(view)
end

local function _default_resolve_debug_enabled(state)
  return ui_event_state.resolve_debug_enabled(state)
end

local function _default_sync_debug_log(state)
  local debug_enabled = _default_resolve_debug_enabled(state)
  if state._debug_log_enabled ~= debug_enabled then
    state._debug_log_enabled = debug_enabled
    local ui_view = require("src.presentation.api.UIView")
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
      local ui_view = require("src.presentation.api.UIView")
      local max_lines = gameplay_rules.debug_log_max_lines or 50
      ui_view.set_debug_log(state, logger.get_text_by_level("event", max_lines))
    end
  end
end

local function _default_reset_status_3d(state)
  local ui_status_3d = require("src.presentation.render.UIStatus3DLayer")
  ui_status_3d.reset(state)
end

local function _default_sync_status_3d(game, state, dirty)
  local ui_status_3d = require("src.presentation.render.UIStatus3DLayer")
  ui_status_3d.sync(game, state, dirty)
end

local function _default_install_event_handlers(game, log, state)
  local event_handlers = require("src.presentation.api.UIEventHandlers")
  event_handlers.install(game, log, state)
end

local function _default_on_bankruptcy_tiles_cleared(game, _, owned_tile_ids)
  local ui_port = game and game.ui_port or nil
  local scene = ui_port and ui_port.board_scene or nil
  if not scene or not scene.building_unit_groups or not scene.tiles then
    return
  end
  local tile_renderer = require("src.presentation.render.TileRenderer")
  for _, tile_id in ipairs(owned_tile_ids or {}) do
    local idx = game.board:index_of_tile_id(tile_id)
    local building = scene.building_unit_groups[idx]
    if building then
      GameAPI.destroy_unit_with_children(building, true)
      scene.building_unit_groups[idx] = nil
    end
    local building_txt = scene.building_txt and scene.building_txt[idx] or nil
    if building_txt and building_txt.set_billboard_text then
      building_txt.set_billboard_text("  ")
    end
    local tile_unit = scene.tiles[idx]
    if tile_unit then
      tile_renderer.render_tile(tile_unit, tile_id, nil)
    end
  end
end

function adapter.build(_)
  return {
    modal = {
      close_choice_modal = _default_close_choice_modal,
      open_choice_modal = _default_open_choice_modal,
      close_popup = _default_close_popup,
    },
    anim = {
      play_move_anim = _default_play_move_anim,
      play_action_anim = _default_play_action_anim,
      reset_status_3d = _default_reset_status_3d,
      sync_status_3d = _default_sync_status_3d,
    },
    ui_sync = {
      apply_input_lock = _default_apply_input_lock,
      step_choice_timeout = _default_step_choice_timeout,
      step_modal_timeout = _default_step_modal_timeout,
      update_countdown = _default_update_countdown,
      build_model = _default_build_model,
      refresh_from_dirty = _default_refresh_from_dirty,
      get_ui_state = _default_get_ui_state,
      is_input_blocked = _default_is_input_blocked,
      is_popup_active = _default_is_popup_active,
      is_choice_active = _default_is_choice_active,
      is_market_active = _default_is_market_active,
      get_popup_owner_index = _default_get_popup_owner_index,
      set_input_blocked = _default_set_input_blocked,
    },
    debug = {
      log_status = _default_log_status,
      sync_debug_log = _default_sync_debug_log,
      resolve_debug_enabled = _default_resolve_debug_enabled,
    },
    state = {
      apply_role_control_lock = _default_apply_role_control_lock,
      install_event_handlers = _default_install_event_handlers,
      on_bankruptcy_tiles_cleared = _default_on_bankruptcy_tiles_cleared,
    },
  }
end

return adapter
