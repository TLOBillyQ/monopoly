---@diagnostic disable: need-check-nil

local property = require("spec.support.property")
local number_utils = require("src.foundation.number")

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

describe("number_utils properties", function()
  describe("clamp", function()
    it("always lands within [min, max]", function()
      property.for_all(function(rng)
        local low, high = _gen_bounds(rng)
        return { value = _gen_int(rng), low = low, high = high }
      end, function(case)
        local clamped = number_utils.clamp(case.value, case.low, case.high)
        assert(clamped >= case.low, "clamp result fell below min")
        assert(clamped <= case.high, "clamp result rose above max")
      end)
    end)

    it("is the identity inside the range", function()
      property.for_all(function(rng)
        local low, high = _gen_bounds(rng)
        return { value = rng:int(low, high), low = low, high = high }
      end, function(case)
        assert(number_utils.clamp(case.value, case.low, case.high) == case.value,
          "in-range value should be returned unchanged")
      end)
    end)

    it("is idempotent", function()
      property.for_all(function(rng)
        local low, high = _gen_bounds(rng)
        return { value = _gen_int(rng), low = low, high = high }
      end, function(case)
        local once = number_utils.clamp(case.value, case.low, case.high)
        local twice = number_utils.clamp(once, case.low, case.high)
        assert(once == twice, "clamping a clamped value should change nothing")
      end)
    end)

    it("preserves ordering of the input value", function()
      property.for_all(function(rng)
        local low, high = _gen_bounds(rng)
        local a, b = _gen_int(rng), _gen_int(rng)
        if b < a then a, b = b, a end
        return { a = a, b = b, low = low, high = high }
      end, function(case)
        local clamped_a = number_utils.clamp(case.a, case.low, case.high)
        local clamped_b = number_utils.clamp(case.b, case.low, case.high)
        assert(clamped_a <= clamped_b, "clamp must be monotonic non-decreasing")
      end)
    end)
  end)

  describe("to_integer", function()
    it("round-trips integers through their decimal string", function()
      property.for_all(_gen_int, function(n)
        assert(number_utils.to_integer(n) == n, "integer should pass through unchanged")
        assert(number_utils.to_integer(tostring(n)) == n, "decimal string should parse back to the integer")
      end)
    end)

    it("round-trips integers through format_integer_part", function()
      property.for_all(_gen_int, function(n)
        local text = number_utils.format_integer_part(n)
        assert(number_utils.to_integer(text) == n,
          "format_integer_part then to_integer should recover the integer")
      end)
    end)
  end)

  describe("page_count", function()
    it("always reports at least one page", function()
      property.for_all(function(rng)
        return { items = rng:int(0, PAGE_ITEMS), size = rng:int(1, PAGE_SIZE) }
      end, function(case)
        assert(number_utils.page_count(case.items, case.size) >= 1, "page count must floor at one")
      end)
    end)

    it("satisfies the ceiling relationship for non-empty catalogs", function()
      property.for_all(function(rng)
        return { items = rng:int(1, PAGE_ITEMS), size = rng:int(1, PAGE_SIZE) }
      end, function(case)
        local pages = number_utils.page_count(case.items, case.size)
        assert((pages - 1) * case.size < case.items, "the previous page boundary must sit below the item count")
        assert(case.items <= pages * case.size, "the item count must fit inside the reported pages")
      end)
    end)

    it("never needs fewer pages for more items", function()
      property.for_all(function(rng)
        local size = rng:int(1, PAGE_SIZE)
        local a, b = rng:int(0, PAGE_ITEMS), rng:int(0, PAGE_ITEMS)
        if b < a then a, b = b, a end
        return { a = a, b = b, size = size }
      end, function(case)
        assert(number_utils.page_count(case.a, case.size) <= number_utils.page_count(case.b, case.size),
          "page count must be monotonic in item count")
      end)
    end)
  end)

  describe("diff_or_zero", function()
    it("subtracts numeric operands", function()
      property.for_all(function(rng)
        return { a = _gen_int(rng), b = _gen_int(rng) }
      end, function(case)
        assert(number_utils.diff_or_zero(case.a, case.b) == case.a - case.b, "numeric diff should subtract")
      end)
    end)

    it("is antisymmetric", function()
      property.for_all(function(rng)
        return { a = _gen_int(rng), b = _gen_int(rng) }
      end, function(case)
        assert(number_utils.diff_or_zero(case.a, case.b) == -number_utils.diff_or_zero(case.b, case.a),
          "swapping operands should negate the difference")
      end)
    end)

    it("falls back to zero when an operand is non-numeric", function()
      property.for_all(function(rng)
        return { a = _gen_int(rng), text = "x" .. tostring(rng:int(0, INT_BOUND)) }
      end, function(case)
        assert(number_utils.diff_or_zero(case.a, case.text) == 0, "non-numeric second operand yields zero")
        assert(number_utils.diff_or_zero(case.text, case.a) == 0, "non-numeric first operand yields zero")
      end)
    end)
  end)

  describe("resolve_numeric", function()
    it("returns the primary value when it is numeric", function()
      property.for_all(function(rng)
        return { value = _gen_int(rng), fallback = _gen_int(rng) }
      end, function(case)
        assert(number_utils.resolve_numeric(case.value, case.fallback) == case.value,
          "a numeric primary value should win")
      end)
    end)

    it("defers to a numeric fallback when the primary is non-numeric", function()
      property.for_all(function(rng)
        return { text = "n" .. tostring(rng:int(0, INT_BOUND)), fallback = _gen_int(rng) }
      end, function(case)
        assert(number_utils.resolve_numeric(case.text, case.fallback) == case.fallback,
          "a non-numeric primary should defer to the numeric fallback")
      end)
    end)
  end)
end)
