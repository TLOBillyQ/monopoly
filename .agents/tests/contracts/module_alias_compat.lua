local old_board_utils = require("src.game.item.ItemBoardUtils")
local new_board_utils = require("src.game.land.LandBoardUtils")

local old_market_layout = require("src.ui.MarketUI")
local new_market_layout = require("src.ui.MarketLayout")

local old_market_view = require("src.ui.UIMarket")
local new_market_view = require("src.ui.MarketView")

assert(old_board_utils == new_board_utils, "ItemBoardUtils alias mismatch")
assert(old_market_layout == new_market_layout, "MarketUI alias mismatch")
assert(old_market_view == new_market_view, "UIMarket alias mismatch")

print("Contract module_alias_compat passed")
