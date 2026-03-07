local M = {}

function M.build_base_ui_sync_ports(load_tick_timeout, load_tick_ui_sync)
  return {
    apply_input_lock = function() end,
    step_choice_timeout = function(game, state, dt)
      local tick_timeout = load_tick_timeout()
      tick_timeout.step_default_choice(game, state, dt)
    end,
    step_modal_timeout = function(game, state, dt)
      local tick_timeout = load_tick_timeout()
      tick_timeout.step_default_modal(game, state, dt)
    end,
    step_target_selection = function() end,
    update_countdown = function(game, state)
      local tick_ui_sync = load_tick_ui_sync()
      tick_ui_sync.update_countdown(game, state)
    end,
    resolve_ui_gate = function()
      return {
        input_blocked = false,
        choice_active = false,
        market_active = false,
        popup_active = false,
        popup_seq = nil,
        popup_auto_close_seconds = nil,
        popup_owner_index = nil,
      }
    end,
    build_model = function() return {} end,
    refresh_from_dirty = function() return false end,
    follow_camera = function() return false end,
    get_ui_state = function() return nil end,
    is_input_blocked = function() return false end,
    is_popup_active = function() return false end,
    is_choice_active = function() return false end,
    is_market_active = function() return false end,
    get_popup_owner_index = function() return nil end,
    set_input_blocked = function() return false end,
  }
end

function M.fill_ui_sync_defaults(ui_sync_ports, base_ui_sync_ports)
  if ui_sync_ports.get_ui_state == base_ui_sync_ports.get_ui_state then
    ui_sync_ports.get_ui_state = function(state)
      return state and state.ui or nil
    end
  end
  if ui_sync_ports.is_input_blocked == base_ui_sync_ports.is_input_blocked then
    ui_sync_ports.is_input_blocked = function(state)
      local ui = ui_sync_ports.get_ui_state(state)
      return ui and ui.input_blocked == true or false
    end
  end
  if ui_sync_ports.is_popup_active == base_ui_sync_ports.is_popup_active then
    ui_sync_ports.is_popup_active = function(state)
      local ui = ui_sync_ports.get_ui_state(state)
      return ui and ui.popup_active == true or false
    end
  end
  if ui_sync_ports.is_choice_active == base_ui_sync_ports.is_choice_active then
    ui_sync_ports.is_choice_active = function(state)
      local ui = ui_sync_ports.get_ui_state(state)
      return ui and ui.choice_active == true or false
    end
  end
  if ui_sync_ports.is_market_active == base_ui_sync_ports.is_market_active then
    ui_sync_ports.is_market_active = function(state)
      local ui = ui_sync_ports.get_ui_state(state)
      return ui and ui.market_active == true or false
    end
  end
  if ui_sync_ports.get_popup_owner_index == base_ui_sync_ports.get_popup_owner_index then
    ui_sync_ports.get_popup_owner_index = function(state)
      local ui = ui_sync_ports.get_ui_state(state)
      return ui and ui.popup_owner_index or nil
    end
  end
  if ui_sync_ports.set_input_blocked == base_ui_sync_ports.set_input_blocked then
    ui_sync_ports.set_input_blocked = function(state, blocked)
      local ui = ui_sync_ports.get_ui_state(state)
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
  if ui_sync_ports.resolve_ui_gate == base_ui_sync_ports.resolve_ui_gate then
    ui_sync_ports.resolve_ui_gate = function(state)
      local ui = ui_sync_ports.get_ui_state(state)
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
    end
  end
end

return M
