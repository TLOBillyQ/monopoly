-- 验证：非 market 的 choice timeout 为 15s
-- luacheck: std +busted
require("test.bootstrap").install_package_paths()
local luassert = assert
local function _assert_same(actual, expected, message)
  luassert.is.same(expected, actual, message)
end
local timing = require("src.config.gameplay.timing")
local ChoiceTimeout = require("src.turn.waits.choice_timeout")

describe("TestNonMarket15sTimeout", function()
  it("test_scope_timeouts_choice_is_15", function()
    _assert_same(timing.scope_timeouts.choice, 15)
  end)

  it("test_resolve_choice_timeout_seconds_returns_15_for_normal_choice", function()
    local game = { turn = { pending_choice = { id = 1, kind = "normal_choice" } } }
    local seconds = ChoiceTimeout.resolve_choice_timeout_seconds(game, {}, nil)
    _assert_same(seconds, 15)
  end)

  it("test_resolve_choice_timeout_seconds_returns_15_when_no_pending_choice", function()
    local seconds = ChoiceTimeout.resolve_choice_timeout_seconds({ turn = {} }, {}, nil)
    _assert_same(seconds, 15)
  end)
end)
