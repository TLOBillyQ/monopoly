local market_service = require("src.game.systems.market.market_service")

local M = {}

M.executors = {
  market = {
    can_apply = function(ctx)
      return ctx.tile and ctx.tile.type == "market"
    end,
    apply = function(ctx)
      local spec, intent = market_service.choice.build(ctx.player, ctx.game)
      if intent then return { intent = intent } end
      assert(spec ~= nil, "missing market choice spec")
      return { waiting = true, reason = "market_choice", intent = { kind = "need_choice", choice_spec = spec } }
    end,
  },
}

return M
