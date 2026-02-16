local runtime = require("visual.runtime")
local ui_view = require("visual.view")
local ui_event_bindings = require("visual.control.binding")
local ui_intent_builder = require("visual.control.builder")
local ui_intent_dispatcher = require("visual.control.dispatch")

local ui_event_router = {}

local function _resolve_actor_role_id(data)
  local role = data and data.role or nil
  if not role then
    role = runtime.get_client_role()
  end
  if not role then
    return nil
  end
  return runtime.resolve_role_id(role)
end

local function _build_default_route_specs(state)
  local specs = {}

  local function _append(list)
    for _, spec in ipairs(list or {}) do
      specs[#specs + 1] = spec
    end
  end

  _append(ui_intent_builder.build_basic_intents(state))
  _append(ui_intent_builder.build_action_log_intents(state))
  _append(ui_intent_builder.build_popup_intents(state))
  _append(ui_intent_builder.build_item_slot_intents(state))
  _append(ui_intent_builder.build_player_intents(state))
  _append(ui_intent_builder.build_target_intents(state))
  _append(ui_intent_builder.build_remote_intents(state))
  _append(ui_intent_builder.build_market_item_intents(state))

  return specs
end

function ui_event_router.unbind(state)
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

function ui_event_router.bind(state, get_game)
  assert(state ~= nil, "missing state")
  local function resolve_game()
    if type(get_game) == "function" then
      return get_game()
    end
    return get_game
  end

  local dispatch_opts = {
    on_close_choice = function(ctx)
      ui_view.close_choice_modal(ctx)
    end,
  }

  ui_event_router.unbind(state)

  local function dispatch_intent(intent, data)
    if intent and intent.actor_role_id == nil then
      intent.actor_role_id = _resolve_actor_role_id(data)
    end
    ui_intent_dispatcher.dispatch(state, resolve_game(), intent, dispatch_opts)
  end

  local cache = {}
  local registered = state.ui_event_router_registered or {}
  state.ui_event_router_registered = registered
  local listeners = state.ui_event_router_listeners or {}
  state.ui_event_router_listeners = listeners

  local route_specs = _build_default_route_specs(state)
  for _, route in ipairs(route_specs) do
    ui_event_bindings.register_node_click(cache, route.name, function(data)
      local intent = route.build_intent(data)
      if intent then
        dispatch_intent(intent, data)
      end
    end, registered, listeners)
  end
  ui_event_bindings.enable_action_log_toggle_touch(cache)
  ui_event_bindings.register_missing_button_tip(cache, registered, listeners)
end

return ui_event_router
