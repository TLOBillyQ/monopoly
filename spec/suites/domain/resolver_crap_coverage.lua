local choice_resolver = require("src.rules.choice.resolver")

local _contains = choice_resolver._M_test._contains

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function test_contains_returns_true_when_value_present()
  _assert_eq(_contains({ "a", "b", "c" }, "b"), true, "contains present value")
end

local function test_contains_returns_false_when_value_missing()
  _assert_eq(_contains({ "a", "b" }, "z"), false, "contains missing value")
end

local function test_contains_returns_false_for_empty_table()
  _assert_eq(_contains({}, "a"), false, "contains empty list")
end

local function test_contains_returns_false_for_nil_list()
  _assert_eq(_contains(nil, "a"), false, "contains nil list")
end

local function test_contains_returns_false_for_string_list()
  _assert_eq(_contains("abc", "a"), false, "contains string list")
end

local function test_contains_returns_false_for_number_list()
  _assert_eq(_contains(123, 1), false, "contains number list")
end

local function test_contains_works_with_numeric_values()
  _assert_eq(_contains({ 1, 2, 3 }, 2), true, "contains numeric value")
end

local function test_contains_returns_false_for_numeric_mismatch()
  _assert_eq(_contains({ 1, 2, 3 }, 4), false, "contains numeric mismatch")
end

return {
  name = "domain resolver crap coverage",
  tests = {
    { name = "contains returns true when value present", run = test_contains_returns_true_when_value_present },
    { name = "contains returns false when value missing", run = test_contains_returns_false_when_value_missing },
    { name = "contains returns false for empty table", run = test_contains_returns_false_for_empty_table },
    { name = "contains returns false for nil list", run = test_contains_returns_false_for_nil_list },
    { name = "contains returns false for string list", run = test_contains_returns_false_for_string_list },
    { name = "contains returns false for number list", run = test_contains_returns_false_for_number_list },
    { name = "contains works with numeric values", run = test_contains_works_with_numeric_values },
    { name = "contains returns false for numeric mismatch", run = test_contains_returns_false_for_numeric_mismatch },
  },
}
