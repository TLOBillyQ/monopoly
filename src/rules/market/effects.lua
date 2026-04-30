local market_service = require("src.rules.market")
local auto_play_port = require("src.rules.ports.auto_play")

local module = {}

module.executors = {
  market = {
    can_apply = function(ctx)
      return ctx.tile and ctx.tile.type == "market"
    end,
    apply = function(ctx)
      if auto_play_port.is_auto_player(ctx.game, ctx.player) then
        market_service.auto.execute(ctx.game, ctx.player)
        return nil
      end

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

--[[ mutate4lua-manifest
version=1
projectHash=d1c2a34360f5a71b
scope.0.id=chunk:src/rules/market/effects.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=36
scope.0.semanticHash=f52c61765986dcd4
scope.1.id=function:anonymous@7:7
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=9
scope.1.semanticHash=705f5a33874e4053
scope.2.id=function:anonymous@10:10
scope.2.kind=function
scope.2.startLine=10
scope.2.endLine=25
scope.2.semanticHash=d64543220b8ecfd6
scope.3.id=function:module.register_effect_executors:29
scope.3.kind=function
scope.3.startLine=29
scope.3.endLine=33
scope.3.semanticHash=cdf16067ffd8563f
]]
