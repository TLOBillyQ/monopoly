local choice_resolver = require("src.rules.choice.resolver")

local _contains = choice_resolver._M_test._contains

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

describe("domain resolver crap coverage", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("contains returns true when value present", function()
    _assert_eq(_contains({ "a", "b", "c" }, "b"), true, "contains present value")
  end)

  it("contains returns false when value missing", function()
    _assert_eq(_contains({ "a", "b" }, "z"), false, "contains missing value")
  end)

  it("contains returns false for empty table", function()
    _assert_eq(_contains({}, "a"), false, "contains empty list")
  end)

  it("contains returns false for nil list", function()
    _assert_eq(_contains(nil, "a"), false, "contains nil list")
  end)

  it("contains returns false for string list", function()
    _assert_eq(_contains("abc", "a"), false, "contains string list")
  end)

  it("contains returns false for number list", function()
    _assert_eq(_contains(123, 1), false, "contains number list")
  end)

  it("contains works with numeric values", function()
    _assert_eq(_contains({ 1, 2, 3 }, 2), true, "contains numeric value")
  end)

  it("contains returns false for numeric mismatch", function()
    _assert_eq(_contains({ 1, 2, 3 }, 4), false, "contains numeric mismatch")
  end)
end)
