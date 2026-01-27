local EggyLayer = require("src.adapters.eggy.eggy_layer")
local MarketUI = require("src.adapters.eggy.market_ui")
local Game = require("src.game")

require "Utils.Frameout"

local EggyRuntime = {}

-- Map UI custom event names to logical actions when UI cannot pass ids.
local EVENT_NAME_ACTION_MAP = {
  ["自动控制底"] = { type = "ui_button", id = "auto" },
  ["自动控制按钮"] = { type = "ui_button", id = "auto" },
  ["圆形金"] = { type = "ui_button", id = "next" },
  ["关闭"] = { type = "popup_confirm" },
}

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

local function resolve_market_index(event_name)
  if type(event_name) ~= "string" then
    return nil
  end
  if type(MarketUI.item_events) == "table" then
    for idx, name in ipairs(MarketUI.item_events) do
      if name == event_name then
        return idx
      end
    end
  end
  local prefix = MarketUI.item_event_prefix
  if type(prefix) == "string" and prefix ~= "" then
    if string.sub(event_name, 1, #prefix) == prefix then
      local suffix = string.sub(event_name, #prefix + 1)
      local idx = tonumber(suffix)
      if idx then
        return idx
      end
    end
  end
  return nil
end

local function resolve_mapped_action(event_name)
  local mapped = EVENT_NAME_ACTION_MAP[event_name]
  if mapped then
    return { type = mapped.type, id = mapped.id, choice_id = mapped.choice_id, option_id = mapped.option_id }
  end
  return nil
end

local function handle_ui_custom_event(layer, event_name, payload)
  local data = payload or {}
  local resolved_name = data.event_name or data.name or data.event or event_name
  if not resolved_name then
    return
  end
  if MarketUI.is_ready and MarketUI.is_ready() then
    local choice = layer.pending_choice
    if choice and choice.kind == "market_buy" then
      if resolved_name == MarketUI.confirm_event then
        local option_id = resolve_option_id(choice, data, layer) or layer.pending_choice_selected_option_id
        local action = nil
        if option_id then
          action = { type = "choice_select", choice_id = choice.id, option_id = option_id }
        elseif choice.allow_cancel ~= false then
          action = { type = "choice_cancel", choice_id = choice.id }
        end
        if action then
          layer:dispatch_action(action)
        end
        return
      end
      if MarketUI.choose_event and resolved_name == MarketUI.choose_event then
        local option_id = resolve_option_id(choice, data, layer)
        if option_id then
          if layer.select_market_option then
            layer:select_market_option(option_id)
          else
            layer.pending_choice_selected_option_id = option_id
          end
        end
        return
      end
      local idx = resolve_market_index(resolved_name)
      if idx then
        local option_id = resolve_option_id(choice, { index = idx }, layer)
        if option_id then
          if layer.select_market_option then
            layer:select_market_option(option_id)
          else
            layer.pending_choice_selected_option_id = option_id
          end
        end
        return
      end
      if MarketUI.cancel_event and resolved_name == MarketUI.cancel_event then
        if choice.allow_cancel ~= false then
          layer:dispatch_action({ type = "choice_cancel", choice_id = choice.id })
        end
        return
      end
    end
  end

  local mapped_action = resolve_mapped_action(resolved_name)
  if mapped_action then
    if mapped_action.type == "popup_confirm" then
      layer:close_popup()
      return
    end
    layer:dispatch_action(mapped_action)
    return
  end

  local actions = {
    ui_button = function(payload)
      return { type = "ui_button", id = payload.id or payload.button_id }
    end,
    choice_select = function(payload)
      return {
        type = "choice_select",
        choice_id = payload.choice_id,
        option_id = payload.option_id,
      }
    end,
    choice_cancel = function(payload)
      return { type = "choice_cancel", choice_id = payload.choice_id }
    end,
    ui_tile_select = function(payload)
      return { type = "ui_tile_select", index = payload.index or payload.tile_index }
    end,
    popup_confirm = function()
      layer:close_popup()
      return nil
    end,
  }
  local builder = actions[resolved_name]
  if not builder then
    return
  end
  local action = builder(data)
  if action then
    layer:dispatch_action(action)
  end
end

function EggyRuntime.install()
  local layer = EggyLayer.new({ game_factory = create_game })

  LuaAPI.global_register_trigger_event({ EVENT.GAME_INIT }, function()
    install_ui_manager()
    install_eca_bridge()
    layer:set_game(layer:new_game())
  end)

  local tick_interval = 1
  local tick_seconds = math.tofixed(tick_interval + 1) / 30.0
  SetFrameOut(tick_interval, function()
    layer:tick(tick_seconds)
  end, -1)

  local registered_events = {}
  local function register_ui_custom_event(name)
    registered_events[name] = true
    LuaAPI.global_register_custom_event(name, function(_, _, data)
      handle_ui_custom_event(layer, name, data)
    end)
  end

  for name in pairs(EVENT_NAME_ACTION_MAP) do
    register_ui_custom_event(name)
  end
  for _, name in ipairs({ "ui_button", "choice_select", "choice_cancel", "ui_tile_select", "popup_confirm" }) do
    register_ui_custom_event(name)
  end
  register_ui_custom_event(MarketUI.confirm_event)
  register_ui_custom_event(MarketUI.cancel_event)
  register_ui_custom_event(MarketUI.choose_event)
  if type(MarketUI.item_events) == "table" then
    for _, name in ipairs(MarketUI.item_events) do
      register_ui_custom_event(name)
    end
  end
  local prefix = MarketUI.item_event_prefix
  local item_buttons = MarketUI.item_buttons
  if type(prefix) == "string" and prefix ~= "" and type(item_buttons) == "table" then
    for i = 1, #item_buttons do
      register_ui_custom_event(prefix .. tostring(i))
    end
  end

  return layer
end

return EggyRuntime
