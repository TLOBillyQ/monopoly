local UIAliases = require("Manager.UIRoot.UIAliases")
local MarketUI = require("Manager.UIRoot.MarketUI")
local UIController = require("Manager.UIRoot.UIController")

local UIEventRouter = {}

local missing_button_tips = {}

local function _ResolveOptionId(choice, payload, state)
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

local function _ShowMissingButtonTip(name)
  if missing_button_tips[name] then
    return
  end
  missing_button_tips[name] = true
  GlobalAPI.show_tips("UI 节点未适配: " .. tostring(name), 2.0)
end

local function _RegisterNodeClick(cache, name, callback, registered)
  assert(name ~= nil, "missing node name")
  local resolved = UIAliases.Resolve(name)
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

function UIEventRouter.Bind(state, get_game, opts)
  local function resolve_game()
    if type(get_game) == "function" then
      return get_game()
    end
    return get_game
  end

  local function dispatch_intent(intent)
    UIController.Dispatch(state, resolve_game(), intent, opts)
  end

  local cache = {}
  local registered = {}
  _RegisterNodeClick(cache, "行动按钮", function()
    dispatch_intent({ type = "ui_button", id = "next" })
  end, registered)
  _RegisterNodeClick(cache, "托管按钮", function()
    dispatch_intent({ type = "ui_button", id = "auto" })
  end, registered)
  for idx = 1, 5 do
    local node_name = "道具槽位" .. tostring(idx)
    local action_id = "item_slot_" .. tostring(idx)
    _RegisterNodeClick(cache, node_name, function()
      dispatch_intent({ type = "ui_button", id = action_id })
    end, registered)
  end
  _RegisterNodeClick(cache, "弹窗确认", function()
    dispatch_intent({ type = "popup_confirm" })
  end, registered)

  _RegisterNodeClick(cache, "取消按钮", function()
    local choice = state.ui_model and state.ui_model.choice
    assert(choice ~= nil, "missing choice")
    if choice.allow_cancel ~= false then
      dispatch_intent({ type = "choice_cancel", choice_id = choice.id })
    end
  end, registered)

  for idx, name in ipairs({ "道具名称1", "道具名称2", "道具名称3", "道具名称4" }) do
    _RegisterNodeClick(cache, name, function()
      local choice = state.ui_model and state.ui_model.choice
      assert(choice ~= nil, "missing choice")
      local option_id = _ResolveOptionId(choice, { index = idx }, state)
      assert(option_id ~= nil, "missing option id")
      dispatch_intent({ type = "choice_select", choice_id = choice.id, option_id = option_id })
      if choice.allow_cancel ~= false then
        dispatch_intent({ type = "choice_cancel", choice_id = choice.id })
      end
    end, registered)
  end

  for idx, name in ipairs(MarketUI.item_buttons) do
    _RegisterNodeClick(cache, name, function()
      assert(MarketUI.IsReady(), "market ui not ready")
      local market = state.ui_model and state.ui_model.market
      assert(market ~= nil, "missing market")
      local option_id = _ResolveOptionId(market, { index = idx }, state)
      assert(option_id ~= nil, "missing option id")
      dispatch_intent({ type = "market_select", option_id = option_id })
    end, registered)
  end

  _RegisterNodeClick(cache, MarketUI.confirm_button, function()
    local market = state.ui_model and state.ui_model.market
    assert(market ~= nil, "missing market")
    local option_id = state.pending_choice_selected_option_id
    assert(option_id ~= nil, "missing selected market option")
    dispatch_intent({ type = "market_confirm", choice_id = market.choice_id, option_id = option_id })
  end, registered)

  _RegisterNodeClick(cache, MarketUI.cancel_button, function()
    local choice = state.ui_model and state.ui_model.choice
    assert(choice ~= nil, "missing choice")
    if choice.allow_cancel ~= false then
      dispatch_intent({ type = "choice_cancel", choice_id = choice.id })
    end
  end, registered)

  local market_close = "关闭"
  if MarketUI.cancel_button ~= market_close then
    _RegisterNodeClick(cache, market_close, function()
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
      _RegisterNodeClick(cache, name, function()
        _ShowMissingButtonTip(name)
      end, registered)
    end
  end
end

return UIEventRouter
