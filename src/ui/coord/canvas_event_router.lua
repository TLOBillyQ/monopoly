local ui_event_bindings = require("src.ui.coord.event_bindings")
local ui_intent_dispatcher = require("src.ui.input.intent_dispatcher")
local canvas_registry = require("src.ui.input.canvas_route.registry")
local local_actor_resolver = require("src.ui.coord.local_actor_resolver")
local host_runtime_ports = require("src.ui.host_bridge")
local modal = require("src.ui.coord.modal")
local logger = require("src.foundation.log.logger")

local router = {}

local function _market_log(...)
  if type(logger.info_unlimited) == "function" then
    logger.info_unlimited("[MarketDebug]", ...)
    return
  end
  logger.info("[MarketDebug]", ...)
end

local function _is_market_route_name(name)
  return type(name) == "string" and string.match(name, "^黑市") ~= nil
end

local function _is_market_intent(intent)
  local intent_type = intent and intent.type or nil
  return intent_type == "market_select"
    or intent_type == "market_confirm"
    or intent_type == "market_page_prev"
    or intent_type == "market_page_next"
    or intent_type == "market_tab_select"
end

local function _log_market_intent(stage, route_name, data, intent)
  if not _is_market_route_name(route_name) and not _is_market_intent(intent) then
    return
  end
  _market_log(
    stage,
    "node=" .. tostring(route_name),
    "event_role=" .. tostring(data and data.role or nil),
    "intent=" .. tostring(intent and intent.type or nil),
    "choice_id=" .. tostring(intent and intent.choice_id or nil),
    "option_id=" .. tostring(intent and intent.option_id or nil),
    "tab=" .. tostring(intent and intent.tab or nil),
    "actor_role_id=" .. tostring(intent and intent.actor_role_id or nil)
  )
end

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
      modal.close_choice_modal(ctx)
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

  local function _try_attach_event_actor(intent, data, route_name)
    if not _requires_event_actor(intent) or intent.actor_role_id ~= nil then
      return true
    end
    local local_only = intent.type == "toggle_action_log"
      or (intent.type == "ui_button" and intent.id == "auto")
    local actor_role_id
    if local_only then
      actor_role_id = local_actor_resolver.resolve_from_event(state, data, {
        local_only = true,
        trace_auto = false,
      })
    else
      actor_role_id = local_actor_resolver.resolve_turn_bound(state, data)
    end
    if actor_role_id == nil then
      _log_market_intent("attach_event_actor missing", route_name, data, intent)
      host_runtime_ports.enqueue_tip({
        text = "当前操作缺少玩家上下文，已忽略",
        duration = 2.0,
        dedupe_key = "missing_actor:" .. tostring(intent.type) .. ":" .. tostring(intent.id),
        blocks_inter_turn = false,
        source = "ui.missing_actor",
      })
      logger.warn("ui intent rejected: missing actor_role_id", tostring(intent.type), tostring(intent.id))
      return false
    end
    intent.actor_role_id = actor_role_id
    _log_market_intent("attach_event_actor ok", route_name, data, intent)
    return true
  end

  local function dispatch_intent(intent, data, route_name)
    if not _try_attach_event_actor(intent, data, route_name) then
      return
    end
    _log_market_intent("dispatch_intent", route_name, data, intent)
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
      _log_market_intent("node_click", route.name, data, nil)
      local intent = route.build_intent(data)
      _log_market_intent(intent and "build_intent ok" or "build_intent nil", route.name, data, intent)
      if intent then
        dispatch_intent(intent, data, route.name)
      end
    end, registered, listeners)
  end

  ui_event_bindings.enable_action_log_toggle_touch(cache, state.ui)
  ui_event_bindings.register_missing_button_tip(cache, registered, listeners)
end

return router
