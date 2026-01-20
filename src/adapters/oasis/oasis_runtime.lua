local Game = require("src.game")
local OasisLayer = require("src.adapters.oasis.oasis_layer")

local OasisRuntime = {}

local function create_game()
  return Game.new({
    players = { "玩家1", "AI2", "AI3", "AI4" },
    ai = { [2] = true, [3] = true, [4] = true },
    auto_all = true,
  })
end

function OasisRuntime.install(opts)
  opts = opts or {}
  local layer = OasisLayer.new({
    game_factory = opts.game_factory or create_game,
    ui_root = opts.ui_root,
    ui_bridge = opts.ui_bridge,
    logger_prefix = opts.logger_prefix,
  })
  OasisRuntime._layer = layer
  return layer
end

function OasisRuntime.on_begin_play(opts)
  local layer = OasisRuntime.install(opts)
  layer:set_game(layer:new_game())
  return layer
end

function OasisRuntime.on_tick(delta_seconds)
  local layer = OasisRuntime._layer
  if not layer then
    return
  end
  layer:tick(delta_seconds or 0)
end

function OasisRuntime.on_ui_event(payload)
  local layer = OasisRuntime._layer
  if not (layer and payload) then
    return
  end
  local event_name = payload.event_name or payload.name or payload.event or nil
  local actions = {
    ui_button = function(data)
      return { type = "ui_button", id = data.id or data.button_id }
    end,
    choice_select = function(data)
      return {
        type = "choice_select",
        choice_id = data.choice_id,
        option_id = data.option_id,
      }
    end,
    choice_cancel = function(data)
      return { type = "choice_cancel", choice_id = data.choice_id }
    end,
    ui_tile_select = function(data)
      return { type = "ui_tile_select", index = data.index or data.tile_index }
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
  local action = builder(payload)
  if action then
    layer:dispatch_action(action)
  end
end

return OasisRuntime
