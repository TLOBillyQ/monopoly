local ui_event_bindings = require("src.ui.coord.event_bindings")
local ui_intent_dispatcher = require("src.ui.input.intent_dispatcher")
local canvas_registry = require("src.ui.input.canvas_route.registry")
local local_actor_resolver = require("src.ui.coord.local_actor_resolver")
local host_runtime_ports = require("src.ui.host_bridge")
local modal = require("src.ui.coord.modal")
local logger = require("src.foundation.log")

local router = {}

local function _is_actor_bound_ui_button(action_id)
  if action_id == "next" or action_id == "auto" then
    return true
  end
  return type(action_id) == "string" and string.match(action_id, "^item_slot_(%d+)$") ~= nil
end

local _ACTOR_BOUND_TYPES = {
  toggle_action_log = true, open_skin_panel = true, open_gallery_panel = true,
  skin_panel_action = true, item_atlas_action = true, skin_gallery_action = true,
  choice_select = true, choice_cancel = true,
  market_confirm = true, market_page_prev = true, market_page_next = true, market_tab_select = true,
}

local _OPTIONAL_EVENT_ACTOR_TYPES = {
  open_skin_panel = true,
  open_gallery_panel = true,
}

local function _requires_event_actor(intent)
  if type(intent) ~= "table" then return false end
  if _ACTOR_BOUND_TYPES[intent.type] then return true end
  return intent.type == "ui_button" and _is_actor_bound_ui_button(intent.id)
end

local function _unbind(state)
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
  _unbind(state)

  local dispatch_opts = {
    on_close_choice = function(ctx)
      modal.close_choice_modal(ctx)
    end,
  }

  local function _try_attach_event_actor(intent, data)
    if not _requires_event_actor(intent) or intent.actor_role_id ~= nil then
      return true
    end
    local local_only = intent.type == "toggle_action_log"
      or intent.type == "open_skin_panel"
      or intent.type == "open_gallery_panel"
      or intent.type == "skin_panel_action"
      or intent.type == "item_atlas_action"
      or intent.type == "skin_gallery_action"
      or (intent.type == "ui_button" and intent.id == "auto")
    local actor_role_id
    if local_only then
      actor_role_id = local_actor_resolver.resolve_from_event(state, data)
    else
      actor_role_id = local_actor_resolver.resolve_turn_bound(state, data)
    end
    if actor_role_id == nil then
      if _OPTIONAL_EVENT_ACTOR_TYPES[intent.type] then
        return true
      end
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
