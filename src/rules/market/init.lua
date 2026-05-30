local query = require("src.rules.market.query")
local choice = require("src.rules.market.choice")
local purchase = require("src.rules.market.purchase")
local auto = require("src.rules.market.auto")

local market_service = {
  query = {},
  choice = {},
  purchase = {},
  auto = {},
}

market_service.query.list_available = query.eligibility.list_available
market_service.choice.build = choice.builder.build
market_service.choice.rebuild_pending = choice.session.rebuild_pending
market_service.choice.apply_navigation = choice.session.apply_navigation
market_service.purchase.execute = purchase.execute
market_service.purchase.setup_for_game = purchase.setup_for_game
market_service.auto.execute = auto.execute

return market_service

--[[ mutate4lua-manifest
version=2
projectHash=3b481595f8af12e3
scope.0.id=chunk:src/rules/market/init.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=22
scope.0.semanticHash=d7260ad4cffc20e3
]]
