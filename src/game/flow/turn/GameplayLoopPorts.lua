local gameplay_loop_ports = {}
local port_types = require("src.game.flow.turn.GameplayLoopPortTypes")

local function _resolve_base_ports()
  return {
    close_choice_modal = function() end,
    open_choice_modal = function() end,
    close_popup = function() end,
    apply_input_lock = function() end,
    apply_role_control_lock = function() end,
    play_move_anim = function() end,
    play_action_anim = function() end,
    step_choice_timeout = function() end,
    step_modal_timeout = function() end,
    update_countdown = function() end,
    build_model = function() return {} end,
    refresh_from_dirty = function() return false end,
    log_status = function() end,
    sync_debug_log = function() end,
    reset_status_3d = function() end,
    sync_status_3d = function() end,
    install_event_handlers = function() end,
    on_bankruptcy_tiles_cleared = function() end,
    get_ui_state = function() return nil end,
    is_input_blocked = function() return false end,
    is_popup_active = function() return false end,
    is_choice_active = function() return false end,
    is_market_active = function() return false end,
    get_popup_owner_index = function() return nil end,
    set_input_blocked = function() end,
  }
end

local base_ports = _resolve_base_ports()

function gameplay_loop_ports.resolve(override_ports)
  if not override_ports then
    return base_ports
  end
  local resolved = {}
  for _, key in ipairs(port_types.keys) do
    local fn = base_ports[key]
    if fn == nil then
      error("missing base port: " .. tostring(key))
    end
    if type(override_ports[key]) == "function" then
      resolved[key] = override_ports[key]
    else
      resolved[key] = fn
    end
  end
  if override_ports.get_ui_state == nil then
    resolved.get_ui_state = function(state)
      return state and state.ui or nil
    end
  end
  if override_ports.is_input_blocked == nil then
    resolved.is_input_blocked = function(state)
      local ui = resolved.get_ui_state(state)
      return ui and ui.input_blocked == true or false
    end
  end
  if override_ports.is_popup_active == nil then
    resolved.is_popup_active = function(state)
      local ui = resolved.get_ui_state(state)
      return ui and ui.popup_active == true or false
    end
  end
  if override_ports.is_choice_active == nil then
    resolved.is_choice_active = function(state)
      local ui = resolved.get_ui_state(state)
      return ui and ui.choice_active == true or false
    end
  end
  if override_ports.is_market_active == nil then
    resolved.is_market_active = function(state)
      local ui = resolved.get_ui_state(state)
      return ui and ui.market_active == true or false
    end
  end
  if override_ports.get_popup_owner_index == nil then
    resolved.get_popup_owner_index = function(state)
      local ui = resolved.get_ui_state(state)
      return ui and ui.popup_owner_index or nil
    end
  end
  if override_ports.set_input_blocked == nil then
    resolved.set_input_blocked = function(state, blocked)
      local ui = resolved.get_ui_state(state)
      if not ui then
        return false
      end
      if ui.input_blocked == blocked then
        return false
      end
      ui.input_blocked = blocked
      return true
    end
  end
  return resolved
end

return gameplay_loop_ports
