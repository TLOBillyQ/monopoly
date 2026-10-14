local luassert = assert
local function boom() error("余额不足: -1") end
describe("TestLuassertFixtureErrorText", function()
  it("test_control_error_text_matches_exactly_after_location_stripping", function()
    luassert.has_error(boom, "余额不足: -1")
    luassert.has_error(function() error("plain", 0) end, "plain")
  end)
  it("test_counterexample_wrong_expected_error_text_fails", function()
    luassert.has_error(boom, "余额不足")
  end)
end)
