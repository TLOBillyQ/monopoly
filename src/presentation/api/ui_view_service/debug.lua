local runtime = require("src.presentation.api.UIRuntimePort")

local M = {}

function M.set_debug_log(state, text)
  local ui = state and state.ui
  if not ui or not ui.set_debug_log then
    return
  end
  ui:set_debug_log(text or "")
end

function M.set_debug_visible(state, visible)
  local ui = state and state.ui
  if not ui or not ui.set_debug_visible then
    return
  end
  local resolved = visible == true
  ui:set_debug_visible(resolved)
  local role = UIManager and UIManager.client_role or nil
  if role then
    if type(ui.debug_visible_by_role) ~= "table" then
      ui.debug_visible_by_role = {}
    end
    if type(ui.debug_log_enabled_by_role) ~= "table" then
      ui.debug_log_enabled_by_role = {}
    end
    local role_id = runtime.resolve_role_id(role) or tostring(role)
    ui.debug_visible_by_role[role_id] = resolved
    ui.debug_log_enabled_by_role[role_id] = resolved
  else
    ui.debug_visible = resolved
  end
end

return M
