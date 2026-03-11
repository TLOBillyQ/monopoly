local market_service = require("src.game.systems.market")

local module = {}

module.executors = {
  market = {
    can_apply = function(ctx)
      return ctx.tile and ctx.tile.type == "market"
    end,
    apply = function(ctx)
      local spec, intent = market_service.choice.build(ctx.player, ctx.game)
      if intent then
        return { intent = intent }
      end

      assert(spec ~= nil, "missing market choice spec")
      return {
        waiting = true,
        reason = "market_choice",
        intent = {
          kind = "need_choice",
          choice_spec = spec,
        },
      }
    end,
  },
}

function module.register_effect_executors(effect_registry)
  assert(effect_registry ~= nil, "missing effect_registry")
  assert(effect_registry.register_many ~= nil, "invalid effect_registry")
  effect_registry:register_many(module.executors)
end

return module
