local ui_event_bindings = require("src.ui.coord.event_bindings")
local ui_intent_dispatcher = require("src.ui.input.intent_dispatcher")
local canvas_registry = require("src.ui.input.canvas_route.registry")
local local_actor_resolver = require("src.ui.coord.local_actor_resolver")
local host_runtime_ports = require("src.ui.host_bridge")
local modal = require("src.ui.coord.modal")
local logger = require("src.foundation.log.logger")
local runtime_ui = require("src.ui.render.runtime_ui")

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

  local function _try_attach_event_actor(intent, data)
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
    logger.info("[diag-firsttap] router.dispatch_intent", tostring(intent and intent.type), tostring(intent and intent.id))
    if not _try_attach_event_actor(intent, data) then
      logger.info("[diag-firsttap] router.dispatch_intent rejected by actor")
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
      logger.info("[diag-firsttap] node clicked:", tostring(route.name))
      local intent = route.build_intent(data)
      if intent then
        dispatch_intent(intent, data)
      else
        logger.info("[diag-firsttap] build_intent returned nil for", tostring(route.name))
      end
    end, registered, listeners)
  end

  ui_event_bindings.enable_action_log_toggle_touch(cache, state.ui)
  ui_event_bindings.register_missing_button_tip(cache, registered, listeners)

  local function _diag_parent_chain(node)
    local names = {}
    local cur = node
    for _ = 1, 8 do
      if not cur then
        break
      end
      names[#names + 1] = tostring(cur.name or cur.id or cur)
      cur = cur.parent
    end
    return table.concat(names, " <- ")
  end
  local ok_data, all_nodes = pcall(require, "Data.UIManagerNodes")
  if ok_data and type(all_nodes) == "table" then
    for _, entry in pairs(all_nodes) do
      if type(entry) == "table" then
        local name = entry[1]
        local kind = entry[2]
        local ok, nodes = pcall(runtime_ui.query_nodes, name)
        if ok and type(nodes) == "table" then
          for _, node in ipairs(nodes) do
            local listener_ok, listener = pcall(function()
              return node:listen(UIManager.EVENT.CLICK, function(data)
                logger.info(
                  "[diag-firsttap-consumer]",
                  "name=" .. tostring(node.name or name),
                  "kind=" .. tostring(kind),
                  "id=" .. tostring(node.id),
                  "visible=" .. tostring(node.visible),
                  "disabled=" .. tostring(node.disabled),
                  "role=" .. tostring(data and data.role),
                  "chain=" .. _diag_parent_chain(node)
                )
              end)
            end)
            if listener_ok and listener then
              table.insert(listeners, listener)
            end
          end
        end
      end
    end
  end
end

return router
