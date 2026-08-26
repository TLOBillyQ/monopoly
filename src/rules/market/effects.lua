local market_service = require("src.rules.market")
local auto_play_port = require("src.rules.ports.auto_play")

local module = {}

module.executors = {
  market = {
    can_apply = function(ctx)
      return ctx.tile and ctx.tile.type == "market"
    end,
    apply = function(ctx)
      if auto_play_port.is_computer_controlled(ctx.game, ctx.player) then
        market_service.auto.execute(ctx.game, ctx.player)
        return nil
      end

      local buyable = market_service.query.list_available(ctx.player, ctx.game)
      if #buyable == 0 then
        return nil
      end

      local spec, intent = market_service.choice.build(ctx.player, ctx.game)
      if intent then
        return { intent = intent }
      end

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

return module

--[[ mutate4lua-manifest
version=4
projectHash=01e1521358bc0e97
scope.0.id=chunk:src/rules/market/effects.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=40
scope.0.semanticHash=83b2d8b7b1ef1d9a
scope.1.id=function:<anonymous>
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=10
scope.1.semanticHash=fc9334e270fc5994
scope.2.id=function:<anonymous>#2
scope.2.kind=function
scope.2.startLine=11
scope.2.endLine=35
scope.2.semanticHash=cc279710486ba394
]]
