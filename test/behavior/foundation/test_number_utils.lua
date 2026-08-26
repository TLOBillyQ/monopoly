---@diagnostic disable: need-check-nil, different-requires, undefined-field

local lu = require("luaunit")
local support = require("test.support.shared_support")
local _assert_eq = support.assert_eq
local number_utils = require("src.foundation.number")

-- 原生 LuaUnit 迁移:顶层 describe 与末尾 property 迁入块均无钩子 → 合并为一个
-- Test* 类(平级 describe 无钩子不拆类),用例数与改写前一一对应(39 + 14 = 53 例)。

TestNumberUtils = {}

function TestNumberUtils:test_to_integer()
  _assert_eq(number_utils.to_integer("12"), 12, "string integer should parse")
  _assert_eq(number_utils.to_integer("-7"), -7, "negative string integer should parse")
  _assert_eq(number_utils.to_integer("12.3"), nil, "float string should be rejected")
end

function TestNumberUtils:test_to_integer_fallback_from_tostring()
  local wrapped = setmetatable({}, {
    __tostring = function()
      return "5"
    end,
  })
  _assert_eq(number_utils.to_integer(wrapped), 5, "non-numeric value should parse from tostring fallback")
end

function TestNumberUtils:test_to_integer_fallback_rejects_non_integer_text()
  local wrapped = setmetatable({}, {
    __tostring = function()
      return "abc"
    end,
  })
  _assert_eq(number_utils.to_integer(wrapped), nil, "non-integer tostring fallback should be rejected")
end

local function _parse_integer_string_upvalue(module)
  local index = 1
  while true do
    local name, value = debug.getupvalue(module.to_integer, index)
    if name == "_parse_integer_string" then
      return value
    end
    index = index + 1
  end
end

function TestNumberUtils:test_parse_integer_string_nil_returns_nil()
  _assert_eq(_parse_integer_string_upvalue(number_utils)(nil), nil, "nil input should parse to nil")
end

function TestNumberUtils:test_parse_integer_string_returns_raw_number_without_math_tointeger()
  local math_without_tointeger = {
    floor = math.floor,
  }

  support.with_patches({
    { key = "math", value = math_without_tointeger },
    { target = package.loaded, key = "src.foundation.number", value = nil },
  }, function()
    local fresh_number = require("src.foundation.number")
    local parser = _parse_integer_string_upvalue(fresh_number)
    _assert_eq(parser("42"), 42, "integer string should parse without math.tointeger")
    _assert_eq(parser("-7"), -7, "negative integer string should parse without math.tointeger")
  end)
end

function TestNumberUtils:test_empty_catalog_still_yields_one_page()
  _assert_eq(number_utils.page_count(0, 8), 1, "zero items should still be one page")
end

function TestNumberUtils:test_exact_multiple_yields_ceil_with_no_extra_page()
  _assert_eq(number_utils.page_count(16, 8), 2, "16 items at 8 per page = 2 pages")
end

function TestNumberUtils:test_partial_page_rounds_up()
  _assert_eq(number_utils.page_count(17, 8), 3, "17 items at 8 per page = 3 pages")
end

function TestNumberUtils:test_single_item_with_large_page_size_yields_one_page()
  _assert_eq(number_utils.page_count(1, 8), 1, "1 item at 8 per page = 1 page")
end

function TestNumberUtils:test_matches_skin_panel_page_size_6_arithmetic()
  _assert_eq(number_utils.page_count(6, 6), 1, "exactly one page")
  _assert_eq(number_utils.page_count(7, 6), 2, "one over the boundary spills to a new page")
  _assert_eq(number_utils.page_count(12, 6), 2, "double page exact")
end

function TestNumberUtils:test_accepts_integers_and_floats()
  _assert_eq(number_utils.is_numeric(0), true, "zero is numeric")
  _assert_eq(number_utils.is_numeric(12), true, "positive int is numeric")
  _assert_eq(number_utils.is_numeric(-7), true, "negative int is numeric")
  _assert_eq(number_utils.is_numeric(3.14), true, "float is numeric")
  _assert_eq(number_utils.is_numeric(1e18), true, "very large number is numeric")
end

function TestNumberUtils:test_rejects_nil()
  _assert_eq(number_utils.is_numeric(nil), false, "nil is not numeric")
end

function TestNumberUtils:test_rejects_strings_even_when_integer_shaped()
  _assert_eq(number_utils.is_numeric("12"), false, "string '12' is not numeric by design")
  _assert_eq(number_utils.is_numeric("3.14"), false, "string '3.14' is not numeric")
  _assert_eq(number_utils.is_numeric("abc"), false, "non-numeric string is not numeric")
  _assert_eq(number_utils.is_numeric(""), false, "empty string is not numeric")
end

function TestNumberUtils:test_rejects_booleans()
  _assert_eq(number_utils.is_numeric(true), false, "true is not numeric")
  _assert_eq(number_utils.is_numeric(false), false, "false is not numeric")
end

function TestNumberUtils:test_rejects_tables_and_functions()
  _assert_eq(number_utils.is_numeric({}), false, "empty table is not numeric")
  _assert_eq(number_utils.is_numeric({1, 2}), false, "list table is not numeric")
  _assert_eq(number_utils.is_numeric(function() end), false, "function is not numeric")
end

function TestNumberUtils:test_nil_returns_nil()
  _assert_eq(number_utils.to_integer(nil), nil, "nil → nil")
end

function TestNumberUtils:test_empty_string_returns_nil()
  _assert_eq(number_utils.to_integer(""), nil, "empty string → nil")
end

function TestNumberUtils:test_non_numeric_string_returns_nil()
  _assert_eq(number_utils.to_integer("abc"), nil, "letters → nil")
end

function TestNumberUtils:test_float_shaped_string_returns_nil()
  _assert_eq(number_utils.to_integer("3.14"), nil, "float string → nil")
  _assert_eq(number_utils.to_integer("12.0"), nil, "integer-shaped float string → nil (parser strict)")
end

function TestNumberUtils:test_whitespace_padded_string_returns_nil()
  _assert_eq(number_utils.to_integer(" 12"), nil, "leading space → nil")
  _assert_eq(number_utils.to_integer("12 "), nil, "trailing space → nil")
end

function TestNumberUtils:test_lone_minus_sign_returns_nil()
  _assert_eq(number_utils.to_integer("-"), nil, "bare minus → nil")
end

function TestNumberUtils:test_zero_parses_to_zero()
  _assert_eq(number_utils.to_integer("0"), 0, "string zero → 0")
  _assert_eq(number_utils.to_integer(0), 0, "number zero → 0")
end

function TestNumberUtils:test_negative_integer_parses()
  _assert_eq(number_utils.to_integer(-42), -42, "negative number stays")
  _assert_eq(number_utils.to_integer("-42"), -42, "negative string parses")
end

function TestNumberUtils:test_very_large_positive_integer_parses()
  _assert_eq(number_utils.to_integer("999999999999"), 999999999999, "12-digit int parses")
  _assert_eq(number_utils.to_integer(1000000000), 1000000000, "billion stays")
end

function TestNumberUtils:test_integer_shaped_float_truncates_via_tointeger()
  _assert_eq(number_utils.to_integer(12.0), 12, "12.0 → 12")
  _assert_eq(number_utils.to_integer(-7.0), -7, "-7.0 → -7")
end

function TestNumberUtils:test_non_integer_float_truncates_via_floor()
  _assert_eq(number_utils.to_integer(12.5), 12, "12.5 truncates down to 12")
  _assert_eq(number_utils.to_integer(12.99), 12, "12.99 floors to 12")
  _assert_eq(number_utils.to_integer(-7.5), -8, "negative floor rounds toward -inf")
end

function TestNumberUtils:test_booleans_return_nil()
  _assert_eq(number_utils.to_integer(true), nil, "true → nil (tostring='true' not integer)")
  _assert_eq(number_utils.to_integer(false), nil, "false → nil")
end

function TestNumberUtils:test_table_without_tostring_returns_nil()
  _assert_eq(number_utils.to_integer({}), nil, "plain table → nil (tostring is 'table: 0x...')")
end

function TestNumberUtils:test_value_within_range_passes_through()
  _assert_eq(number_utils.clamp(5, 1, 10), 5, "in-range value unchanged")
end

function TestNumberUtils:test_value_below_min_snaps_to_min()
  _assert_eq(number_utils.clamp(-5, 1, 10), 1, "below min → min")
  _assert_eq(number_utils.clamp(0, 1, 10), 1, "0 below min of 1 → 1")
end

function TestNumberUtils:test_value_above_max_snaps_to_max()
  _assert_eq(number_utils.clamp(15, 1, 10), 10, "above max → max")
end

function TestNumberUtils:test_nil_value_snaps_to_min()
  _assert_eq(number_utils.clamp(nil, 1, 10), 1, "nil → min (defensive default)")
end

function TestNumberUtils:test_boundary_values_stay()
  _assert_eq(number_utils.clamp(1, 1, 10), 1, "exactly min stays")
  _assert_eq(number_utils.clamp(10, 1, 10), 10, "exactly max stays")
end

function TestNumberUtils:test_returns_value_when_numeric()
  _assert_eq(number_utils.resolve_numeric(12, 0), 12, "numeric value used")
  _assert_eq(number_utils.resolve_numeric(3.14, 0), 3.14, "float value used")
  _assert_eq(number_utils.resolve_numeric(-7, 100), -7, "negative numeric value used")
end

function TestNumberUtils:test_falls_back_when_value_is_non_numeric()
  _assert_eq(number_utils.resolve_numeric(nil, 5), 5, "nil value → fallback")
  _assert_eq(number_utils.resolve_numeric("12", 5), 5, "string '12' not numeric → fallback")
  _assert_eq(number_utils.resolve_numeric("abc", 5), 5, "non-numeric string → fallback")
  _assert_eq(number_utils.resolve_numeric(true, 5), 5, "boolean → fallback")
  _assert_eq(number_utils.resolve_numeric({}, 5), 5, "table → fallback")
end

function TestNumberUtils:test_returns_nil_when_both_non_numeric()
  _assert_eq(number_utils.resolve_numeric(nil, nil), nil, "nil + nil → nil")
  _assert_eq(number_utils.resolve_numeric("abc", "xyz"), nil, "both non-numeric → nil")
  _assert_eq(number_utils.resolve_numeric(nil, "xyz"), nil, "nil + non-numeric fallback → nil")
end

function TestNumberUtils:test_formats_positive_integer()
  _assert_eq(number_utils.format_integer_part(12), "12", "positive int")
  _assert_eq(number_utils.format_integer_part(0), "0", "zero")
end

function TestNumberUtils:test_formats_negative_integer()
  _assert_eq(number_utils.format_integer_part(-7), "-7", "negative int")
end

function TestNumberUtils:test_truncates_float_to_integer_part()
  _assert_eq(number_utils.format_integer_part(12.5), "12", "12.5 → 12")
  _assert_eq(number_utils.format_integer_part(12.99), "12", "12.99 → 12")
  _assert_eq(number_utils.format_integer_part(-7.5), "-8", "negative floor rounds toward -inf")
end

function TestNumberUtils:test_non_numeric_falls_back_to_tostring()
  _assert_eq(number_utils.format_integer_part(nil), "nil", "nil → 'nil'")
  _assert_eq(number_utils.format_integer_part("abc"), "abc", "string → tostring")
  _assert_eq(number_utils.format_integer_part(true), "true", "boolean → tostring")
end

-- T16 mutation-pinning addendum.
-- Most of number.lua's 17 surviving mutants in T16 sweep are equivalent:
-- defensive layers (early-return guards, dual _tointeger/math.floor paths,
-- type-name table values backed by a fallback) collapse to identical observable
-- output. One mutation (L92 'and → or' in to_integer's tostring-fallback branch)
-- can be discriminated by a throwing __tostring metatable whose error message
-- parses as an integer.
function TestNumberUtils:test_returns_nil_when_tostring_throws_even_if_error_string_parses_as_integer()
  local wrapped = setmetatable({}, {
    __tostring = function() error("42", 0) end,
  })
  -- pcall(tostring, wrapped) → (false, "42"). Original at L92 is `if ok and
  -- type(as_text)=="string"`: ok=false → short-circuit false → skip parse →
  -- return nil. Mutated `or`: ok=false OR type("42")=="string" → true → enter
  -- L93 _parse_integer_string("42") = 42 → returns 42 instead of nil.
  _assert_eq(number_utils.to_integer(wrapped), nil,
    "to_integer must reject throwing __tostring; mutation would re-parse the error string")
end

-- ===== 迁自 test/property/test_number_utils.lua（#190, 测试极简化决策：property 车道退场，性质并入 behavior）=====
do

  local property = require("test.support.property")

  -- Wide-but-overflow-safe integer window: number_utils.to_integer parses decimal
  -- strings by hand, so generated ids stay well clear of 64-bit limits.
  local INT_BOUND = 1000000000 -- 1e9
  -- page_count divides as floats; keep its inputs where double division is exact
  -- so the ceiling relationship cannot be tripped by rounding noise.
  local PAGE_ITEMS = 100000
  local PAGE_SIZE = 500

  local function _gen_int(rng)
    return rng:int(-INT_BOUND, INT_BOUND)
  end

  local function _gen_bounds(rng)
    local low = rng:int(-INT_BOUND, INT_BOUND)
    return low, low + rng:int(0, INT_BOUND)
  end

  function TestNumberUtils:test_always_lands_within_min_max()
    property.for_all(function(rng)
      local low, high = _gen_bounds(rng)
      return { value = _gen_int(rng), low = low, high = high }
    end, function(case)
      local clamped = number_utils.clamp(case.value, case.low, case.high)
      lu.assertEvalToTrue(clamped >= case.low, "clamp result fell below min")
      lu.assertEvalToTrue(clamped <= case.high, "clamp result rose above max")
    end)
  end

  function TestNumberUtils:test_is_the_identity_inside_the_range()
    property.for_all(function(rng)
      local low, high = _gen_bounds(rng)
      return { value = rng:int(low, high), low = low, high = high }
    end, function(case)
      lu.assertEvalToTrue(number_utils.clamp(case.value, case.low, case.high) == case.value,
        "in-range value should be returned unchanged")
    end)
  end

  function TestNumberUtils:test_is_idempotent()
    property.for_all(function(rng)
      local low, high = _gen_bounds(rng)
      return { value = _gen_int(rng), low = low, high = high }
    end, function(case)
      local once = number_utils.clamp(case.value, case.low, case.high)
      local twice = number_utils.clamp(once, case.low, case.high)
      lu.assertEvalToTrue(once == twice, "clamping a clamped value should change nothing")
    end)
  end

  function TestNumberUtils:test_preserves_ordering_of_the_input_value()
    property.for_all(function(rng)
      local low, high = _gen_bounds(rng)
      local a, b = _gen_int(rng), _gen_int(rng)
      if b < a then a, b = b, a end
      return { a = a, b = b, low = low, high = high }
    end, function(case)
      local clamped_a = number_utils.clamp(case.a, case.low, case.high)
      local clamped_b = number_utils.clamp(case.b, case.low, case.high)
      lu.assertEvalToTrue(clamped_a <= clamped_b, "clamp must be monotonic non-decreasing")
    end)
  end

  function TestNumberUtils:test_round_trips_integers_through_their_decimal_string()
    property.for_all(_gen_int, function(n)
      lu.assertEvalToTrue(number_utils.to_integer(n) == n, "integer should pass through unchanged")
      lu.assertEvalToTrue(number_utils.to_integer(tostring(n)) == n, "decimal string should parse back to the integer")
    end)
  end

  function TestNumberUtils:test_round_trips_integers_through_format_integer_part()
    property.for_all(_gen_int, function(n)
      local text = number_utils.format_integer_part(n)
      lu.assertEvalToTrue(number_utils.to_integer(text) == n,
        "format_integer_part then to_integer should recover the integer")
    end)
  end

  function TestNumberUtils:test_always_reports_at_least_one_page()
    property.for_all(function(rng)
      return { items = rng:int(0, PAGE_ITEMS), size = rng:int(1, PAGE_SIZE) }
    end, function(case)
      lu.assertEvalToTrue(number_utils.page_count(case.items, case.size) >= 1, "page count must floor at one")
    end)
  end

  function TestNumberUtils:test_satisfies_the_ceiling_relationship_for_non_empty_catalogs()
    property.for_all(function(rng)
      return { items = rng:int(1, PAGE_ITEMS), size = rng:int(1, PAGE_SIZE) }
    end, function(case)
      local pages = number_utils.page_count(case.items, case.size)
      lu.assertEvalToTrue((pages - 1) * case.size < case.items, "the previous page boundary must sit below the item count")
      lu.assertEvalToTrue(case.items <= pages * case.size, "the item count must fit inside the reported pages")
    end)
  end

  function TestNumberUtils:test_never_needs_fewer_pages_for_more_items()
    property.for_all(function(rng)
      local size = rng:int(1, PAGE_SIZE)
      local a, b = rng:int(0, PAGE_ITEMS), rng:int(0, PAGE_ITEMS)
      if b < a then a, b = b, a end
      return { a = a, b = b, size = size }
    end, function(case)
      lu.assertEvalToTrue(number_utils.page_count(case.a, case.size) <= number_utils.page_count(case.b, case.size),
        "page count must be monotonic in item count")
    end)
  end

  function TestNumberUtils:test_subtracts_numeric_operands()
    property.for_all(function(rng)
      return { a = _gen_int(rng), b = _gen_int(rng) }
    end, function(case)
      lu.assertEvalToTrue(number_utils.diff_or_zero(case.a, case.b) == case.a - case.b, "numeric diff should subtract")
    end)
  end

  function TestNumberUtils:test_is_antisymmetric()
    property.for_all(function(rng)
      return { a = _gen_int(rng), b = _gen_int(rng) }
    end, function(case)
      lu.assertEvalToTrue(number_utils.diff_or_zero(case.a, case.b) == -number_utils.diff_or_zero(case.b, case.a),
        "swapping operands should negate the difference")
    end)
  end

  function TestNumberUtils:test_falls_back_to_zero_when_an_operand_is_non_numeric()
    property.for_all(function(rng)
      return { a = _gen_int(rng), text = "x" .. tostring(rng:int(0, INT_BOUND)) }
    end, function(case)
      lu.assertEvalToTrue(number_utils.diff_or_zero(case.a, case.text) == 0, "non-numeric second operand yields zero")
      lu.assertEvalToTrue(number_utils.diff_or_zero(case.text, case.a) == 0, "non-numeric first operand yields zero")
    end)
  end

  function TestNumberUtils:test_returns_the_primary_value_when_it_is_numeric()
    property.for_all(function(rng)
      return { value = _gen_int(rng), fallback = _gen_int(rng) }
    end, function(case)
      lu.assertEvalToTrue(number_utils.resolve_numeric(case.value, case.fallback) == case.value,
        "a numeric primary value should win")
    end)
  end

  function TestNumberUtils:test_defers_to_a_numeric_fallback_when_the_primary_is_non_numeric()
    property.for_all(function(rng)
      return { text = "n" .. tostring(rng:int(0, INT_BOUND)), fallback = _gen_int(rng) }
    end, function(case)
      lu.assertEvalToTrue(number_utils.resolve_numeric(case.text, case.fallback) == case.fallback,
        "a non-numeric primary should defer to the numeric fallback")
    end)
  end
end


return TestNumberUtils
