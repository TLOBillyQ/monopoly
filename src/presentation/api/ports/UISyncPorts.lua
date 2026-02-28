local gameplay_rules = require("Config.GameplayRules")
local runtime_constants = require("Config.RuntimeConstants")
local runtime_event_bridge = require("src.core.RuntimeEventBridge")
local tick_timeout = require("src.game.flow.turn.TickTimeout")
local tick_ui_sync = require("src.game.flow.turn.TickUISync")
local canvas_store = require("src.presentation.canvas_runtime.CanvasStore")

local M = {}

local function _get_ui_state(state)
  return state and state.ui or nil
end

function M.build()
  return {
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
  }
end

return M
