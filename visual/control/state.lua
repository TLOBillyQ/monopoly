local gameplay_rules = require("cfg.GameplayRules")
local runtime = require("visual.runtime")

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
  if ui then
    if ui.debug_log_enabled_override ~= nil then
      return ui.debug_log_enabled_override == true
    end
    local role = UIManager and UIManager.client_role or nil
    if role and type(ui.debug_log_enabled_by_role) == "table" then
      local role_id = runtime.resolve_role_id(role) or tostring(role)
      if ui.debug_log_enabled_by_role[role_id] ~= nil then
        return ui.debug_log_enabled_by_role[role_id] == true
      end
    end
  end
  return gameplay_rules.debug_log_enabled == true
end

return ui_event_state
