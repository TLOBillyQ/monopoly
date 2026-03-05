local eligibility = require("src.game.systems.market.service.Eligibility")
local choice = require("src.game.systems.market.service.Choice")
local purchase = require("src.game.systems.market.service.Purchase")
local auto = require("src.game.systems.market.service.Auto")

local market_service = {
  query = {},
  choice = {},
  purchase = {},
  auto = {},
}

market_service.query.list_available = eligibility.list_available
market_service.choice.build = choice.build
market_service.choice.apply_navigation = choice.apply_navigation
market_service.purchase.execute = purchase.execute
market_service.purchase.setup_for_game = purchase.setup_for_game
market_service.purchase.can_start_external_purchase = purchase.can_start_external_purchase
market_service.auto.execute = auto.execute

return market_service
