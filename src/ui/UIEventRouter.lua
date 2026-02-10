local ui_aliases = require("src.ui.UIAliases")
local market_ui = require("src.ui.MarketLayout")
local turn_dispatch = require("src.game.turn.TurnDispatch")
local ui_view = require("src.ui.UIView")
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
  local idx = payload.index or payload.option_index or payload.card_index or payload.choice_index
  if idx then
    local mapped = state and state.market_choice_option_ids and state.market_choice_option_ids[idx]
    if mapped then
      return mapped
    end
    local options = choice.options
    if type(options) ~= "table" then
      return nil
    end
    local opt = options[idx]
    if opt then
      return opt.id or opt
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

local function _resolve_actor_role_id(data)
  if not data or not data.role or not data.role.get_roleid then
    return nil
  end
  local ok, role_id = pcall(data.role.get_roleid)
  if not ok then
    return nil
  end
  return role_id
end

local function _register_node_click(cache, name, callback, registered, listeners)
  assert(name ~= nil, "missing node name")
  assert(registered ~= nil, "missing registered map")
  assert(listeners ~= nil, "missing listeners list")
  local resolved = ui_aliases.resolve(name)
  if registered[resolved] then
    return
  end
  local nodes = cache[resolved]
  if not nodes then
    nodes = UIManager.query_nodes_by_name(resolved)
    cache[resolved] = nodes
  end
  if not nodes or not nodes[1] then
    _show_missing_button_tip(name)
    return
  end
  registered[resolved] = true
  for _, node in ipairs(nodes) do
    local listener = node:listen(UIManager.EVENT.CLICK, function(data)
      callback(data)
    end)
    table.insert(listeners, listener)
  end
end

local function _should_block_intent(state, intent_type)
  if turn_dispatch.should_block_action then
    return turn_dispatch.should_block_action(state, intent_type)
  end
  return false
end

local function _dispatch(state, game, intent, opts)
  assert(intent ~= nil, "missing intent")
  local intent_type = intent.type
  if _should_block_intent(state, intent_type) then
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

function ui_event_router.bind(state, get_game, opts)
  assert(state ~= nil, "missing state")
  local function resolve_game()
    if type(get_game) == "function" then
      return get_game()
    end
    return get_game
  end

  if not opts then
    opts = {}
  end
  if not opts.on_close_choice then
    opts.on_close_choice = function(ctx)
      ui_view.close_choice_modal(ctx)
    end
  end

  ui_event_router.unbind(state)

  local function dispatch_intent(intent, data)
    if intent and intent.actor_role_id == nil then
      intent.actor_role_id = _resolve_actor_role_id(data)
    end
    _dispatch(state, resolve_game(), intent, opts)
  end

  local cache = {}
  local registered = state.ui_event_router_registered or {}
  state.ui_event_router_registered = registered
  local listeners = state.ui_event_router_listeners or {}
  state.ui_event_router_listeners = listeners
  _register_node_click(cache, "行动按钮", function(data)
    dispatch_intent({ type = "ui_button", id = "next" }, data)
  end, registered, listeners)
  _register_node_click(cache, "托管按钮", function(data)
    dispatch_intent({ type = "ui_button", id = "auto" }, data)
  end, registered, listeners)
  for idx = 1, 5 do
    local node_name = "道具槽位" .. tostring(idx)
    local action_id = "item_slot_" .. tostring(idx)
    _register_node_click(cache, node_name, function(data)
      local choice = state.ui_model and state.ui_model.choice
      if not choice or choice.kind ~= "item_phase_choice" then
        logger.warn("item_slot click ignored:", tostring(idx))
        return
      end
      dispatch_intent({ type = "ui_button", id = action_id }, data)
    end, registered, listeners)
  end
  _register_node_click(cache, "弹窗确认", function(data)
    dispatch_intent({ type = "popup_confirm" }, data)
  end, registered, listeners)

  _register_node_click(cache, "通用选择_取消", function(data)
    local choice = state.ui_model and state.ui_model.choice
    if not choice then
      logger.warn("choice_cancel without choice")
      return
    end
    if choice.allow_cancel ~= false then
      dispatch_intent({ type = "choice_cancel", choice_id = choice.id }, data)
    end
  end, registered, listeners)

  for idx, name in ipairs({
    "通用选择_选项_01",
    "通用选择_选项_02",
    "通用选择_选项_03",
    "通用选择_选项_04",
    "通用选择_选项_05",
    "通用选择_选项_06",
  }) do
    _register_node_click(cache, name, function(data)
      local choice = state.ui_model and state.ui_model.choice
      if not choice then
        logger.warn("choice_select without choice")
        return
      end
      local option_id = _resolve_option_id(choice, { index = idx }, state)
      if not option_id then
        logger.warn("choice_select missing option:", tostring(idx))
        return
      end
      dispatch_intent({ type = "choice_select", choice_id = choice.id, option_id = option_id }, data)
    end, registered, listeners)
  end

  for idx, name in ipairs(market_ui.item_buttons) do
    _register_node_click(cache, name, function(data)
      if not market_ui.is_ready() then
        logger.warn("market ui not ready")
        return
      end
      local market = state.ui_model and state.ui_model.market
      if not market then
        logger.warn("market_select without market")
        return
      end
      local option_id = _resolve_option_id(market, { index = idx }, state)
      if not option_id then
        logger.warn("market_select missing option:", tostring(idx))
        return
      end
      dispatch_intent({ type = "market_select", option_id = option_id }, data)
    end, registered, listeners)
  end

  _register_node_click(cache, market_ui.confirm_button, function(data)
    local market = state.ui_model and state.ui_model.market
    if not market then
      logger.warn("market_confirm without market")
      return
    end
    local option_id = state.pending_choice_selected_option_id
    if not option_id then
      logger.warn("market_confirm missing selected option")
      return
    end
    dispatch_intent({ type = "market_confirm", choice_id = market.choice_id, option_id = option_id }, data)
  end, registered, listeners)

  _register_node_click(cache, market_ui.cancel_button, function(data)
    local choice = state.ui_model and state.ui_model.choice
    if not choice then
      logger.warn("market_cancel without choice")
      return
    end
    if choice.allow_cancel ~= false then
      dispatch_intent({ type = "choice_cancel", choice_id = choice.id }, data)
    end
  end, registered, listeners)

  local market_close = "关闭"
  if market_ui.cancel_button ~= market_close then
    _register_node_click(cache, market_close, function(data)
      local choice = state.ui_model and state.ui_model.choice
      if not choice then
        logger.warn("market_close without choice")
        return
      end
      if choice.allow_cancel ~= false then
        dispatch_intent({ type = "choice_cancel", choice_id = choice.id }, data)
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
