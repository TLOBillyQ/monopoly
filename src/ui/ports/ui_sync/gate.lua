local canvas_store = require("src.ui.state.canvas_store")

local ui_gate_sync = {}

local function _resolve_ui(state, common)
  return common.get_ui_state(state)
end

local function _read_flag(ui, key)
  return ui and ui[key] == true or false
end

local function _read_value(ui, key)
  return ui and ui[key] or nil
end

local function _resolve_popup_auto_close_seconds(ui)
  local popup = ui and ui.popup_payload or nil
  return popup and popup.auto_close_seconds or nil
end

function ui_gate_sync.get_ui_state(state, common)
  return common.get_ui_state(state)
end

function ui_gate_sync.resolve_ui_gate(state, common)
  local ui = _resolve_ui(state, common)
  return {
    input_blocked = _read_flag(ui, "input_blocked"),
    choice_active = _read_flag(ui, "choice_active"),
    market_active = _read_flag(ui, "market_active"),
    popup_active = _read_flag(ui, "popup_active"),
    popup_seq = _read_value(ui, "popup_seq"),
    popup_auto_close_seconds = _resolve_popup_auto_close_seconds(ui),
    popup_owner_index = _read_value(ui, "popup_owner_index"),
  }
end

function ui_gate_sync.is_input_blocked(state, common)
  return _read_flag(_resolve_ui(state, common), "input_blocked")
end

function ui_gate_sync.is_popup_active(state, common)
  return _read_flag(_resolve_ui(state, common), "popup_active")
end

function ui_gate_sync.is_choice_active(state, common)
  return _read_flag(_resolve_ui(state, common), "choice_active")
end

function ui_gate_sync.is_market_active(state, common)
  return _read_flag(_resolve_ui(state, common), "market_active")
end

function ui_gate_sync.get_popup_owner_index(state, common)
  return _read_value(_resolve_ui(state, common), "popup_owner_index")
end

function ui_gate_sync.set_input_blocked(state, blocked, common)
  local ui = _resolve_ui(state, common)
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
end

return ui_gate_sync
