local logger = require("src.core.Logger")
local runtime = require("src.presentation.api.UIRuntimePort")
local ui_view = require("src.presentation.api.UIViewService")
local canvas = require("src.presentation.interaction.UICanvasCoordinator")
local ui_events = require("src.presentation.shared.UIEvents")
local ui_event_state = require("src.presentation.interaction.UIEventState")
local runtime_compat = require("src.core.RuntimeCompat")

local view_command_dispatcher = {}

local function _resolve_role_by_game_api(role_id)
  if role_id == nil then
    return nil
  end
  if not (GameAPI and type(GameAPI.get_role) == "function") then
    return nil
  end
  local ok, role = pcall(GameAPI.get_role, role_id)
  if not ok then
    return nil
  end
  return role
end

local function _resolve_role_by_id(role_id)
  if role_id == nil then
    return runtime.get_client_role()
  end
  local roles = runtime_compat.get_roles()
  if type(roles) == "table" then
    for _, role in ipairs(roles) do
      if runtime.resolve_role_id(role) == role_id then
        return role
      end
    end
  end
  local role_from_game_api = _resolve_role_by_game_api(role_id)
  if role_from_game_api ~= nil then
    return role_from_game_api
  end
  return {
    get_roleid = function()
      return role_id
    end,
  }
end

function view_command_dispatcher.dispatch(state, intent)
  local intent_type = intent and intent.type
  if not intent_type then
    return false
  end

  if intent_type == "toggle_action_log" then
    local ui = state and state.ui or nil
    if not ui then
      return true
    end
    local active_role = _resolve_role_by_id(intent.actor_role_id)
    runtime.with_client_role(active_role, function()
      ui.debug_log_enabled_override = nil
      local next_enabled = not ui_event_state.resolve_debug_enabled(state)
      ui_view.set_debug_visible(state, next_enabled)
      if active_role == nil then
        return
      end
      local role_id = runtime.resolve_role_id(active_role) or tostring(active_role)
      if type(ui.debug_visible_by_role) ~= "table" then
        ui.debug_visible_by_role = {}
      end
      if type(ui.debug_log_enabled_by_role) ~= "table" then
        ui.debug_log_enabled_by_role = {}
      end
      ui.debug_visible_by_role[role_id] = next_enabled
      ui.debug_log_enabled_by_role[role_id] = next_enabled
      if next_enabled and type(active_role.send_ui_custom_event) ~= "function" then
        logger.warn("toggle_action_log missing role event channel:", tostring(role_id))
      end
      if next_enabled then
        canvas.switch_for_role(ui, canvas.CANVAS_DEBUG, active_role)
      else
        local hide_event = ui_events.hide[canvas.CANVAS_DEBUG]
        if hide_event then
          ui_events.send_to_role(active_role, hide_event, {})
        end
      end
    end)
    return true
  end

  if intent_type == "market_select" then
    ui_view.select_market_option(state, intent.option_id)
    return true
  end

  if intent_type == "popup_confirm" then
    ui_view.close_popup(state)
    return true
  end

  return false
end

return view_command_dispatcher
