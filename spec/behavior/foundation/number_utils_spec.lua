---@diagnostic disable: need-check-nil, different-requires, undefined-field

local support = require("spec.support.shared_support")
local _assert_eq = support.assert_eq
local number_utils = require("src.foundation.number")

describe("number_utils", function()
  it("to_integer", function()
    _assert_eq(number_utils.to_integer("12"), 12, "string integer should parse")
    _assert_eq(number_utils.to_integer("-7"), -7, "negative string integer should parse")
    _assert_eq(number_utils.to_integer("12.3"), nil, "float string should be rejected")
  end)

  it("to_integer_fallback_from_tostring", function()
    local wrapped = setmetatable({}, {
      __tostring = function()
        return "5"
      end,
    })
    _assert_eq(number_utils.to_integer(wrapped), 5, "non-numeric value should parse from tostring fallback")
  end)

  it("to_integer_fallback_rejects_non_integer_text", function()
    local wrapped = setmetatable({}, {
      __tostring = function()
        return "abc"
      end,
    })
    _assert_eq(number_utils.to_integer(wrapped), nil, "non-integer tostring fallback should be rejected")
  end)

  describe("page_count", function()
    it("empty catalog still yields one page", function()
      _assert_eq(number_utils.page_count(0, 8), 1, "zero items should still be one page")
    end)

    it("exact multiple yields ceil with no extra page", function()
      _assert_eq(number_utils.page_count(16, 8), 2, "16 items at 8 per page = 2 pages")
    end)

    it("partial page rounds up", function()
      _assert_eq(number_utils.page_count(17, 8), 3, "17 items at 8 per page = 3 pages")
    end)

    it("single item with large page size yields one page", function()
      _assert_eq(number_utils.page_count(1, 8), 1, "1 item at 8 per page = 1 page")
    end)

    it("matches skin_panel PAGE_SIZE=6 arithmetic", function()
      _assert_eq(number_utils.page_count(6, 6), 1, "exactly one page")
      _assert_eq(number_utils.page_count(7, 6), 2, "one over the boundary spills to a new page")
      _assert_eq(number_utils.page_count(12, 6), 2, "double page exact")
    end)
  end)

  describe("is_numeric", function()
    it("accepts integers and floats", function()
      _assert_eq(number_utils.is_numeric(0), true, "zero is numeric")
      _assert_eq(number_utils.is_numeric(12), true, "positive int is numeric")
      _assert_eq(number_utils.is_numeric(-7), true, "negative int is numeric")
      _assert_eq(number_utils.is_numeric(3.14), true, "float is numeric")
      _assert_eq(number_utils.is_numeric(1e18), true, "very large number is numeric")
    end)

    it("rejects nil", function()
      _assert_eq(number_utils.is_numeric(nil), false, "nil is not numeric")
    end)

    it("rejects strings even when integer-shaped", function()
      _assert_eq(number_utils.is_numeric("12"), false, "string '12' is not numeric by design")
      _assert_eq(number_utils.is_numeric("3.14"), false, "string '3.14' is not numeric")
      _assert_eq(number_utils.is_numeric("abc"), false, "non-numeric string is not numeric")
      _assert_eq(number_utils.is_numeric(""), false, "empty string is not numeric")
    end)

    it("rejects booleans", function()
      _assert_eq(number_utils.is_numeric(true), false, "true is not numeric")
      _assert_eq(number_utils.is_numeric(false), false, "false is not numeric")
    end)

    it("rejects tables and functions", function()
      _assert_eq(number_utils.is_numeric({}), false, "empty table is not numeric")
      _assert_eq(number_utils.is_numeric({1, 2}), false, "list table is not numeric")
      _assert_eq(number_utils.is_numeric(function() end), false, "function is not numeric")
    end)
  end)

  describe("to_integer edges", function()
    it("nil returns nil", function()
      _assert_eq(number_utils.to_integer(nil), nil, "nil → nil")
    end)

    it("empty string returns nil", function()
      _assert_eq(number_utils.to_integer(""), nil, "empty string → nil")
    end)

    it("non-numeric string returns nil", function()
      _assert_eq(number_utils.to_integer("abc"), nil, "letters → nil")
    end)

    it("float-shaped string returns nil", function()
      _assert_eq(number_utils.to_integer("3.14"), nil, "float string → nil")
      _assert_eq(number_utils.to_integer("12.0"), nil, "integer-shaped float string → nil (parser strict)")
    end)

    it("whitespace-padded string returns nil", function()
      _assert_eq(number_utils.to_integer(" 12"), nil, "leading space → nil")
      _assert_eq(number_utils.to_integer("12 "), nil, "trailing space → nil")
    end)

    it("lone minus sign returns nil", function()
      _assert_eq(number_utils.to_integer("-"), nil, "bare minus → nil")
    end)

    it("zero parses to zero", function()
      _assert_eq(number_utils.to_integer("0"), 0, "string zero → 0")
      _assert_eq(number_utils.to_integer(0), 0, "number zero → 0")
    end)

    it("negative integer parses", function()
      _assert_eq(number_utils.to_integer(-42), -42, "negative number stays")
      _assert_eq(number_utils.to_integer("-42"), -42, "negative string parses")
    end)

    it("very large positive integer parses", function()
      _assert_eq(number_utils.to_integer("999999999999"), 999999999999, "12-digit int parses")
      _assert_eq(number_utils.to_integer(1000000000), 1000000000, "billion stays")
    end)

    it("integer-shaped float truncates via tointeger", function()
      _assert_eq(number_utils.to_integer(12.0), 12, "12.0 → 12")
      _assert_eq(number_utils.to_integer(-7.0), -7, "-7.0 → -7")
    end)

    it("non-integer float truncates via floor", function()
      _assert_eq(number_utils.to_integer(12.5), 12, "12.5 truncates down to 12")
      _assert_eq(number_utils.to_integer(12.99), 12, "12.99 floors to 12")
      _assert_eq(number_utils.to_integer(-7.5), -8, "negative floor rounds toward -inf")
    end)

    it("booleans return nil", function()
      _assert_eq(number_utils.to_integer(true), nil, "true → nil (tostring='true' not integer)")
      _assert_eq(number_utils.to_integer(false), nil, "false → nil")
    end)

    it("table without __tostring returns nil", function()
      _assert_eq(number_utils.to_integer({}), nil, "plain table → nil (tostring is 'table: 0x...')")
    end)
  end)

  describe("clamp", function()
    it("value within range passes through", function()
      _assert_eq(number_utils.clamp(5, 1, 10), 5, "in-range value unchanged")
    end)

    it("value below min snaps to min", function()
      _assert_eq(number_utils.clamp(-5, 1, 10), 1, "below min → min")
      _assert_eq(number_utils.clamp(0, 1, 10), 1, "0 below min of 1 → 1")
    end)

    it("value above max snaps to max", function()
      _assert_eq(number_utils.clamp(15, 1, 10), 10, "above max → max")
    end)

    it("nil value snaps to min", function()
      _assert_eq(number_utils.clamp(nil, 1, 10), 1, "nil → min (defensive default)")
    end)

    it("boundary values stay", function()
      _assert_eq(number_utils.clamp(1, 1, 10), 1, "exactly min stays")
      _assert_eq(number_utils.clamp(10, 1, 10), 10, "exactly max stays")
    end)
  end)

  describe("resolve_numeric", function()
    it("returns value when numeric", function()
      _assert_eq(number_utils.resolve_numeric(12, 0), 12, "numeric value used")
      _assert_eq(number_utils.resolve_numeric(3.14, 0), 3.14, "float value used")
      _assert_eq(number_utils.resolve_numeric(-7, 100), -7, "negative numeric value used")
    end)

    it("falls back when value is non-numeric", function()
      _assert_eq(number_utils.resolve_numeric(nil, 5), 5, "nil value → fallback")
      _assert_eq(number_utils.resolve_numeric("12", 5), 5, "string '12' not numeric → fallback")
      _assert_eq(number_utils.resolve_numeric("abc", 5), 5, "non-numeric string → fallback")
      _assert_eq(number_utils.resolve_numeric(true, 5), 5, "boolean → fallback")
      _assert_eq(number_utils.resolve_numeric({}, 5), 5, "table → fallback")
    end)

    it("returns nil when both non-numeric", function()
      _assert_eq(number_utils.resolve_numeric(nil, nil), nil, "nil + nil → nil")
      _assert_eq(number_utils.resolve_numeric("abc", "xyz"), nil, "both non-numeric → nil")
      _assert_eq(number_utils.resolve_numeric(nil, "xyz"), nil, "nil + non-numeric fallback → nil")
    end)
  end)

  describe("format_integer_part", function()
    it("formats positive integer", function()
      _assert_eq(number_utils.format_integer_part(12), "12", "positive int")
      _assert_eq(number_utils.format_integer_part(0), "0", "zero")
    end)

    it("formats negative integer", function()
      _assert_eq(number_utils.format_integer_part(-7), "-7", "negative int")
    end)

    it("truncates float to integer part", function()
      _assert_eq(number_utils.format_integer_part(12.5), "12", "12.5 → 12")
      _assert_eq(number_utils.format_integer_part(12.99), "12", "12.99 → 12")
      _assert_eq(number_utils.format_integer_part(-7.5), "-8", "negative floor rounds toward -inf")
    end)

    it("non-numeric falls back to tostring", function()
      _assert_eq(number_utils.format_integer_part(nil), "nil", "nil → 'nil'")
      _assert_eq(number_utils.format_integer_part("abc"), "abc", "string → tostring")
      _assert_eq(number_utils.format_integer_part(true), "true", "boolean → tostring")
    end)
  end)
end)
