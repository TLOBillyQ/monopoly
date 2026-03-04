local logger = require("src.core.Logger")
local runtime = require("src.presentation.api.UIRuntimePort")
local ui_view = require("src.presentation.api.UIViewService")
local canvas = require("src.presentation.interaction.UICanvasCoordinator")
local ui_events = require("src.presentation.shared.UIEvents")
local ui_event_state = require("src.presentation.interaction.UIEventState")
local role_context = require("src.presentation.interaction.ui_intent_dispatcher.RoleContext")

local view_command_dispatcher = {}

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
    local actor_role_id = intent.actor_role_id
    if actor_role_id == nil then
      logger.warn("toggle_action_log missing actor_role_id")
      return true
    end
    local active_role = role_context.resolve_by_id(intent.actor_role_id)
    local next_enabled = not ui_event_state.resolve_debug_enabled(state, actor_role_id)
    ui_view.set_debug_visible_for_role(state, active_role, next_enabled)
    if next_enabled and type(active_role.send_ui_custom_event) ~= "function" then
      logger.warn("toggle_action_log missing role event channel:", tostring(actor_role_id))
    end
    if next_enabled then
      canvas.switch_for_role(ui, canvas.CANVAS_DEBUG, active_role)
    else
      local hide_event = ui_events.hide[canvas.CANVAS_DEBUG]
      if hide_event then
        ui_events.send_to_role(active_role, hide_event, {})
      end
    end
    runtime.set_client_role(nil)
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
