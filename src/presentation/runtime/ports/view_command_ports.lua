local logger = require("src.core.utils.logger")
local role_id_utils = require("src.core.utils.role_id")
local runtime = require("src.presentation.runtime.ui")
local canvas = require("src.presentation.runtime.canvas_coordinator")
local ui_events = require("src.presentation.runtime.events")
local ui_event_state = require("src.presentation.runtime.event_state")
local actor_context = require("src.presentation.runtime.actor_context")
local target_choice_effects = require("src.presentation.runtime.controllers.target_choice_effects")
local market_controller = require("src.presentation.runtime.controllers.market_controller")
local modal_controller = require("src.presentation.runtime.controllers.modal_controller")
local debug_view = require("src.presentation.runtime.view.debug")

local view_command_ports = {}

local function _toggle_action_log(state, intent)
  local ui = state and state.ui or nil
  if not ui then
    return true
  end
  local actor_role_id = role_id_utils.normalize(intent and intent.actor_role_id or nil)
  if actor_role_id == nil then
    logger.warn("toggle_action_log missing actor_role_id")
    return true
  end
  local active_role = actor_context.resolve_role_by_id(actor_role_id)
  local next_enabled = not ui_event_state.resolve_debug_enabled(state, actor_role_id)
  debug_view.set_debug_visible_for_role(state, active_role, next_enabled)
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

function view_command_ports.build()
  return {
    dispatch = function(state, intent)
      local intent_type = intent and intent.type or nil
      if intent_type == nil then
        return false
      end
      if intent_type == "toggle_action_log" then
        return _toggle_action_log(state, intent)
      end
      if intent_type == "market_select" then
        market_controller.select_market_option(state, intent.option_id)
        return true
      end
      if intent_type == "popup_confirm" then
        modal_controller.close_popup(state)
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
    end,
  }
end

return view_command_ports
