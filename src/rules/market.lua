local eligibility = require("src.rules.market.query.eligibility")
local choice = require("src.rules.market.choice.builder")
local choice_session = require("src.rules.market.choice.session")
local purchase = require("src.rules.market.purchase.core")
local auto = require("src.rules.market.auto")

local market_service = {
  query = {},
  choice = {},
  purchase = {},
  auto = {},
}

market_service.query.list_available = eligibility.list_available
market_service.choice.build = choice.build
market_service.choice.rebuild_pending = choice_session.rebuild_pending
market_service.choice.apply_navigation = choice_session.apply_navigation
market_service.purchase.execute = purchase.execute
market_service.purchase.setup_for_game = purchase.setup_for_game
market_service.auto.execute = auto.execute

return market_service
