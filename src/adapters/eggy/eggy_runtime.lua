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
    if event_name == "ui_button" then
      layer:dispatch_action({ type = "ui_button", id = data.id or data.button_id })
    elseif event_name == "choice_select" then
      layer:dispatch_action({
        type = "choice_select",
        choice_id = data.choice_id,
        option_id = data.option_id,
      })
    elseif event_name == "choice_cancel" then
      layer:dispatch_action({ type = "choice_cancel", choice_id = data.choice_id })
    end
  end)

  return layer
end

return EggyRuntime
