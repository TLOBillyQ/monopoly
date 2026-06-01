local support = require("spec.support.shared_support")
local _assert_eq = support.assert_eq
local context = require("src.turn.actions.context")

describe("turn.actions.context.resolve_timestamp_diff_seconds", function()
  it("uses the clock port diff when it returns a numeric value", function()
    local ctx = {
      clock_ports = {
        wall_diff_seconds = function(a, b)
          return (a - b) * 2
        end,
      },
    }
    _assert_eq(context.resolve_timestamp_diff_seconds(ctx, 9, 7), 4,
      "a numeric clock-port diff should be returned directly")
  end)

  it("falls back to subtraction when the clock port returns a non-numeric value", function()
    local ctx = {
      clock_ports = {
        wall_diff_seconds = function()
          return "not-a-number"
        end,
      },
    }
    _assert_eq(context.resolve_timestamp_diff_seconds(ctx, 9, 7), 2,
      "a non-numeric clock-port diff should fall back to arithmetic")
  end)

  it("falls back to subtraction when the clock port errors", function()
    local ctx = {
      clock_ports = {
        wall_diff_seconds = function()
          error("clock boom")
        end,
      },
    }
    _assert_eq(context.resolve_timestamp_diff_seconds(ctx, 9, 7), 2,
      "a throwing clock port should fall back to arithmetic")
  end)

  it("subtracts directly when no clock port is available", function()
    _assert_eq(context.resolve_timestamp_diff_seconds(nil, 9, 7), 2,
      "a missing dispatch context should fall back to arithmetic")
    _assert_eq(context.resolve_timestamp_diff_seconds({}, 9, 7), 2,
      "a context without clock ports should fall back to arithmetic")
  end)

  it("returns zero when either timestamp is non-numeric", function()
    _assert_eq(context.resolve_timestamp_diff_seconds(nil, "x", 7), 0,
      "a non-numeric first timestamp should yield 0")
    _assert_eq(context.resolve_timestamp_diff_seconds(nil, 9, nil), 0,
      "a missing second timestamp should yield 0")
  end)
end)
