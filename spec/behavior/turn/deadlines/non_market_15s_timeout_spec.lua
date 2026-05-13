-- 验证：非 market 的 choice timeout 为 15s
local timing = require("src.config.gameplay.timing")
local tick_timeout = require("src.turn.waits.timeout")

describe("non-market 15s timeout", function()
  it("scope_timeouts.choice is 15", function()
    assert.equals(15, timing.scope_timeouts.choice)
  end)

  it("resolve_choice_timeout_seconds returns 15 for normal choice", function()
    local game = { turn = { pending_choice = { id = 1, kind = "normal_choice" } } }
    local seconds = tick_timeout.resolve_choice_timeout_seconds(game, {}, nil)
    assert.equals(15, seconds)
  end)

  it("resolve_choice_timeout_seconds returns 15 when no pending choice", function()
    local seconds = tick_timeout.resolve_choice_timeout_seconds({ turn = {} }, {}, nil)
    assert.equals(15, seconds)
  end)
end)
