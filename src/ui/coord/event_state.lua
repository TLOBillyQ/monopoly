local runtime = require("src.ui.render.runtime_ui")
local role_id_utils = require("src.foundation.identity")

local ui_event_state = {}

local function _has_active_modal(ui)
  return ui.market_active or ui.choice_active or ui.popup_active
end

function ui_event_state.is_base_screen_active(state)
  local ui = state and state.ui
  if not ui then
    return false
  end
  if _has_active_modal(ui) then
    return false
  end
  return true
end

function ui_event_state.resolve_event_log_enabled(state, role_id)
  local ui = state and state.ui
  if role_id == nil then
    local role = runtime.get_client_role()
    role_id = runtime.resolve_role_id(role)
  end
  role_id = role_id_utils.normalize(role_id)
  if role_id == nil then
    return false
  end
  local by_role = ui and ui.debug_log_enabled_by_role or nil
  if type(by_role) == "table" then
    return role_id_utils.read(by_role, role_id) == true
  end
  return false
end

return ui_event_state

--[[ mutate4lua-manifest
version=2
projectHash=399542ba2ddab7b3
scope.0.id=chunk:src/ui/coord/event_state.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=39
scope.0.semanticHash=400b101a658d5709
scope.1.id=function:_has_active_modal:6
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=8
scope.1.semanticHash=5b32da1b8e7f74a7
scope.2.id=function:ui_event_state.is_base_screen_active:10
scope.2.kind=function
scope.2.startLine=10
scope.2.endLine=19
scope.2.semanticHash=9483775652f6a794
scope.3.id=function:ui_event_state.resolve_event_log_enabled:21
scope.3.kind=function
scope.3.startLine=21
scope.3.endLine=36
scope.3.semanticHash=d375310b29b40447
]]
