-- 验证：非 market 的 choice timeout 为 15s
local lu = require("luaunit")
local timing = require("src.config.gameplay.timing")
local ChoiceTimeout = require("src.turn.waits.choice_timeout")

TestNonMarket15sTimeout = {}

function TestNonMarket15sTimeout:test_scope_timeouts_choice_is_15()
  lu.assertEquals(timing.scope_timeouts.choice, 15)
end

function TestNonMarket15sTimeout:test_resolve_choice_timeout_seconds_returns_15_for_normal_choice()
  local game = { turn = { pending_choice = { id = 1, kind = "normal_choice" } } }
  local seconds = ChoiceTimeout.resolve_choice_timeout_seconds(game, {}, nil)
  lu.assertEquals(seconds, 15)
end

function TestNonMarket15sTimeout:test_resolve_choice_timeout_seconds_returns_15_when_no_pending_choice()
  local seconds = ChoiceTimeout.resolve_choice_timeout_seconds({ turn = {} }, {}, nil)
  lu.assertEquals(seconds, 15)
end


return TestNonMarket15sTimeout
