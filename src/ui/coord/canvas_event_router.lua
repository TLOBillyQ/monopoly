local ui_event_bindings = require("src.ui.coord.event_bindings")
local ui_intent_dispatcher = require("src.ui.input.intent_dispatcher")
local canvas_registry = require("src.ui.input.routes")
local event_actor_policy = require("src.ui.coord.event_actor_policy")
local modal = require("src.ui.coord.modal")
local base_nodes = require("src.ui.schema.base")

local router = {}

local function _destroy_listener(listener)
  if listener and listener.destroy then
    listener:destroy()
  end
end

local function _unbind(state)
  local listeners = state.ui_event_router_listeners
  if type(listeners) == "table" then
    for _, listener in ipairs(listeners) do
      _destroy_listener(listener)
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

  local function dispatch_intent(intent, data)
    if not event_actor_policy.attach_event_actor(state, intent, data) then
      return
    end
    ui_intent_dispatcher.dispatch(state, resolve_game(), intent, dispatch_opts)
  end

  local cache = {}
  local registered = {}
  state.ui_event_router_registered = registered
  local listeners = {}
  state.ui_event_router_listeners = listeners

  local route_specs = canvas_registry.build_route_specs(state)
  for _, route in ipairs(route_specs) do
    local route_name = route.name
    ui_event_bindings.register_node_click(cache, route_name, function(data)
      local intent = route.build_intent(data)
      if intent then
        dispatch_intent(intent, data)
      end
    end, registered, listeners, {
      bind_client_role = route_name ~= base_nodes.action_log_button,
    })
  end

  ui_event_bindings.enable_action_log_toggle_touch(cache, state.ui)
  ui_event_bindings.register_missing_button_tip(cache, registered, listeners)
end

return router

--[[ mutate4lua-manifest
version=2
projectHash=40fb582155f7eecd
scope.0.id=chunk:src/ui/coord/canvas_event_router.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=68
scope.0.semanticHash=3646867791eaaa6e
scope.0.lastMutatedAt=2026-05-25T13:21:39Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=18
scope.0.lastMutationKilled=18
scope.1.id=function:_destroy_listener:10
scope.1.kind=function
scope.1.startLine=10
scope.1.endLine=14
scope.1.semanticHash=85f40aabb110032c
scope.1.lastMutatedAt=2026-05-25T13:21:39Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=2
scope.1.lastMutationKilled=2
scope.2.id=function:anonymous@32:32
scope.2.kind=function
scope.2.startLine=32
scope.2.endLine=34
scope.2.semanticHash=ac0e292eb1e2aa57
scope.2.lastMutatedAt=2026-05-25T13:21:39Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=1
scope.2.lastMutationKilled=1
scope.3.id=function:dispatch_intent:37
scope.3.kind=function
scope.3.startLine=37
scope.3.endLine=42
scope.3.semanticHash=40301c9230a8c153
scope.3.lastMutatedAt=2026-05-25T13:21:39Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=3
scope.3.lastMutationKilled=3
scope.4.id=function:anonymous@53:53
scope.4.kind=function
scope.4.startLine=53
scope.4.endLine=58
scope.4.semanticHash=71278c5c84d5bd25
scope.4.lastMutatedAt=2026-05-25T13:21:39Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=no_sites
scope.4.lastMutationSites=0
scope.4.lastMutationKilled=0
]]
