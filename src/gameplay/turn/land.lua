local TileService = require("src.gameplay.services.tile_service")
local Effect = require("src.gameplay.effect")
local land_effects = require("src.gameplay.effects.land")
local Choice = require("src.gameplay.choice")

local function phase_land(tm, args)
  local player = args.player
  local move_result = args.move_result
  local tile = tm.game.board:get_tile(player.position)
  local res = TileService.resolve(tm.game, player, tile, move_result)
  if res and res.waiting then
    return "wait_choice", {
      resume_state = "land",
      resume_args = { player = player, move_result = move_result },
    }
  end

  local ctx = { player = player, tile = tile, move_result = move_result, on_landing = true, game = tm.game }
  local available = Effect.list(land_effects.defs, ctx)
  local mandatory = {}
  local optional = {}
  for _, eff in ipairs(available) do
    if eff.mandatory then
      table.insert(mandatory, eff)
    else
      table.insert(optional, eff)
    end
  end

  for _, eff in ipairs(mandatory) do
    if eff.apply then
      eff.apply(ctx)
    end
  end

  if #optional > 0 then
    if tm.game.ui_enabled then
      local body_lines = {}
      local options = {}
      for _, eff in ipairs(optional) do
        local label = eff.label or eff.id
        table.insert(body_lines, label)
        table.insert(options, { id = eff.id, label = label })
      end
      Choice.open(tm.game, {
        kind = "land_optional_effect",
        title = "可选行动",
        body_lines = body_lines,
        options = options,
        allow_cancel = true,
        cancel_label = "跳过",
        meta = { player_id = player.id, tile_id = tile.id },
      })
      return "wait_choice", { resume_state = "end_turn", resume_args = { player = player } }
    end

    local first = optional[1]
    if first and first.apply then
      first.apply(ctx)
    end
  end

  return "end_turn", { player = player }
end

return phase_land
