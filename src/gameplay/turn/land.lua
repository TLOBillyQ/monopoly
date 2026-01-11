local TileService = require("src.gameplay.services.tile_service")
local Effect = require("src.gameplay.effect")
local land_effects = require("src.gameplay.effects.land")
local logger = require("src.gameplay.services.logger")

local function phase_land(tm, args)
  local player = args.player
  local move_result = args.move_result
  local tile = tm.game.board:get_tile(player.position)
  TileService.resolve(tm.game, player, tile, move_result)
  local ctx = { player = player, tile = tile, move_result = move_result, on_landing = true, game = tm.game }
  local chooser = nil
  if tm.game.ui_hooks and tm.game.ui_hooks.request_choice then
    chooser = function(options, on_select)
      local buttons = {}
      local body = {}
      for _, eff in ipairs(options) do
        local label = eff.label or eff.id
        local desc = eff.description and (" - " .. eff.description) or ""
        table.insert(body, label .. desc)
        table.insert(buttons, {
          label = label,
          on_click = function()
            on_select(eff)
          end,
        })
      end
      table.insert(buttons, {
        label = "跳过",
        on_click = function()
          on_select(nil)
        end,
      })
      tm.game.ui_hooks.request_choice({
        title = "可选行动",
        body_lines = body,
        buttons = buttons,
      })
    end
  end
  Effect.resolve(land_effects.defs, ctx, chooser)

  if player.eliminated then
    tm:next_player()
    return nil
  end
  return "end_turn", { player = player }
end

return phase_land
