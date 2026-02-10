local market_ui = require("src.ui.MarketLayout")
local turn_dispatch = require("src.game.turn.TurnDispatch")
local ui_view = require("src.ui.UIView")
local runtime = require("src.ui.UIRuntimePort")
local logger = require("src.core.Logger")

local ui_event_router = {}

local missing_button_tips = {}

local function _resolve_option_id(choice, payload, state)
  assert(choice ~= nil, "missing choice")
  assert(payload ~= nil, "missing payload")
  local option_id = payload.option_id or payload.option or nil
  if option_id then
    return option_id
  end
  local index = payload.index or payload.option_index or payload.card_index or payload.choice_index
  if index then
    local mapped = state and state.market_choice_option_ids and state.market_choice_option_ids[index]
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

local function _resolve_actor_role_id(data)
  if not data or not data.role then
    return nil
  end
  return runtime.resolve_role_id(data.role)
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
      return
    end
    nodes = result
    cache[name] = nodes
  end
  if not nodes or not nodes[1] then
    _show_missing_button_tip(name)
    return
  end
  registered[name] = true
  for _, node in ipairs(nodes) do
    local listener = node:listen(UIManager.EVENT.CLICK, function(data)
      callback(data)
    end)
    table.insert(listeners, listener)
  end
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
      name = "弹窗确认",
      build_intent = function()
        return { type = "popup_confirm" }
      end,
    },
    {
      name = "通用选择_取消",
      build_intent = function()
        return _choice_cancel_intent(state, "choice_cancel")
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
  }

  local market_close = "关闭"
  if market_ui.cancel_button ~= market_close then
    specs[#specs + 1] = {
      name = market_close,
      build_intent = function()
        return _choice_cancel_intent(state, "market_close")
      end,
    }
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

  local choice_option_nodes = state.ui and state.ui.choice and state.ui.choice.option_buttons or nil
  if type(choice_option_nodes) ~= "table" or #choice_option_nodes == 0 then
    choice_option_nodes = {
      "通用选择_选项_01",
      "通用选择_选项_02",
      "通用选择_选项_03",
      "通用选择_选项_04",
      "通用选择_选项_05",
      "通用选择_选项_06",
    }
  end
  for index, name in ipairs(choice_option_nodes) do
    specs[#specs + 1] = {
      name = name,
      build_intent = function()
        local choice = state.ui_model and state.ui_model.choice or nil
        if not choice then
          logger.warn("choice_select without choice")
          return nil
        end
        local option_id = _resolve_option_id(choice, { index = index }, state)
        if not option_id then
          logger.warn("choice_select missing option:", tostring(index))
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
