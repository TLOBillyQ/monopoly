local ui_model_sync = require("src.presentation.api.presentation_ports.ui_sync.UIModelSync")
local camera_sync = require("src.presentation.api.presentation_ports.ui_sync.CameraSync")
local ui_gate_sync = require("src.presentation.api.presentation_ports.ui_sync.UIGateSync")

local ui_sync_ports = {}

function ui_sync_ports.build(common)
  return {
    apply_input_lock = ui_model_sync.apply_input_lock,
    build_model = ui_model_sync.build_model,
    refresh_from_dirty = function(game, state, dirty)
      return ui_model_sync.refresh_from_dirty(game, state, dirty, common)
    end,
    follow_camera = function(_, player_id)
      return camera_sync.follow_camera(player_id)
    end,
    get_ui_state = function(state)
      return ui_gate_sync.get_ui_state(state, common)
    end,
    resolve_ui_gate = function(state)
      return ui_gate_sync.resolve_ui_gate(state, common)
    end,
    is_input_blocked = function(state)
      return ui_gate_sync.is_input_blocked(state, common)
    end,
    is_popup_active = function(state)
      return ui_gate_sync.is_popup_active(state, common)
    end,
    is_choice_active = function(state)
      return ui_gate_sync.is_choice_active(state, common)
    end,
    is_market_active = function(state)
      return ui_gate_sync.is_market_active(state, common)
    end,
    get_popup_owner_index = function(state)
      return ui_gate_sync.get_popup_owner_index(state, common)
    end,
    set_input_blocked = function(state, blocked)
      return ui_gate_sync.set_input_blocked(state, blocked, common)
    end,
  }
end

return ui_sync_ports
