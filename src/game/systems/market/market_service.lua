local eligibility = require("src.game.systems.market.application.eligibility")
local choice = require("src.game.systems.market.application.choice")
local choice_session = require("src.game.systems.market.application.choice_session")
local purchase = require("src.game.systems.market.application.purchase")
local auto = require("src.game.systems.market.application.auto")

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
