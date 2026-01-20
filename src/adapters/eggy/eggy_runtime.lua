local EggyLayer = require("src.adapters.eggy.eggy_layer")
local Game = require("src.game")

local EggyRuntime = {}

local function create_game()
  return Game.new({
    players = { "玩家1", "AI2", "AI3", "AI4" },
    ai = { [2] = true, [3] = true, [4] = true },
    auto_all = true,
  })
end

function EggyRuntime.install()
  local layer = EggyLayer.new({ game_factory = create_game })

  LuaAPI.global_register_trigger_event(EVENT.GAME_INIT, function()
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
    local builder = event_name and actions[event_name] or nil
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
