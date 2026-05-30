-- 验证：market_buy 的 timeout 为 60s（来自 timing.scope_timeouts.market_buy）
local timing = require("src.config.gameplay.timing")
local tick_timeout = require("src.turn.waits.timeout")

describe("market_buy 60s timeout", function()
  it("scope_timeouts.market_buy is 60", function()
    assert.is_table(timing.scope_timeouts)
    assert.equals(60, timing.scope_timeouts.market_buy)
  end)

  it("resolve_choice_timeout_seconds returns 60 for market_buy choice", function()
    local game = { turn = { pending_choice = { id = 1, kind = "market_buy" } } }
    local seconds = tick_timeout.resolve_choice_timeout_seconds(game, {}, nil)
    assert.equals(60, seconds)
  end)

  it("resolve_choice_timeout_seconds via passed choice param", function()
    local seconds = tick_timeout.resolve_choice_timeout_seconds({ turn = {} }, {}, { kind = "market_buy" })
    assert.equals(60, seconds)
  end)
end)
