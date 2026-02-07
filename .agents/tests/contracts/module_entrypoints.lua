local board_utils = require("src.game.land.LandBoardUtils")
local market_layout = require("src.ui.MarketLayout")
local market_view = require("src.ui.MarketView")

assert(type(board_utils.indices_in_range) == "function", "LandBoardUtils missing indices_in_range")
assert(type(market_layout.is_ready) == "function", "MarketLayout missing is_ready")
assert(type(market_view.refresh_market) == "function", "MarketView missing refresh_market")

print("Contract module_entrypoints passed")
