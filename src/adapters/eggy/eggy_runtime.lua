local EggyLayer = require("src.adapters.eggy.eggy_layer")
local MarketUI = require("src.adapters.eggy.market_ui")
local Game = require("src.game")

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
  pcall(require, "UIManager.Utils")
  local manager = rawget(_G, "UIManager")
  if not (manager and manager.Builder) then
    return
  end
  local ok_nodes, nodes = pcall(require, "ui_data")
  if not ok_nodes then
    return
  end
  pcall(manager.Builder, nodes)
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

function EggyRuntime.install()
  local layer = EggyLayer.new({ game_factory = create_game })

  LuaAPI.global_register_trigger_event(EVENT.GAME_INIT, function()
    install_ui_manager()
    layer:set_game(layer:new_game())
  end)

  LuaAPI.set_tick_handler(function(delta_seconds)
    layer:tick(delta_seconds or 0)
  end)

  LuaAPI.global_register_trigger_event(EVENT.UI_CUSTOM_EVENT, function(data)
    if not data then
      return
    end
    local event_name = data.event_name or data.name or data.event or nil
    if MarketUI.is_ready and MarketUI.is_ready() then
      local choice = layer.pending_choice
      if choice and choice.kind == "market_buy" then
        if event_name == MarketUI.confirm_event then
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
        if MarketUI.choose_event and event_name == MarketUI.choose_event then
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
        local idx = resolve_market_index(event_name)
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
        if MarketUI.cancel_event and event_name == MarketUI.cancel_event then
          if choice.allow_cancel ~= false then
            layer:dispatch_action({ type = "choice_cancel", choice_id = choice.id })
          end
          return
        end
      end
    end

    local mapped_action = resolve_mapped_action(event_name)
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
    local builder = actions[event_name]
    if not builder then
      return
    end
    local action = builder(data)
    if action then
      layer:dispatch_action(action)
    end
  end)

  return layer
end

return EggyRuntime