local Effect = require("src.gameplay.effect")
local land_effects = require("src.gameplay.effects.land")
local Choice = require("src.gameplay.choice")

local LandResolver = {}

-- Apply land_effects with shared logic for mandatory/optional handling.
-- Returns { waiting=true } when an optional choice is opened.
function LandResolver.resolve(game, player, tile, move_result)
  local ctx = { player = player, tile = tile, move_result = move_result, on_landing = true, game = game }
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
    if game.ui_enabled then
      local body_lines = {}
      local options = {}
      for _, eff in ipairs(optional) do
        local label = eff.label or eff.id
        table.insert(body_lines, label)
        table.insert(options, { id = eff.id, label = label })
      end
      Choice.open(game, {
        kind = "land_optional_effect",
        title = "可选行动",
        body_lines = body_lines,
        options = options,
        allow_cancel = true,
        cancel_label = "跳过",
        meta = { player_id = player.id, tile_id = tile.id },
      })
      return { waiting = true, reason = "land_optional", resume_state = "end_turn", resume_args = { player = player } }
    end

    local first = optional[1]
    if first and first.apply then
      first.apply(ctx)
    end
  end

  return nil
end

return LandResolver
