local M = {}

local function _bool_field(obj, field)
  return obj and obj[field] == true or false
end

local function _opt_field(obj, field)
  return obj and obj[field] or nil
end

local _cached_ui_gate = {
  input_blocked = false,
  choice_active = false,
  market_active = false,
  popup_active = false,
  popup_seq = nil,
  popup_auto_close_seconds = nil,
  popup_owner_index = nil,
}

local function _build_ui_gate(ui, popup)
  _cached_ui_gate.input_blocked = _bool_field(ui, "input_blocked")
  _cached_ui_gate.choice_active = _bool_field(ui, "choice_active")
  _cached_ui_gate.market_active = _bool_field(ui, "market_active")
  _cached_ui_gate.popup_active = _bool_field(ui, "popup_active")
  _cached_ui_gate.popup_seq = _opt_field(ui, "popup_seq")
  _cached_ui_gate.popup_auto_close_seconds = popup and popup.auto_close_seconds or nil
  _cached_ui_gate.popup_owner_index = _opt_field(ui, "popup_owner_index")
  return _cached_ui_gate
end

local function _resolve_ui_gate_from_state(state)
  local ui = state and state.ui or nil
  local popup = ui and ui.popup_payload or nil
  return _build_ui_gate(ui, popup)
end

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
    update_countdown = function(game, state)
      local tick_ui_sync = load_tick_ui_sync()
      tick_ui_sync.update_countdown(game, state)
    end,
    resolve_ui_gate = _resolve_ui_gate_from_state,
    build_model = function() return {} end,
    refresh_from_dirty = function() return false end,
    follow_camera = function() return false end,
    sync_camera_position = function() return false end,
    get_ui_state = function() return nil end,
    is_input_blocked = function() return false end,
    is_popup_active = function() return false end,
    is_choice_active = function() return false end,
    is_market_active = function() return false end,
    get_popup_owner_index = function() return nil end,
    set_input_blocked = function() return false end,
  }
end

local function _default_get_ui_state(state)
  return state and state.ui or nil
end

local function _default_ui_bool(ui_sync_ports, field)
  return function(state)
    return _bool_field(ui_sync_ports.get_ui_state(state), field)
  end
end

local function _default_ui_opt(ui_sync_ports, field)
  return function(state)
    return _opt_field(ui_sync_ports.get_ui_state(state), field)
  end
end

local function _default_set_input_blocked(ui_sync_ports)
  return function(state, blocked)
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

local function _default_resolve_ui_gate(ui_sync_ports)
  return function(state)
    local ui = ui_sync_ports.get_ui_state(state)
    local popup = ui and ui.popup_payload or nil
    return _build_ui_gate(ui, popup)
  end
end

local function _fill_default(ui_sync_ports, base_ui_sync_ports, key, resolver)
  if ui_sync_ports[key] == nil or ui_sync_ports[key] == base_ui_sync_ports[key] then
    ui_sync_ports[key] = resolver(ui_sync_ports)
  end
end

local function _build_ui_sync_specs()
  return {
    { key = "get_ui_state", resolver = function() return _default_get_ui_state end },
    { key = "is_input_blocked", resolver = function(ports) return _default_ui_bool(ports, "input_blocked") end },
    { key = "is_popup_active", resolver = function(ports) return _default_ui_bool(ports, "popup_active") end },
    { key = "is_choice_active", resolver = function(ports) return _default_ui_bool(ports, "choice_active") end },
    { key = "is_market_active", resolver = function(ports) return _default_ui_bool(ports, "market_active") end },
    { key = "get_popup_owner_index", resolver = function(ports) return _default_ui_opt(ports, "popup_owner_index") end },
    { key = "set_input_blocked", resolver = _default_set_input_blocked },
    { key = "resolve_ui_gate", resolver = _default_resolve_ui_gate },
  }
end

local function _apply_ui_sync_defaults(ui_sync_ports, base_ui_sync_ports, specs)
  for _, spec in ipairs(specs) do
    _fill_default(ui_sync_ports, base_ui_sync_ports, spec.key, spec.resolver)
  end
end

local _ui_sync_specs = _build_ui_sync_specs()

function M.fill_ui_sync_defaults(ui_sync_ports, base_ui_sync_ports)
  _apply_ui_sync_defaults(ui_sync_ports, base_ui_sync_ports, _ui_sync_specs)
end

return M
