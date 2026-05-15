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
end)
