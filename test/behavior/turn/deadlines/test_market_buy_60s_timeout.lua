-- 验证：market_buy 的 timeout 为 60s（来自 timing.scope_timeouts.market_buy）
local lu = require("luaunit")
local timing = require("src.config.gameplay.timing")
local ChoiceTimeout = require("src.turn.waits.choice_timeout")

TestMarketBuy60sTimeout = {}

function TestMarketBuy60sTimeout:test_scope_timeouts_market_buy_is_60()
  lu.assertIsTable(timing.scope_timeouts)
  lu.assertEquals(timing.scope_timeouts.market_buy, 60)
end

function TestMarketBuy60sTimeout:test_resolve_choice_timeout_seconds_returns_60_for_market_buy_choice()
  local game = { turn = { pending_choice = { id = 1, kind = "market_buy" } } }
  local seconds = ChoiceTimeout.resolve_choice_timeout_seconds(game, {}, nil)
  lu.assertEquals(seconds, 60)
end

function TestMarketBuy60sTimeout:test_resolve_choice_timeout_seconds_via_passed_choice_param()
  local seconds = ChoiceTimeout.resolve_choice_timeout_seconds({ turn = {} }, {}, { kind = "market_buy" })
  lu.assertEquals(seconds, 60)
end


return TestMarketBuy60sTimeout
