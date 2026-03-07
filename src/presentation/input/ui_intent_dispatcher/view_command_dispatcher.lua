local logger = require("src.core.utils.logger")
local runtime = require("src.presentation.runtime.ui_runtime_port")
local ui_view = require("src.presentation.runtime.ui_view_service")
local canvas = require("src.presentation.input.ui_canvas_coordinator")
local ui_events = require("src.presentation.runtime.ui_events")
local ui_event_state = require("src.presentation.input.ui_event_state")
local role_context = require("src.presentation.input.ui_intent_dispatcher.role_context")
local target_choice_effects = require("src.presentation.view.render.target_choice_effects")
local role_id_utils = require("src.core.utils.role_id")

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
    actor_role_id = role_id_utils.normalize(actor_role_id)
    if actor_role_id == nil then
      logger.warn("toggle_action_log missing actor_role_id")
      return true
    end
    local active_role = role_context.resolve_by_id(actor_role_id)
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

  if intent_type == "target_unlock" then
    target_choice_effects.on_unlock(state)
    return true
  end

  if intent_type == "target_lock" then
    target_choice_effects.on_scene_pick(state, intent.option_id, intent.actor_role_id, {
      option_id = intent.option_id,
      actor_role_id = intent.actor_role_id,
    })
    return true
  end

  return false
end

return view_command_dispatcher
