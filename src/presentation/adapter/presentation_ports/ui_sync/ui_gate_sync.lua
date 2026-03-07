local canvas_store = require("src.presentation.canvas_runtime.canvas_store")

local ui_gate_sync = {}

function ui_gate_sync.get_ui_state(state, common)
  return common.get_ui_state(state)
end

function ui_gate_sync.resolve_ui_gate(state, common)
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
end

function ui_gate_sync.is_input_blocked(state, common)
  local ui = common.get_ui_state(state)
  return ui and ui.input_blocked == true or false
end

function ui_gate_sync.is_popup_active(state, common)
  local ui = common.get_ui_state(state)
  return ui and ui.popup_active == true or false
end

function ui_gate_sync.is_choice_active(state, common)
  local ui = common.get_ui_state(state)
  return ui and ui.choice_active == true or false
end

function ui_gate_sync.is_market_active(state, common)
  local ui = common.get_ui_state(state)
  return ui and ui.market_active == true or false
end

function ui_gate_sync.get_popup_owner_index(state, common)
  local ui = common.get_ui_state(state)
  return ui and ui.popup_owner_index or nil
end

function ui_gate_sync.set_input_blocked(state, blocked, common)
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
end

return ui_gate_sync
