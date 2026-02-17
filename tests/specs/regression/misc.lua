local support = require("TestSupport")
local _assert_eq = support.assert_eq
local number_utils = support.number_utils

local function _test_number_utils_to_integer()
  _assert_eq(number_utils.to_integer("12"), 12, "string integer should parse")
  _assert_eq(number_utils.to_integer("-7"), -7, "negative string integer should parse")
  _assert_eq(number_utils.to_integer("12.3"), nil, "float string should be rejected")
end

local _tests = {
  _test_number_utils_to_integer,
}

local _cases = {}
for index, run in ipairs(_tests) do
  _cases[#_cases + 1] = {
    id = "misc.case_" .. tostring(index),
    desc = "misc migrated case " .. tostring(index),
    run = run,
  }
end

return {
  layer = "regression",
  domain = "misc",
  cases = _cases,
}
