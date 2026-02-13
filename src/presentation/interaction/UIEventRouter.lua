local runtime = require("src.presentation.api.UIRuntimePort")
local ui_view = require("src.presentation.api.UIView")
local ui_event_bindings = require("src.presentation.interaction.UIEventBindings")
local ui_event_state = require("src.presentation.interaction.UIEventState")
local ui_intent_builder = require("src.presentation.interaction.UIIntentBuilder")
local ui_intent_dispatcher = require("src.presentation.interaction.UIIntentDispatcher")

local ui_event_router = {}

local function _toggle_debug_visible_for_role(state, role)
  local ui = state and state.ui
  if not ui then
    return
  end
  local active_role = role or runtime.get_client_role()
  runtime.with_client_role(active_role, function()
    ui.debug_log_enabled_override = nil
    local next_enabled = not ui_event_state.resolve_debug_enabled(state)
    ui_view.set_debug_visible(state, next_enabled)
  end)
end

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
  _append({
    {
      name = "基础_行动日志按钮",
      build_intent = function(data)
        _toggle_debug_visible_for_role(state, data and data.role or nil)
        return nil
      end,
    },
  })
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
  ui_event_bindings.enable_debug_toggle_touch(cache)
  ui_event_bindings.register_missing_button_tip(cache, registered, listeners)
end

return ui_event_router
