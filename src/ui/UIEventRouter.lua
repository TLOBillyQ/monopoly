local ui_aliases = require("src.ui.UIAliases")
local market_ui = require("src.ui.MarketUI")
local ui_controller = require("src.ui.UIController")

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
    local mapped = state.market_choice_option_ids and state.market_choice_option_ids[idx]
    if mapped then
      return mapped
    end
    local opt = choice.options[idx]
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

local function _register_node_click(cache, name, callback, registered)
  assert(name ~= nil, "missing node name")
  local resolved = ui_aliases.resolve(name)
  local nodes = cache[resolved]
  if nodes then
  else
    nodes = UIManager.query_nodes_by_name(resolved)
    cache[resolved] = nodes
  end
  assert(nodes[1] ~= nil, "missing ui nodes: " .. tostring(resolved))
  assert(registered ~= nil, "missing registered map")
  registered[resolved] = true
  for _, node in ipairs(nodes) do
    node:listen(UIManager.EVENT.CLICK, function(data)
      callback(data)
    end)
  end
end

function ui_event_router.bind(state, get_game, opts)
  local function resolve_game()
    if type(get_game) == "function" then
      return get_game()
    end
    return get_game
  end

  local function dispatch_intent(intent)
    ui_controller.dispatch(state, resolve_game(), intent, opts)
  end

  local cache = {}
  local registered = {}
  _register_node_click(cache, "行动按钮", function()
    dispatch_intent({ type = "ui_button", id = "next" })
  end, registered)
  _register_node_click(cache, "托管按钮", function()
    dispatch_intent({ type = "ui_button", id = "auto" })
  end, registered)
  for idx = 1, 5 do
    local node_name = "道具槽位" .. tostring(idx)
    local action_id = "item_slot_" .. tostring(idx)
    _register_node_click(cache, node_name, function()
      dispatch_intent({ type = "ui_button", id = action_id })
    end, registered)
  end
  _register_node_click(cache, "弹窗确认", function()
    dispatch_intent({ type = "popup_confirm" })
  end, registered)

  _register_node_click(cache, "通用选择_取消", function()
    local choice = state.ui_model and state.ui_model.choice
    assert(choice ~= nil, "missing choice")
    if choice.allow_cancel ~= false then
      dispatch_intent({ type = "choice_cancel", choice_id = choice.id })
    end
  end, registered)

  for idx, name in ipairs({
    "通用选择_选项_01",
    "通用选择_选项_02",
    "通用选择_选项_03",
    "通用选择_选项_04",
  }) do
    _register_node_click(cache, name, function()
      local choice = state.ui_model and state.ui_model.choice
      assert(choice ~= nil, "missing choice")
      local option_id = _resolve_option_id(choice, { index = idx }, state)
      assert(option_id ~= nil, "missing option id")
      dispatch_intent({ type = "choice_select", choice_id = choice.id, option_id = option_id })
      if choice.allow_cancel ~= false then
        dispatch_intent({ type = "choice_cancel", choice_id = choice.id })
      end
    end, registered)
  end

  for idx, name in ipairs(market_ui.item_buttons) do
    _register_node_click(cache, name, function()
      assert(market_ui.is_ready(), "market ui not ready")
      local market = state.ui_model and state.ui_model.market
      assert(market ~= nil, "missing market")
      local option_id = _resolve_option_id(market, { index = idx }, state)
      assert(option_id ~= nil, "missing option id")
      dispatch_intent({ type = "market_select", option_id = option_id })
    end, registered)
  end

  _register_node_click(cache, market_ui.confirm_button, function()
    local market = state.ui_model and state.ui_model.market
    assert(market ~= nil, "missing market")
    local option_id = state.pending_choice_selected_option_id
    assert(option_id ~= nil, "missing selected market option")
    dispatch_intent({ type = "market_confirm", choice_id = market.choice_id, option_id = option_id })
  end, registered)

  _register_node_click(cache, market_ui.cancel_button, function()
    local choice = state.ui_model and state.ui_model.choice
    assert(choice ~= nil, "missing choice")
    if choice.allow_cancel ~= false then
      dispatch_intent({ type = "choice_cancel", choice_id = choice.id })
    end
  end, registered)

  local market_close = "关闭"
  if market_ui.cancel_button ~= market_close then
    _register_node_click(cache, market_close, function()
      local choice = state.ui_model and state.ui_model.choice
      assert(choice ~= nil, "missing choice")
      if choice.allow_cancel ~= false then
        dispatch_intent({ type = "choice_cancel", choice_id = choice.id })
      end
    end, registered)
  end

  local nodes = require("Data.UIManagerNodes")
  for _, entry in pairs(nodes) do
    local name = entry[1]
    local kind = entry[2]
    if kind == "EButton" and not registered[name] then
      _register_node_click(cache, name, function()
        _show_missing_button_tip(name)
      end, registered)
    end
  end
end

return ui_event_router
