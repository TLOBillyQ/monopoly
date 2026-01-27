local EggyLayer = require("src.adapters.eggy.eggy_layer")
local MarketUI = require("src.adapters.eggy.market_ui")
local Game = require("src.game")

require "Utils.Frameout"

local EggyRuntime = {}

-- Map UI custom event names to logical actions when UI cannot pass ids.
local function create_game()
  return Game.new({
    players = { "玩家1", "AI2", "AI3", "AI4" },
    ai = { [2] = true, [3] = true, [4] = true },
    auto_all = true,
  })
end

local function install_ui_manager()
  require "UIManager.Utils"
  local ui_data = require "ui_data"
  UIManager.Builder(ui_data)
end

local function install_eca_bridge()
  require "macro"
  require "src.adapters.eggy.eca"
end

local function resolve_option_id(choice, payload, layer)
  if not (choice and payload) then
    return nil
  end
  local option_id = payload.option_id or payload.option or nil
  if option_id then
    return option_id
  end
  local idx = payload.index or payload.option_index or payload.card_index or payload.choice_index
  if idx then
    local mapped = layer and layer.market_choice_option_ids and layer.market_choice_option_ids[idx]
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



local function register_node_click(name, callback)
  if not name then
    return
  end
  local nodes = UIManager.query_nodes_by_name(name)
  if not nodes or not nodes[1] then
    return
  end
  for _, node in ipairs(nodes) do
    node:listen(UIManager.EVENT.CLICK, function(data)
      callback(data)
    end)
  end
end

local function register_ui_manager_events(layer)
  register_node_click("btn_next", function()
    layer:dispatch_action({ type = "ui_button", id = "next" })
  end)
  register_node_click("btn_auto", function()
    layer:dispatch_action({ type = "ui_button", id = "auto" })
  end)
  register_node_click("btn_restart", function()
    layer:dispatch_action({ type = "ui_button", id = "restart" })
  end)
  register_node_click("popup_confirm", function()
    layer:close_popup()
  end)
  register_node_click("popup_confirm_alt", function()
    layer:close_popup()
  end)

  register_node_click("choice_cancel", function()
    local choice = layer.pending_choice
    if choice and choice.allow_cancel ~= false then
      layer:dispatch_action({ type = "choice_cancel", choice_id = choice.id })
    end
  end)

  for idx, name in ipairs({ "choice_option_1", "choice_option_2", "choice_option_3", "choice_option_4" }) do
    register_node_click(name, function()
      local choice = layer.pending_choice
      if not choice then
        return
      end
      local option_id = resolve_option_id(choice, { index = idx }, layer)
      if option_id then
        layer:dispatch_action({ type = "choice_select", choice_id = choice.id, option_id = option_id })
      elseif choice.allow_cancel ~= false then
        layer:dispatch_action({ type = "choice_cancel", choice_id = choice.id })
      end
    end)
  end

  for idx, name in ipairs(MarketUI.item_buttons or {}) do
    register_node_click(name, function()
      if not (MarketUI.is_ready and MarketUI.is_ready()) then
        return
      end
      local choice = layer.pending_choice
      if not (choice and choice.kind == "market_buy") then
        return
      end
      local option_id = resolve_option_id(choice, { index = idx }, layer)
      if option_id then
        if layer.select_market_option then
          layer:select_market_option(option_id)
        else
          layer.pending_choice_selected_option_id = option_id
        end
      end
    end)
  end

  register_node_click(MarketUI.confirm_button, function()
    local choice = layer.pending_choice
    if not (choice and choice.kind == "market_buy") then
      return
    end
    local option_id = layer.pending_choice_selected_option_id
    if option_id then
      layer:dispatch_action({ type = "choice_select", choice_id = choice.id, option_id = option_id })
    end
  end)

  register_node_click(MarketUI.cancel_button, function()
    local choice = layer.pending_choice
    if choice and choice.allow_cancel ~= false then
      layer:dispatch_action({ type = "choice_cancel", choice_id = choice.id })
    end
  end)
end

function EggyRuntime.install()
  local layer = EggyLayer.new({ game_factory = create_game })

  LuaAPI.global_register_trigger_event({ EVENT.GAME_INIT }, function()
    install_ui_manager()
    install_eca_bridge()
    layer:set_game(layer:new_game())
    register_ui_manager_events(layer)
  end)

  local tick_interval = 1
  local tick_seconds = math.tofixed(tick_interval + 1) / 30.0
  SetFrameOut(tick_interval, function()
    layer:tick(tick_seconds)
  end, -1)

  return layer
end

return EggyRuntime
