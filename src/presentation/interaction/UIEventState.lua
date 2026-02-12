local gameplay_rules = require("Config.GameplayRules")

local ui_event_state = {}

function ui_event_state.is_base_screen_active(state)
  local ui = state and state.ui
  if not ui then
    return false
  end
  if ui.market_active or ui.choice_active or ui.popup_active then
    return false
  end
  return true
end

function ui_event_state.resolve_debug_enabled(state)
  local ui = state and state.ui
  if ui and ui.debug_log_enabled_override ~= nil then
    return ui.debug_log_enabled_override == true
  end
  return gameplay_rules.debug_log_enabled == true
end

return ui_event_state
