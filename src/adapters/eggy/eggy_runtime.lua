local EggyLayer = require("src.adapters.eggy.eggy_layer")
local MarketUI = require("src.adapters.eggy.market_ui")
local Game = require("src.game")

require "Utils.Frameout"
require "src.adapters.eggy.macro"

local EggyRuntime = {}

-- Map UI custom event names to logical actions when UI cannot pass ids.
local function create_game()
  return Game.new({
    players = { "玩家1", "AI2", "AI3", "AI4" },
    ai = { [2] = true, [3] = true, [4] = true },
    auto_all = true,
  })
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



local function register_node_click(cache, name, callback)
  if not name then
    return
  end
  local nodes = cache[name]
  if nodes == nil then
    nodes = UIManager.query_nodes_by_name(name) or {}
    cache[name] = nodes
  end
  if not nodes[1] then
    return
  end
  for _, node in ipairs(nodes) do
    node:listen(UIManager.EVENT.CLICK, function(data)
      callback(data)
    end)
  end
end

local function register_ui_manager_events(layer)
  local cache = {}
  register_node_click(cache, "btn_next", function()
    layer:dispatch_action({ type = "ui_button", id = "next" })
  end)
  register_node_click(cache, "btn_auto", function()
    layer:dispatch_action({ type = "ui_button", id = "auto" })
  end)
  for idx = 1, 5 do
    local name = "item_slot_" .. tostring(idx)
    register_node_click(cache, name, function()
      layer:dispatch_action({ type = "ui_button", id = name })
    end)
  end
  register_node_click(cache, "popup_confirm", function()
    layer:close_popup()
  end)

  register_node_click(cache, "choice_cancel", function()
    local choice = layer.pending_choice
    if choice and choice.allow_cancel ~= false then
      layer:dispatch_action({ type = "choice_cancel", choice_id = choice.id })
    end
  end)

  for idx, name in ipairs({ "choice_option1", "choice_option2", "choice_option3", "choice_option4" }) do
    register_node_click(cache, name, function()
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
    register_node_click(cache, name, function()
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

  register_node_click(cache, MarketUI.confirm_button, function()
    local choice = layer.pending_choice
    if not (choice and choice.kind == "market_buy") then
      return
    end
    local option_id = layer.pending_choice_selected_option_id
    if option_id then
      layer:dispatch_action({ type = "choice_select", choice_id = choice.id, option_id = option_id })
    end
  end)

  register_node_click(cache, MarketUI.cancel_button, function()
    local choice = layer.pending_choice
    if choice and choice.allow_cancel ~= false then
      layer:dispatch_action({ type = "choice_cancel", choice_id = choice.id })
    end
  end)
end

function EggyRuntime.install()
  local layer = EggyLayer.new({ game_factory = create_game })

  LuaAPI.global_register_trigger_event({ EVENT.GAME_INIT }, function()
    require "UIManager.Utils"
    UIManager.Builder(require "Data.ui_data")
    require "src.adapters.eggy.eca"
    UIManager.forward_eca_event(ECA_EVENT.UI.open_loading_screen)
    G = {
      tiles = {},
      buildings = {},
      refs = require "src.adapters.eggy.refs",
      lvs = {},
      role = {
        GameAPI.get_role(1),
        GameAPI.get_role(2),
        GameAPI.get_role(3),
        GameAPI.get_role(4),
      },
      unit = {
        GameAPI.get_role(1).get_ctrl_unit(),
        GameAPI.get_role(2).get_ctrl_unit(),
        GameAPI.get_role(3).get_ctrl_unit(),
        GameAPI.get_role(4).get_ctrl_unit(),
      },
    }
    layer:set_game(layer:new_game())
    register_ui_manager_events(layer)

    local refs = G.refs
    local role = GameAPI.get_role(1)
    local unit = role.get_ctrl_unit()

    local tile_names = {}
    local building_names = {}
    for i = 1, 45 do
      tile_names[i] = "t" .. tostring(i)
      building_names[i] = "b" .. tostring(i)
    end
    G.tiles = LuaAPI.query_units(tile_names)
    G.buildings = LuaAPI.query_units(building_names)

    local ground = LuaAPI.query_unit("ground")
    ground.set_model_visible(false)

    local function set_item_slot_image(slot_name, image_key)
      if not (slot_name and image_key) then
        return
      end
      local nodes = UIManager.query_nodes_by_name(slot_name) or {}
      for _, node in ipairs(nodes) do
        if node and node.image_texture ~= nil then
          node.image_texture = image_key
        end
      end
    end

    for _, r in ipairs(GameAPI.get_all_valid_roles()) do
      UIManager.client_role = r
      for i = 1, 5 do
        set_item_slot_image("item_slot_" .. tostring(i), refs["空"])
      end

      unit.add_state(Enums.BuffState.BUFF_FORBID_CONTROL)
    end
    UIManager.client_role = nil

    LuaAPI.call_delay_time(0.1, function()
      UIManager.forward_eca_event(ECA_EVENT.UI.close_loading_screen)
      UIManager.forward_eca_event(ECA_EVENT.UI.open_base_screen)
    end)
  end)

  local tick_interval = 1
  local tick_seconds = math.tofixed(tick_interval + 1) / 30.0
  SetFrameOut(tick_interval, function()
    layer:tick(tick_seconds)
  end, -1)

  return layer
end

return EggyRuntime
