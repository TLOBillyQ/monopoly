local land_effects = require("src.gameplay.domain.land")
local logger = require("src.util.logger")
local constants = require("src.config.constants")

local Effect = {}


Effect.defs = {
  {
    id = "start_reward",
    label = "起点奖励",
    mandatory = true,
    can_apply = function(ctx)
      return ctx and ctx.tile and ctx.tile.type == "start" and ctx.on_landing
    end,
    apply = function(ctx)
      local player = ctx.player
      player:add_cash(constants.pass_start_bonus)
      logger.event(player.name .. " 停在起点，获得 " .. constants.pass_start_bonus .. " 金币")
    end,
  },
  {
    id = "item_draw_and_give",
    label = "道具",
    mandatory = true,
    can_apply = function(ctx)
      return ctx and ctx.game and ctx.player and ctx.tile and ctx.tile.type == "item"
    end,
    apply = function(ctx)
      local item = ctx.game and ctx.game.services and ctx.game.services.item
      if not item or not item.draw_and_give then
        error("Missing ItemService (game.services.item)")
      end
      return item.draw_and_give(ctx.player, ctx.game and ctx.game.rng)
    end,
  },
  {
    id = "chance_draw_and_resolve",
    label = "机会卡",
    mandatory = true,
    can_apply = function(ctx)
      return ctx and ctx.game and ctx.player and ctx.tile and ctx.tile.type == "chance"
    end,
    apply = function(ctx)
      local chance = ctx.game and ctx.game.services and ctx.game.services.chance
      if not chance or not chance.draw_card or not chance.resolve then
        error("Missing ChanceService (game.services.chance)")
      end

      local card = chance.draw_card(ctx.game and ctx.game.rng)
      logger.event(ctx.player.name .. " 抽到机会卡 " .. card.description)
      return chance.resolve(ctx.game, ctx.player, card, ctx.move_result)
    end,
  },
  {
    id = "tile_events",
    label = "格子事件",
    mandatory = true,
    can_apply = function(ctx)
      return ctx and ctx.game and ctx.player and ctx.tile
    end,
    apply = function(ctx)
      local tile_service = ctx.game and ctx.game.services and ctx.game.services.tile
      if not tile_service or not tile_service.resolve then
        error("Missing TileService (game.services.tile)")
      end
      return tile_service.resolve(ctx.game, ctx.player, ctx.tile, ctx.move_result)
    end,
  },
}


for _, eff in ipairs(land_effects.defs or {}) do
  table.insert(Effect.defs, eff)
end

return Effect
