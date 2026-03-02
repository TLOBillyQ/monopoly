local canvas_store = require("src.presentation.canvas_runtime.CanvasStore")
local runtime_constants = require("Config.RuntimeConstants")
local runtime_event_bridge = require("src.core.RuntimeEventBridge")
local turn_ui_sync_shared = require("src.core.TurnUISyncShared")
local runtime_compat = require("src.core.RuntimeCompat")

local ui_sync_ports = {}

function ui_sync_ports.build(common)
  return {
    apply_input_lock = function(state)
      local ui_view = require("src.presentation.api.UIViewService")
      ui_view.apply_input_lock(state)
    end,
    build_model = function(state, game)
      local ui_model = require("src.presentation.state.UIModel")
      local env = turn_ui_sync_shared.build_ui_env(state, game)
      return ui_model.build(game, env)
    end,
    refresh_from_dirty = function(game, state, dirty)
      if state.ui_dirty then
        dirty.ui = true
      end
      local only_countdown = turn_ui_sync_shared.is_only_turn_countdown(dirty)
      local ui_refreshed = false
      if dirty.any or dirty.ui then
        local ui_model = require("src.presentation.state.UIModel")
        local ui_view = require("src.presentation.api.UIViewService")
        local env = turn_ui_sync_shared.build_ui_env(state, game)
        local next_model = ui_model.update(state.ui_model, game, env, dirty)
        state.ui_model = next_model
        if only_countdown then
          ui_view.refresh_turn_label(state, next_model.panel and next_model.panel.turn_label or "")
        else
          ui_view.render(state, next_model, common.log_once, common.build_log_prefix)
          ui_refreshed = true
          if next_model.choice then
            ui_view.open_choice_modal(state, next_model.choice, next_model.market)
          end
        end
        state.ui_dirty = false
      end
      return ui_refreshed
    end,
    follow_camera = function(_, player_id)
      if player_id == nil then
        return false
      end
      local camera = runtime_compat.get_camera_helper()
      if camera then
        camera.target_role_id = player_id
      end
      if camera
          and runtime_constants
          and runtime_constants.eca_event
          and runtime_constants.eca_event.camera
          and runtime_constants.eca_event.camera.follow then
        runtime_event_bridge.emit_custom_event(
          runtime_constants.eca_event.camera.follow,
          {},
          { feature_key = "camera.follow" }
        )
        return true
      end
      return false
    end,
    get_ui_state = function(state)
      return common.get_ui_state(state)
    end,
    resolve_ui_gate = function(state)
      local ui = common.get_ui_state(state)
      local popup = ui and ui.popup_payload or nil
      return {
        input_blocked = ui and ui.input_blocked == true or false,
        choice_active = ui and ui.choice_active == true or false,
        market_active = ui and ui.market_active == true or false,
        popup_active = ui and ui.popup_active == true or false,
        popup_seq = ui and ui.popup_seq or nil,
        popup_auto_close_seconds = popup and popup.auto_close_seconds or nil,
        popup_owner_index = ui and ui.popup_owner_index or nil,
      }
    end,
    is_input_blocked = function(state)
      local ui = common.get_ui_state(state)
      return ui and ui.input_blocked == true or false
    end,
    is_popup_active = function(state)
      local ui = common.get_ui_state(state)
      return ui and ui.popup_active == true or false
    end,
    is_choice_active = function(state)
      local ui = common.get_ui_state(state)
      return ui and ui.choice_active == true or false
    end,
    is_market_active = function(state)
      local ui = common.get_ui_state(state)
      return ui and ui.market_active == true or false
    end,
    get_popup_owner_index = function(state)
      local ui = common.get_ui_state(state)
      return ui and ui.popup_owner_index or nil
    end,
    set_input_blocked = function(state, blocked)
      local ui = common.get_ui_state(state)
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
  }
end

return ui_sync_ports
