-- 验证：market_buy 的 timeout 为 60s（来自 timing.scope_timeouts.market_buy）
-- luacheck: std +busted
require("test.bootstrap").install_package_paths()
local luassert = assert
local function _assert_same(actual, expected, message)
  luassert.is.same(expected, actual, message)
end
local timing = require("src.config.gameplay.timing")
local ChoiceTimeout = require("src.turn.waits.choice_timeout")

describe("TestMarketBuy60sTimeout", function()
  it("test_scope_timeouts_market_buy_is_60", function()
    luassert.is_table(timing.scope_timeouts)
    _assert_same(timing.scope_timeouts.market_buy, 60)
  end)

  it("test_resolve_choice_timeout_seconds_returns_60_for_market_buy_choice", function()
    local game = { turn = { pending_choice = { id = 1, kind = "market_buy" } } }
    local seconds = ChoiceTimeout.resolve_choice_timeout_seconds(game, {}, nil)
    _assert_same(seconds, 60)
  end)

  it("test_resolve_choice_timeout_seconds_via_passed_choice_param", function()
    local seconds = ChoiceTimeout.resolve_choice_timeout_seconds({ turn = {} }, {}, { kind = "market_buy" })
    _assert_same(seconds, 60)
  end)
end)
