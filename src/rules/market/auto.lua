local auto_play_port = require("src.rules.ports.auto_play")
local monopoly_event = require("src.foundation.events")
local market_query = require("src.rules.market.query")
local purchase = require("src.rules.market.purchase")
local purchase_settlement = require("src.rules.market.purchase_settlement")
local query = market_query.eligibility
local context = market_query.context
local event_feed = require("src.rules.ports.event_feed")
local event_kinds = require("src.config.gameplay.event_kinds")

local auto = {}
local _emit_event = monopoly_event.emit

function auto.execute(game, player)
  if auto_play_port.is_auto_player(game, player) then
    local text = player.name .. " (AI) 到达黑市，选择不购买"
    _emit_event(monopoly_event.market.auto_skip, {
      player = player,
      text = text,
    })
    event_feed.publish(game, {
      kind = event_kinds.choice_skipped,
      text = text,
      tip = false,
    })
    return
  end

  local list = query.list_available(player, game)
  table.sort(list, function(a, b)
    return (context.entry_price(a) or 0) < (context.entry_price(b) or 0)
  end)

  if #list <= 0 then
    return
  end

  local chosen = list[1]
  if chosen then
    local result = purchase.execute(game, player, chosen.product_id)
    purchase_settlement.resolve(game, game.turn and game.turn.pending_choice or nil, player, chosen, result)
  end
end

return auto

--[[ mutate4lua-manifest
version=2
projectHash=03853170cab05f21
scope.0.id=chunk:src/rules/market/auto.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=46
scope.0.semanticHash=798d57124354297c
scope.1.id=function:anonymous@30:30
scope.1.kind=function
scope.1.startLine=30
scope.1.endLine=32
scope.1.semanticHash=566a2ab388db53a7
scope.2.id=function:auto.execute:14
scope.2.kind=function
scope.2.startLine=14
scope.2.endLine=43
scope.2.semanticHash=2a2d551f30234765
]]
