local support = require("TestSupport")
local _assert_eq = support.assert_eq
local number_utils = support.number_utils

local function _test_number_utils_to_integer()
  _assert_eq(number_utils.to_integer("12"), 12, "string integer should parse")
  _assert_eq(number_utils.to_integer("-7"), -7, "negative string integer should parse")
  _assert_eq(number_utils.to_integer("12.3"), nil, "float string should be rejected")
end

return {
  _test_number_utils_to_integer,
}
