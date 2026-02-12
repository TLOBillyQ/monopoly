local market_ui = require("src.presentation.shared.MarketLayout")
local turn_dispatch = require("src.game.turn.TurnDispatch")
local ui_view = require("src.presentation.api.UIView")
local runtime = require("src.presentation.api.UIRuntimePort")
local logger = require("src.core.Logger")
local gameplay_rules = require("Config.GameplayRules")

local ui_event_router = {}

local missing_button_tips = {}

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

local function _is_base_screen_active(state)
  local ui = state and state.ui
  if not ui then
    return false
  end
  if ui.market_active or ui.choice_active or ui.popup_active then
    return false
  end
  return true
end

local function _resolve_debug_enabled(state)
  local ui = state and state.ui
  if ui and ui.debug_log_enabled_override ~= nil then
    return ui.debug_log_enabled_override == true
  end
  return gameplay_rules.debug_log_enabled == true
end

local function _toggle_debug_visible(state)
  local ui = state and state.ui
  if not ui then
    return
  end
  local next_enabled = not _resolve_debug_enabled(state)
  ui.debug_log_enabled_override = next_enabled
  ui_view.set_debug_visible(state, next_enabled)
end

local function _record_debug_toggle_click(state)
  local ui = state and state.ui
  local base_active = _is_base_screen_active(state)
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
      "current=" .. tostring(_resolve_debug_enabled(state))
    )
    _toggle_debug_visible(state)
    logger.info(
      "[调试屏] 切换完成",
      "next=" .. tostring(_resolve_debug_enabled(state))
    )
  end
end

local function _resolve_option_id(choice, payload, state)
  assert(choice ~= nil, "missing choice")
  assert(payload ~= nil, "missing payload")
  local option_id = payload.option_id or payload.option or nil
  if option_id then
    return option_id
  end
  local index = payload.index or payload.option_index or payload.card_index or payload.choice_index
  if index then
    local mapped = state and state.choice_visible_option_ids and state.choice_visible_option_ids[index]
    if mapped then
      return mapped
    end
    local options = choice.options
    if type(options) ~= "table" then
      return nil
    end
    local option = options[index]
    if option then
      return option.id or option
    end
  end
  return nil
end

local function _show_missing_button_tip(name)
  if missing_button_tips[name] then
    return
  end
  missing_button_tips[name] = true
  GlobalAPI.show_tips("UI 节点未适配: " .. tostring(name), 2.0)
end

local function _choice_cancel_intent(state, warn_label)
  local choice = state.ui_model and state.ui_model.choice or nil
  if not choice then
    logger.warn(warn_label .. " without choice")
    return nil
  end
  if choice.allow_cancel == false then
    return nil
  end
  return { type = "choice_cancel", choice_id = choice.id }
end

local function _choice_select_intent(state, index, warn_label)
  local choice = state.ui_model and state.ui_model.choice or nil
  if not choice then
    logger.warn(warn_label .. " without choice")
    return nil
  end
  local option_id = _resolve_option_id(choice, { index = index }, state)
  if not option_id then
    logger.warn(warn_label .. " missing option:", tostring(index))
    return nil
  end
  return {
    type = "choice_select",
    choice_id = choice.id,
    option_id = option_id,
  }
end

local function _choice_confirm_intent(state, warn_label)
  local choice = state.ui_model and state.ui_model.choice or nil
  if not choice then
    logger.warn(warn_label .. " without choice")
    return nil
  end
  local option_id = state.pending_choice_selected_option_id
  if option_id == nil and type(state.choice_visible_option_ids) == "table" then
    option_id = state.choice_visible_option_ids[1]
  end
  if option_id == nil then
    logger.warn(warn_label .. " missing selected option")
    return nil
  end
  return {
    type = "choice_select",
    choice_id = choice.id,
    option_id = option_id,
  }
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

local function _register_node_click(cache, name, callback, registered, listeners)
  assert(name ~= nil, "missing node name")
  assert(type(callback) == "function", "missing callback")
  assert(registered ~= nil, "missing registered map")
  assert(listeners ~= nil, "missing listeners list")
  if registered[name] then
    return
  end
  local nodes = cache[name]
  if not nodes then
    local ok, result = pcall(runtime.query_nodes, name)
    if not ok then
      _show_missing_button_tip(name)
      if name == "图片_82" then
        logger.info("[调试屏] 图片_82注册失败: query_nodes异常")
      end
      return
    end
    nodes = result
    cache[name] = nodes
  end
  if not nodes or not nodes[1] then
    _show_missing_button_tip(name)
    if name == "图片_82" then
      logger.info("[调试屏] 图片_82注册失败: 未找到节点")
    end
    return
  end
  if name == "图片_82" then
    logger.info("[调试屏] 图片_82注册成功", "nodes=" .. tostring(#nodes))
  end
  registered[name] = true
  for _, node in ipairs(nodes) do
    local listener = node:listen(UIManager.EVENT.CLICK, function(data)
      callback(data)
    end)
    table.insert(listeners, listener)
  end
end

local function _enable_debug_toggle_touch(cache)
  local nodes = cache and cache["图片_82"] or nil
  if not nodes or not nodes[1] then
    local ok, result = pcall(runtime.query_nodes, "图片_82")
    if not ok then
      logger.info("[调试屏] 图片_82触控启用失败: query_nodes异常")
      return
    end
    nodes = result
  end
  if not nodes or not nodes[1] then
    logger.info("[调试屏] 图片_82触控启用失败: 未找到节点")
    return
  end
  runtime.for_each_role_or_global(function()
    for _, node in ipairs(nodes) do
      node.disabled = false
    end
  end)
  runtime.set_client_role(nil)
  logger.info("[调试屏] 图片_82触控已启用", "nodes=" .. tostring(#nodes))
end

local function _should_block_intent(state, intent)
  if turn_dispatch.should_block_action then
    return turn_dispatch.should_block_action(state, intent)
  end
  return false
end

local function _dispatch(state, game, intent, opts)
  assert(intent ~= nil, "missing intent")
  local intent_type = intent.type
  if _should_block_intent(state, intent) then
    return
  end
  if not game then
    logger.warn("ui intent without game:", tostring(intent_type))
    return
  end

  if intent_type == "ui_button"
      or intent_type == "choice_select"
      or intent_type == "choice_cancel" then
    turn_dispatch.dispatch_action(game, state, intent, opts)
    return
  end

  if intent_type == "market_confirm" then
    if not intent.choice_id or not intent.option_id then
      logger.warn("market_confirm missing ids:", tostring(intent.choice_id), tostring(intent.option_id))
      return
    end
    turn_dispatch.dispatch_action(game, state, {
      type = "choice_select",
      choice_id = intent.choice_id,
      option_id = intent.option_id,
    }, opts)
    return
  end

  if intent_type == "market_select" then
    ui_view.select_market_option(state, intent.option_id)
    return
  end

  if intent_type == "popup_confirm" then
    ui_view.close_popup(state)
  end
end

local function _build_route_specs(state)
  local specs = {
    {
      name = "行动按钮",
      build_intent = function()
        return { type = "ui_button", id = "next" }
      end,
    },
    {
      name = "托管按钮",
      build_intent = function()
        return { type = "ui_button", id = "auto" }
      end,
    },
    {
      name = market_ui.confirm_button,
      build_intent = function()
        local market = state.ui_model and state.ui_model.market or nil
        if not market then
          logger.warn("market_confirm without market")
          return nil
        end
        local option_id = state.pending_choice_selected_option_id
        if not option_id then
          logger.warn("market_confirm missing selected option")
          return nil
        end
        return { type = "market_confirm", choice_id = market.choice_id, option_id = option_id }
      end,
    },
    {
      name = market_ui.cancel_button,
      build_intent = function()
        return _choice_cancel_intent(state, "market_cancel")
      end,
    },
    {
      name = "关闭",
      build_intent = function()
        return _choice_cancel_intent(state, "market_close")
      end,
    },
    {
      name = "取消按钮",
      build_intent = function()
        if state.ui and state.ui.popup_active then
          return { type = "popup_confirm" }
        end
        return _choice_cancel_intent(state, "choice_cancel")
      end,
    },
    {
      name = "建筑升级_确定按钮",
      build_intent = function()
        return _choice_confirm_intent(state, "building_confirm")
      end,
    },
    {
      name = "建筑升级_取消",
      build_intent = function()
        return _choice_cancel_intent(state, "building_cancel")
      end,
    },
    {
      name = "遥控骰子_取消",
      build_intent = function()
        return _choice_cancel_intent(state, "remote_cancel")
      end,
    },
  }

  local popup = state.ui and state.ui.popup_screen or nil
  local dismiss_nodes = popup and popup.dismiss_nodes or nil
  if type(dismiss_nodes) == "table" then
    for _, name in ipairs(dismiss_nodes) do
      specs[#specs + 1] = {
        name = name,
        build_intent = function()
          if state.ui and state.ui.popup_active then
            return { type = "popup_confirm" }
          end
          return nil
        end,
      }
    end
  end

  local item_slots = (state.ui and state.ui.item_slots) or {}
  if #item_slots == 0 then
    item_slots = { "道具槽位1", "道具槽位2", "道具槽位3", "道具槽位4", "道具槽位5" }
  end
  for index, node_name in ipairs(item_slots) do
    local action_id = "item_slot_" .. tostring(index)
    specs[#specs + 1] = {
      name = node_name,
      build_intent = function()
        local choice = state.ui_model and state.ui_model.choice or nil
        if not choice or choice.kind ~= "item_phase_choice" then
          logger.warn("item_slot click ignored:", tostring(index))
          return nil
        end
        return { type = "ui_button", id = action_id }
      end,
    }
  end

  local player_nodes = {
    "玩家选择_槽位1",
    "玩家选择_槽位2",
    "玩家选择_槽位3",
  }
  for index, name in ipairs(player_nodes) do
    specs[#specs + 1] = {
      name = name,
      build_intent = function()
        return _choice_select_intent(state, index, "player_select")
      end,
    }
  end

  local target_nodes = {
    "位置前1",
    "位置前2",
    "位置前3",
    "位置后1",
    "位置后2",
    "位置后3",
    "位置脚下",
  }
  for index, name in ipairs(target_nodes) do
    specs[#specs + 1] = {
      name = name,
      build_intent = function()
        return _choice_select_intent(state, index, "target_select")
      end,
    }
  end

  local remote_nodes = {
    "遥控骰子_选项_01",
    "遥控骰子_选项_02",
    "遥控骰子_选项_03",
    "遥控骰子_选项_04",
    "遥控骰子_选项_05",
    "遥控骰子_选项_06",
  }
  for index, name in ipairs(remote_nodes) do
    specs[#specs + 1] = {
      name = name,
      build_intent = function()
        local choice = state.ui_model and state.ui_model.choice or nil
        if not choice then
          logger.warn("remote_select without choice")
          return nil
        end
        local option_id = _resolve_option_id(choice, { index = index }, state)
        if not option_id then
          logger.warn("remote_select missing option:", tostring(index))
          return nil
        end
        return { type = "choice_select", choice_id = choice.id, option_id = option_id }
      end,
    }
  end

  for index, name in ipairs(market_ui.item_buttons) do
    specs[#specs + 1] = {
      name = name,
      build_intent = function()
        if not market_ui.is_ready() then
          logger.warn("market ui not ready")
          return nil
        end
        local market = state.ui_model and state.ui_model.market or nil
        if not market then
          logger.warn("market_select without market")
          return nil
        end
        local option_id = _resolve_option_id(market, { index = index }, state)
        if not option_id then
          logger.warn("market_select missing option:", tostring(index))
          return nil
        end
        return { type = "market_select", option_id = option_id }
      end,
    }
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
    _dispatch(state, resolve_game(), intent, dispatch_opts)
  end

  local cache = {}
  local registered = state.ui_event_router_registered or {}
  state.ui_event_router_registered = registered
  local listeners = state.ui_event_router_listeners or {}
  state.ui_event_router_listeners = listeners

  local route_specs = _build_route_specs(state)
  for _, route in ipairs(route_specs) do
    _register_node_click(cache, route.name, function(data)
      local intent = route.build_intent(data)
      if intent then
        dispatch_intent(intent, data)
      end
    end, registered, listeners)
  end

  _register_node_click(cache, "图片_82", function()
    _record_debug_toggle_click(state)
  end, registered, listeners)
  _enable_debug_toggle_touch(cache)

  local nodes = require("Data.UIManagerNodes")
  for _, entry in pairs(nodes) do
    local name = entry[1]
    local kind = entry[2]
    if kind == "EButton" and not registered[name] then
      _register_node_click(cache, name, function()
        _show_missing_button_tip(name)
      end, registered, listeners)
    end
  end
end

return ui_event_router
