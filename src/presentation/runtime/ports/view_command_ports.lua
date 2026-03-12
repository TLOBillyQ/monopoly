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

local function _resolve_toggle_role(state, intent)
  local actor_role_id = role_id_utils.normalize(intent and intent.actor_role_id or nil)
  if actor_role_id == nil then
    logger.warn("toggle_action_log missing actor_role_id")
    return nil, nil, true
  end
  local active_role = actor_context.resolve_role_by_id(actor_role_id)
  local next_enabled = not ui_event_state.resolve_debug_enabled(state, actor_role_id)
  return actor_role_id, active_role, next_enabled
end

local function _can_toggle_action_log(state)
  return state and state.ui ~= nil
end

local function _should_abort_toggle(actor_role_id, next_enabled)
  return next_enabled == true and actor_role_id == nil
end

local function _hide_debug_canvas(active_role)
  local hide_event = ui_events.hide[canvas.CANVAS_DEBUG]
  if hide_event then
    ui_events.send_to_role(active_role, hide_event, {})
  end
end

local function _sync_debug_canvas(ui, active_role, next_enabled)
  if next_enabled then
    canvas.switch_for_role(ui, canvas.CANVAS_DEBUG, active_role)
    return
  end
  _hide_debug_canvas(active_role)
end

local function _warn_missing_debug_channel(active_role, actor_role_id, next_enabled)
  if not next_enabled then
    return
  end
  if type(active_role) == "table" and type(active_role.send_ui_custom_event) == "function" then
    return
  end
  logger.warn("toggle_action_log missing role event channel:", tostring(actor_role_id))
end

local function _toggle_action_log(state, intent)
  if not _can_toggle_action_log(state) then
    return true
  end
  local ui = state.ui
  local actor_role_id, active_role, next_enabled = _resolve_toggle_role(state, intent)
  if _should_abort_toggle(actor_role_id, next_enabled) then
    return true
  end
  debug_view.set_debug_visible_for_role(state, active_role, next_enabled)
  _warn_missing_debug_channel(active_role, actor_role_id, next_enabled)
  _sync_debug_canvas(ui, active_role, next_enabled)
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
