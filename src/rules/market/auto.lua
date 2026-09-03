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

local function _auto_skip(game, player)
  local text = player.name .. " (AI) 到达黑市，选择不购买"
  _emit_event(monopoly_event.market.auto_skip, {
    player = player,
    text = text,
  })
  -- 独立 kind:通用 choice_skipped 不进行动日志,黑市跳过要留痕,托管席位才看得出被跳过。
  event_feed.publish(game, {
    kind = event_kinds.market_auto_skipped,
    text = text,
    tip = false,
  })
end

local function _sort_by_price(list)
  table.sort(list, function(a, b)
    return (context.entry_price(a) or 0) < (context.entry_price(b) or 0)
  end)
end

local function _pending_choice(game)
  return game.turn and game.turn.pending_choice or nil
end

function auto.execute(game, player)
  if auto_play_port.is_computer_controlled(game, player) then
    _auto_skip(game, player)
    return
  end

  local list = query.list_available(player, game)
  _sort_by_price(list)

  if #list <= 0 then
    return
  end

  local chosen = list[1]
  if chosen then
    local result = purchase.execute(game, player, chosen.product_id)
    purchase_settlement.resolve(game, _pending_choice(game), player, chosen, result)
  end
end

return auto

--[[ mutate4lua-manifest
version=4
projectHash=a91159d34bc0e656
scope.0.id=chunk:src/rules/market/auto.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=59
scope.0.semanticHash=00fcf92ec492beb1
scope.1.id=function:_auto_skip
scope.1.kind=function
scope.1.startLine=14
scope.1.endLine=26
scope.1.semanticHash=99491da1a80866e7
scope.2.id=function:_sort_by_price
scope.2.kind=function
scope.2.startLine=28
scope.2.endLine=32
scope.2.semanticHash=c55adbb184afc263
scope.3.id=function:<anonymous>
scope.3.kind=function
scope.3.startLine=29
scope.3.endLine=31
scope.3.semanticHash=386c46f9ceea61ea
scope.4.id=function:_pending_choice
scope.4.kind=function
scope.4.startLine=34
scope.4.endLine=36
scope.4.semanticHash=13ddff47d34fa2ed
scope.5.id=function:auto.execute
scope.5.kind=function
scope.5.startLine=38
scope.5.endLine=56
scope.5.semanticHash=10e795416d2e9cc4
]]
