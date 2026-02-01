local UIAliases = require("Manager.ChoiceManager.GUI.UIAliases")
local MarketUI = require("Manager.MarketManager.GUI.MarketUI")
local GameplayLoop = require("Manager.TurnManager.GameplayLoop")
local MainView = require("Manager.TurnManager.GUI.MainView")

local UIEventRouter = {}

local missing_button_tips = {}

local function resolve_option_id(choice, payload, state)
  if not (choice and payload) then
    return nil
  end
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
    local opt = choice.options and choice.options[idx]
    if opt then
      return opt.id or opt
    end
  end
  return nil
end

local function show_missing_button_tip(name)
  if missing_button_tips[name] then
    return
  end
  missing_button_tips[name] = true
  GlobalAPI.show_tips("UI 节点未适配: " .. tostring(name), 2.0)
end

local function register_node_click(cache, name, callback, registered)
  if not name then
    return
  end
  local resolved = UIAliases.resolve(name)
  local nodes = cache[resolved]
  if nodes == nil then
    nodes = UIManager.query_nodes_by_name(resolved) or {}
    cache[resolved] = nodes
  end
  if not nodes[1] then
    return
  end
  if registered then
    registered[resolved] = true
  end
  for _, node in ipairs(nodes) do
    node:listen(UIManager.EVENT.CLICK, function(data)
      callback(data)
    end)
  end
end

function UIEventRouter.bind(state, get_game, opts)
  local function resolve_game()
    if type(get_game) == "function" then
      return get_game()
    end
    return get_game
  end

  local function dispatch_action(action)
    GameplayLoop.dispatch_action(resolve_game(), state, action, opts)
  end

  local cache = {}
  local registered = {}
  register_node_click(cache, "btn_next", function()
    print("[debug] ui btn_next clicked")
    dispatch_action({ type = "ui_button", id = "next" })
  end, registered)
  register_node_click(cache, "btn_auto", function()
    dispatch_action({ type = "ui_button", id = "auto" })
  end, registered)
  for idx = 1, 5 do
    local name = "item_slot_" .. tostring(idx)
    register_node_click(cache, name, function()
      dispatch_action({ type = "ui_button", id = name })
    end, registered)
  end
  register_node_click(cache, "popup_confirm", function()
    MainView.close_popup(state)
  end, registered)

  register_node_click(cache, "choice_cancel", function()
    local choice = state.pending_choice
    if choice and choice.allow_cancel ~= false then
      dispatch_action({ type = "choice_cancel", choice_id = choice.id })
    end
  end, registered)

  for idx, name in ipairs({ "choice_option1", "choice_option2", "choice_option3", "choice_option4" }) do
    register_node_click(cache, name, function()
      local choice = state.pending_choice
      if not choice then
        return
      end
      local option_id = resolve_option_id(choice, { index = idx }, state)
      if option_id then
        dispatch_action({ type = "choice_select", choice_id = choice.id, option_id = option_id })
      elseif choice.allow_cancel ~= false then
        dispatch_action({ type = "choice_cancel", choice_id = choice.id })
      end
    end, registered)
  end

  for idx, name in ipairs(MarketUI.item_buttons or {}) do
    register_node_click(cache, name, function()
      if not (MarketUI.is_ready and MarketUI.is_ready()) then
        return
      end
      local choice = state.pending_choice
      if not (choice and choice.kind == "market_buy") then
        return
      end
      local option_id = resolve_option_id(choice, { index = idx }, state)
      if option_id then
        MainView.select_market_option(state, option_id)
      end
    end, registered)
  end

  register_node_click(cache, MarketUI.confirm_button, function()
    local choice = state.pending_choice
    if not (choice and choice.kind == "market_buy") then
      return
    end
    local option_id = state.pending_choice_selected_option_id
    if option_id then
      dispatch_action({ type = "choice_select", choice_id = choice.id, option_id = option_id })
    end
  end, registered)

  register_node_click(cache, MarketUI.cancel_button, function()
    local choice = state.pending_choice
    if choice and choice.allow_cancel ~= false then
      dispatch_action({ type = "choice_cancel", choice_id = choice.id })
    end
  end, registered)

  register_node_click(cache, "market_panel_close", function()
    local choice = state.pending_choice
    if choice and choice.allow_cancel ~= false then
      dispatch_action({ type = "choice_cancel", choice_id = choice.id })
    end
  end, registered)

  local ok, nodes = pcall(require, "Data.UIManagerNodes")
  if ok and type(nodes) == "table" then
    for _, entry in pairs(nodes) do
      local name = entry[1]
      local kind = entry[2]
      if kind == "EButton" and name and not registered[name] then
        register_node_click(cache, name, function()
          show_missing_button_tip(name)
        end, registered)
      end
    end
  end
end

return UIEventRouter
