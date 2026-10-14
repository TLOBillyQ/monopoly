local luassert = assert
local function boom() error({ code = 9, kind = "guard" }) end
describe("TestLuassertFixtureErrorTablePayload", function()
  it("test_control_table_error_payload_deep_compares_and_type_assertions_hold", function()
    luassert.has_error(boom, { code = 9, kind = "guard" })
    luassert.is_table({})
    luassert.is_string("x")
    luassert.is_number(1)
  end)
  it("test_counterexample_mismatched_table_error_payload_fails", function()
    luassert.has_error(boom, { code = 8, kind = "guard" })
  end)
end)
