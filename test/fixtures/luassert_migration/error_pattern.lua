local luassert = assert
local function boom() error("remove_by_index: index out of bounds: 7") end
describe("TestLuassertFixtureErrorPattern", function()
  it("test_control_error_pattern_and_plain_substring_both_match", function()
    luassert.has_error.match(boom, "index out of bounds: %d+")
    luassert.has_error.match(boom, "out of bounds: 7", 1, true)
  end)
  it("test_counterexample_non_matching_error_pattern_fails", function()
    luassert.has_error.match(boom, "NEVER_MATCHES_THIS_PATTERN", 1, true)
  end)
end)
