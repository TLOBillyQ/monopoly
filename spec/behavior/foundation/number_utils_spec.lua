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
end)
