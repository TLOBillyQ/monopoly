local runtime = require("src.presentation.api.UIRuntimePort")
local ui_view = require("src.presentation.api.UIView")
local logger = require("src.core.Logger")
local ui_event_bindings = require("src.presentation.interaction.UIEventBindings")
local ui_event_state = require("src.presentation.interaction.UIEventState")
local ui_intent_builder = require("src.presentation.interaction.UIIntentBuilder")
local ui_intent_dispatcher = require("src.presentation.interaction.UIIntentDispatcher")

local ui_event_router = {}

local function _get_timestamp()
  assert(GameAPI ~= nil and GameAPI.get_timestamp ~= nil, "missing GameAPI.get_timestamp")
  local timestamp = GameAPI.get_timestamp()
  assert(type(timestamp) == "number", "invalid timestamp")
  return timestamp
end

local function _get_timestamp_diff_seconds(timestamp_1, timestamp_2)
  assert(GameAPI ~= nil and GameAPI.get_timestamp_diff ~= nil, "missing GameAPI.get_timestamp_diff")
  assert(type(timestamp_1) == "number" and type(timestamp_2) == "number", "invalid timestamps")
  return GameAPI.get_timestamp_diff(timestamp_1, timestamp_2)
end

local function _toggle_debug_visible(state)
  local ui = state and state.ui
  if not ui then
    return
  end
  ui.debug_log_enabled_override = nil
  local next_enabled = not ui_event_state.resolve_debug_enabled(state)
  ui_view.set_debug_visible(state, next_enabled)
end

local function _toggle_debug_visible_for_role(state, role)
  local ui = state and state.ui
  if not ui then
    return
  end
  local previous_role = UIManager and UIManager.client_role or nil
  if UIManager then
    UIManager.client_role = role or previous_role
  end
  ui.debug_log_enabled_override = nil
  local next_enabled = not ui_event_state.resolve_debug_enabled(state)
  ui_view.set_debug_visible(state, next_enabled)
  if UIManager then
    UIManager.client_role = previous_role
  end
end
local function _record_debug_toggle_click(state, role)
  local ui = state and state.ui
  local base_active = ui_event_state.is_base_screen_active(state)
  local input_blocked = ui and ui.input_blocked or false
  if not base_active then
    logger.info("[调试屏] 图片_82点击忽略: 非基础屏", "input_blocked=" .. tostring(input_blocked))
    return
  end
  local now = _get_timestamp()
  local first_click = ui.debug_toggle_first_click_timestamp
  local click_count = ui.debug_toggle_click_count or 0
  logger.info(
    "[调试屏] 图片_82点击",
    "now=" .. tostring(now),
    "first=" .. tostring(first_click),
    "count=" .. tostring(click_count),
    "input_blocked=" .. tostring(input_blocked)
  )
  if first_click ~= nil then
    local diff = _get_timestamp_diff_seconds(now, first_click)
    logger.info("[调试屏] 图片_82时间差", "diff=" .. tostring(diff))
    if diff > 3 then
      first_click = now
      click_count = 0
      logger.info("[调试屏] 图片_82计数重置")
    end
  else
    first_click = now
  end
  click_count = click_count + 1
  ui.debug_toggle_first_click_timestamp = first_click
  ui.debug_toggle_click_count = click_count
  logger.info(
    "[调试屏] 图片_82计数更新",
    "first=" .. tostring(first_click),
    "count=" .. tostring(click_count)
  )
  if click_count >= 10 then
    ui.debug_toggle_first_click_timestamp = nil
    ui.debug_toggle_click_count = 0
    logger.info(
      "[调试屏] 触发显隐切换",
      "current=" .. tostring(ui_event_state.resolve_debug_enabled(state))
    )
    _toggle_debug_visible_for_role(state, role)
    logger.info(
      "[调试屏] 切换完成",
      "next=" .. tostring(ui_event_state.resolve_debug_enabled(state))
    )
  end
end

local function _resolve_actor_role_id(data)
  local role = data and data.role or nil
  if not role and UIManager and UIManager.client_role then
    role = UIManager.client_role
  end
  if not role then
    return nil
  end
  return runtime.resolve_role_id(role)
end


local function _build_route_specs(state)
  local specs = {}

  local base_specs = ui_intent_builder.build_basic_intents(state)
  for _, spec in ipairs(base_specs) do
    specs[#specs + 1] = spec
  end
  specs[#specs + 1] = {
    name = "基础_行动日志按钮",
    build_intent = function(data)
      _toggle_debug_visible_for_role(state, data and data.role or nil)
      return nil
    end,
  }

  local popup_specs = ui_intent_builder.build_popup_intents(state)
  for _, spec in ipairs(popup_specs) do
    specs[#specs + 1] = spec
  end
  local item_specs = ui_intent_builder.build_item_slot_intents(state)
  for _, spec in ipairs(item_specs) do
    specs[#specs + 1] = spec
  end
  local player_specs = ui_intent_builder.build_player_intents(state)
  for _, spec in ipairs(player_specs) do
    specs[#specs + 1] = spec
  end
  local target_specs = ui_intent_builder.build_target_intents(state)
  for _, spec in ipairs(target_specs) do
    specs[#specs + 1] = spec
  end
  local remote_specs = ui_intent_builder.build_remote_intents(state)
  for _, spec in ipairs(remote_specs) do
    specs[#specs + 1] = spec
  end
  local market_specs = ui_intent_builder.build_market_item_intents(state)
  for _, spec in ipairs(market_specs) do
    specs[#specs + 1] = spec
  end

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

  local route_specs = _build_route_specs(state)
  for _, route in ipairs(route_specs) do
    ui_event_bindings.register_node_click(cache, route.name, function(data)
      local intent = route.build_intent(data)
      if intent then
        dispatch_intent(intent, data)
      end
    end, registered, listeners)
  end

  ui_event_bindings.register_node_click(cache, "图片_82", function(data)
    _record_debug_toggle_click(state, data and data.role or nil)
  end, registered, listeners)
  ui_event_bindings.enable_debug_toggle_touch(cache)
  ui_event_bindings.register_missing_button_tip(cache, registered, listeners)
end

return ui_event_router
