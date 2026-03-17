local ui_event_bindings = require("src.ui.ctl.event_bindings")
local ui_intent_dispatcher = require("src.ui.input.intent_dispatcher")
local canvas_registry = require("src.ui.input.canvas_route_registry")
local local_actor_resolver = require("src.ui.ctl.local_actor_resolver")
local host_runtime_ports = require("src.ui.runtime.host_runtime_ports")
local modal_controller = require("src.ui.ctl.modal_controller")
local logger = require("src.core.utils.logger")

local router = {}

local function _is_actor_bound_ui_button(action_id)
  if action_id == "next" or action_id == "auto" then
    return true
  end
  return type(action_id) == "string" and string.match(action_id, "^item_slot_(%d+)$") ~= nil
end

function router.unbind(state)
  if not state then
    return
  end
  local listeners = state.ui_event_router_listeners
  if type(listeners) == "table" then
    for _, listener in ipairs(listeners) do
      if listener and listener.destroy then
        listener:destroy()
      end
    end
  end
  state.ui_event_router_listeners = {}
  state.ui_event_router_registered = {}
end

function router.bind(state, resolve_game)
  assert(state ~= nil, "missing state")
  router.unbind(state)

  local dispatch_opts = {
    on_close_choice = function(ctx)
      modal_controller.close_choice_modal(ctx)
    end,
  }

  local function _requires_event_actor(intent)
    if type(intent) ~= "table" then
      return false
    end
    if intent.type == "toggle_action_log"
        or intent.type == "choice_select"
        or intent.type == "choice_cancel"
        or intent.type == "market_confirm"
        or intent.type == "market_page_prev"
        or intent.type == "market_page_next"
        or intent.type == "market_tab_select"
        or intent.type == "target_lock" then
      return true
    end
    return intent.type == "ui_button" and _is_actor_bound_ui_button(intent.id)
  end

  local function _try_attach_event_actor(intent, data)
    if not _requires_event_actor(intent) or intent.actor_role_id ~= nil then
      return true
    end
    local local_only = intent.type == "toggle_action_log"
      or (intent.type == "ui_button" and intent.id == "auto")
    local actor_role_id = local_actor_resolver.resolve_from_event(state, data, {
      local_only = local_only,
      trace_auto = false,
    })
    if actor_role_id == nil then
      host_runtime_ports.show_tips("当前操作缺少玩家上下文，已忽略", 2.0)
      logger.warn("ui intent rejected: missing actor_role_id", tostring(intent.type), tostring(intent.id))
      return false
    end
    intent.actor_role_id = actor_role_id
    return true
  end

  local function dispatch_intent(intent, data)
    if not _try_attach_event_actor(intent, data) then
      return
    end
    ui_intent_dispatcher.dispatch(state, resolve_game(), intent, dispatch_opts)
  end

  local cache = {}
  local registered = state.ui_event_router_registered or {}
  state.ui_event_router_registered = registered
  local listeners = state.ui_event_router_listeners or {}
  state.ui_event_router_listeners = listeners

  local route_specs = canvas_registry.build_route_specs(state)
  for _, route in ipairs(route_specs) do
    ui_event_bindings.register_node_click(cache, route.name, function(data)
      local intent = route.build_intent(data)
      if intent then
        dispatch_intent(intent, data)
      end
    end, registered, listeners)
  end

  ui_event_bindings.enable_action_log_toggle_touch(cache, state.ui)
  ui_event_bindings.register_missing_button_tip(cache, registered, listeners)
end

return router
