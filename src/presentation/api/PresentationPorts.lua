local gameplay_rules = require("Config.GameplayRules")
local runtime_constants = require("Config.RuntimeConstants")
local runtime_event_bridge = require("src.core.RuntimeEventBridge")
local tick_timeout = require("src.game.flow.turn.TickTimeout")
local tick_ui_sync = require("src.game.flow.turn.TickUISync")
local canvas_store = require("src.presentation.canvas_runtime.CanvasStore")
local ui_event_state = require("src.presentation.interaction.UIEventState")
local logger = require("src.core.Logger")
local move_anim = require("src.presentation.render.MoveAnim")

local presentation_ports = {}

local _action_anim_player = nil

local function _load_action_anim_player()
  if _action_anim_player then
    return _action_anim_player
  end
  _action_anim_player = require("src.presentation.render.ActionAnim")
  return _action_anim_player
end

local function _apply_role_control_lock(state, enabled)
  local ui_view = require("src.presentation.api.UIViewService")
  ui_view.apply_role_control_lock(state, enabled)
end

local function _update_role_control_lock_exempt(state, enabled, meta, lock_fn)
  local role_id = meta and meta.player_id or nil
  if role_id == nil then
    lock_fn(state, state.role_control_lock_active == true)
    return
  end

  local counts = state.role_control_lock_exempt_count_by_role
  if type(counts) ~= "table" then
    counts = {}
    state.role_control_lock_exempt_count_by_role = counts
  end

  local exempt_by_role = state.role_control_lock_exempt_by_role
  if type(exempt_by_role) ~= "table" then
    exempt_by_role = {}
    state.role_control_lock_exempt_by_role = exempt_by_role
  end

  local current = counts[role_id] or 0
  if enabled == true then
    current = math.max(0, current - 1)
  else
    current = current + 1
  end

  if current <= 0 then
    counts[role_id] = nil
    exempt_by_role[role_id] = nil
  else
    counts[role_id] = current
    exempt_by_role[role_id] = true
  end

  lock_fn(state, state.role_control_lock_active == true)
end

local function _get_ui_state(state)
  return state and state.ui or nil
end

function presentation_ports.build()
  return {
    modal = {
      close_choice_modal = function(state)
        local ui_view = require("src.presentation.api.UIViewService")
        ui_view.close_choice_modal(state)
      end,
      open_choice_modal = function(state, choice, market)
        local ui_view = require("src.presentation.api.UIViewService")
        ui_view.open_choice_modal(state, choice, market)
      end,
      close_popup = function(state)
        local ui_view = require("src.presentation.api.UIViewService")
        ui_view.close_popup(state)
      end,
    },
    anim = {
      play_move_anim = function(state, anim_ctx)
        if anim_ctx then
          local prev = anim_ctx.on_step_lock
          anim_ctx.on_step_lock = function(enabled, step_time, meta)
            if prev then
              prev(enabled, step_time, meta)
            end
            _update_role_control_lock_exempt(state, enabled, meta, _apply_role_control_lock)
          end
        end
        return move_anim.play_sequence(state.board_scene, anim_ctx)
      end,
      play_action_anim = function(state, anim_ctx)
        local player = _load_action_anim_player()
        return player.play(state, anim_ctx)
      end,
      reset_status_3d = function(state)
        local ui_status_3d = require("src.presentation.render.Status3DService")
        ui_status_3d.reset(state)
      end,
      sync_status_3d = function(game, state, dirty)
        local ui_status_3d = require("src.presentation.render.Status3DService")
        ui_status_3d.sync(game, state, dirty)
      end,
    },
    ui_sync = {
      apply_input_lock = function(state)
        local ui_view = require("src.presentation.api.UIViewService")
        ui_view.apply_input_lock(state)
      end,
      step_choice_timeout = function(game, state, dt)
        tick_timeout.step_default_choice(game, state, dt)
      end,
      step_modal_timeout = function(game, state, dt)
        tick_timeout.step_default_modal(game, state, dt)
      end,
      update_countdown = function(game, state)
        tick_ui_sync.update_countdown(game, state)
      end,
      build_model = function(state, game)
        local ui_model = require("src.presentation.state.UIModel")
        local env = tick_ui_sync.build_ui_env(state, game)
        return ui_model.build(game, env)
      end,
      refresh_from_dirty = function(game, state, dirty)
        if state.ui_dirty then
          dirty.ui = true
        end
        local only_countdown = tick_ui_sync.is_only_turn_countdown(dirty)
        local ui_refreshed = false
        if dirty.any or dirty.ui then
          local ui_model = require("src.presentation.state.UIModel")
          local ui_view = require("src.presentation.api.UIViewService")
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

            if camera_helper then
              camera_helper.target_role_id = current_id
            end
            if camera_helper
              and runtime_constants
              and runtime_constants.eca_event
              and runtime_constants.eca_event.camera
              and runtime_constants.eca_event.camera.follow
            then
              runtime_event_bridge.emit_custom_event(
                runtime_constants.eca_event.camera.follow,
                {},
                { feature_key = "camera.follow" }
              )
            end
          end
          state.ui_dirty = false
        end
        return ui_refreshed
      end,
      get_ui_state = function(state)
        return _get_ui_state(state)
      end,
      is_input_blocked = function(state)
        local ui = _get_ui_state(state)
        return ui and ui.input_blocked == true or false
      end,
      is_popup_active = function(state)
        local ui = _get_ui_state(state)
        return ui and ui.popup_active == true or false
      end,
      is_choice_active = function(state)
        local ui = _get_ui_state(state)
        return ui and ui.choice_active == true or false
      end,
      is_market_active = function(state)
        local ui = _get_ui_state(state)
        return ui and ui.market_active == true or false
      end,
      get_popup_owner_index = function(state)
        local ui = _get_ui_state(state)
        return ui and ui.popup_owner_index or nil
      end,
      set_input_blocked = function(state, blocked)
        local ui = _get_ui_state(state)
        if not ui then
          return false
        end
        if ui.input_blocked == blocked then
          return false
        end
        canvas_store.patch_slice(state, "base", function()
          ui.input_blocked = blocked
        end)
        return true
      end,
    },
    debug = {
      log_status = function(view)
        tick_ui_sync.log_status(view)
      end,
      sync_debug_log = function(state)
        local debug_enabled = ui_event_state.resolve_debug_enabled(state)
        if state._debug_log_enabled ~= debug_enabled then
          state._debug_log_enabled = debug_enabled
          local ui_view = require("src.presentation.api.UIViewService")
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
            local ui_view = require("src.presentation.api.UIViewService")
            local max_lines = gameplay_rules.debug_log_max_lines or 50
            ui_view.set_debug_log(state, logger.get_text_by_level("event", max_lines))
          end
        end
      end,
      resolve_debug_enabled = function(state)
        return ui_event_state.resolve_debug_enabled(state)
      end,
    },
    state = {
      apply_role_control_lock = function(state, enabled)
        local ui_view = require("src.presentation.api.UIViewService")
        ui_view.apply_role_control_lock(state, enabled)
      end,
      install_event_handlers = function(game, log, state)
        local event_handlers = require("src.presentation.api.UIEventHandlers")
        event_handlers.install(game, log, state)
      end,
      on_bankruptcy_tiles_cleared = function(game, _, owned_tile_ids)
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
      end,
    },
  }
end

return presentation_ports
