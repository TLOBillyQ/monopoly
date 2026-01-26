local EggyLayer = require("src.adapters.eggy.eggy_layer")
local MarketUI = require("src.adapters.eggy.market_ui")
local Game = require("src.game")

local EggyRuntime = {}

local function create_game()
  return Game.new({
    players = { "玩家1", "AI2", "AI3", "AI4" },
    ai = { [2] = true, [3] = true, [4] = true },
    auto_all = true,
  })
end

local function install_ui_manager()
  pcall(require, "src.adapters.eggy.lib.eggy_ui_manager.UIManager.Utils")
  local manager = rawget(_G, "UIManager")
  if not manager then
    local ok, mod = pcall(require, "src.adapters.eggy.lib.eggy_ui_manager.UIManager.Utils")
    if ok then
      manager = mod
    end
  end
  if not (manager and manager.Builder) then
    return
  end
  local ok_nodes, nodes = pcall(require, "src.adapters.eggy.ui_nodes")
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

local function ensure_tickables()
  local g = rawget(_G, "G")
  if not g then
    g = {}
    rawset(_G, "G", g)
  end
  if not g.tickables then
    g.tickables = {}
  end
  g.addTickable = function(obj)
    assert(obj and obj.update, "tickable requires update")
    table.insert(g.tickables, obj)
  end
  g.removeTickable = function(obj)
    for i, v in ipairs(g.tickables) do
      if v == obj then
        table.remove(g.tickables, i)
        break
      end
    end
  end
  return g
end

function EggyRuntime.install()
  local layer = EggyLayer.new({ game_factory = create_game })
  local g = ensure_tickables()
  local layer_tickable = {
    update = function(_, dt)
      layer:tick(dt or 0)
    end,
  }

  LuaAPI.global_register_trigger_event(EVENT.GAME_INIT, function()
    install_ui_manager()
    layer:set_game(layer:new_game())
    g.tickables = {}
    g.addTickable(layer_tickable)
  end)

  LuaAPI.set_tick_handler(function(delta_seconds)
    local dt = delta_seconds or 0
    for _, tickable in ipairs(g.tickables) do
      tickable:update(dt)
    end
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
        if event_name == MarketUI.choose_event then
          local option_id = resolve_option_id(choice, data, layer)
          if option_id then
            layer.pending_choice_selected_option_id = option_id
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
