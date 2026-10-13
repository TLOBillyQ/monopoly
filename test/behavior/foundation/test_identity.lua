require("test.bootstrap").install_package_paths()
-- busted injects the extensible assertion object into each file environment.
-- luacheck: ignore 143
local luassert = assert
---@diagnostic disable: need-check-nil, undefined-field

local function _assert_eq(a, b, msg) luassert.is.equal(b, a, msg) end
local role_id = require("src.foundation.identity")

local function _labelled(text)
  return setmetatable({}, {
    __tostring = function()
      return text
    end,
  })
end

describe("TestRoleIdIdentity", function()

  it("test_normalize_returns_nil_for_nil", function()
    _assert_eq(role_id.normalize(nil), nil, "nil normalizes to nil")
  end)

  it("test_normalize_coerces_numeric_ids_and_numeric_strings_to_integers", function()
    _assert_eq(role_id.normalize(5), 5, "integer id stays an integer")
    _assert_eq(role_id.normalize("7"), 7, "numeric string becomes an integer")
  end)

  it("test_normalize_keeps_non_numeric_strings_unchanged", function()
    _assert_eq(role_id.normalize("hero"), "hero", "non-numeric string is preserved")
  end)

  it("test_normalize_falls_back_to_tostring_for_non_string_non_numeric_values", function()
    _assert_eq(role_id.normalize(_labelled("guild")), "guild", "tostring fallback supplies the id")
  end)

  it("test_normalize_returns_nil_when_the_tostring_fallback_is_empty", function()
    _assert_eq(role_id.normalize(_labelled("")), nil, "an empty tostring fallback yields nil")
  end)

  it("test_equals_treats_numeric_and_string_forms_of_an_id_as_equal", function()
    _assert_eq(role_id.equals(3, "3"), true, "3 and \"3\" are the same role")
  end)

  it("test_equals_is_false_for_different_ids", function()
    _assert_eq(role_id.equals(3, 4), false, "different ids are not equal")
  end)

  it("test_equals_is_false_when_either_side_normalizes_to_nil", function()
    _assert_eq(role_id.equals(nil, 3), false, "nil never equals a real id")
    _assert_eq(role_id.equals(_labelled(""), 3), false, "an unnormalizable value never equals a real id")
  end)

  it("test_read_returns_nil_when_the_map_is_not_a_table", function()
    _assert_eq(role_id.read(nil, 1), nil, "a nil map reads nil")
    _assert_eq(role_id.read("nope", 1), nil, "a non-table map reads nil")
  end)

  it("test_read_reads_through_the_normalized_integer_key", function()
    _assert_eq(role_id.read({ [1] = "a" }, "1"), "a", "a string key resolves to the integer slot")
  end)

  it("test_read_falls_back_to_the_stringified_normalized_key", function()
    _assert_eq(role_id.read({ ["1"] = "a" }, 1), "a", "an integer key resolves to the string slot")
  end)

  it("test_read_falls_back_to_the_raw_key_when_normalization_fails", function()
    local raw = _labelled("")
    _assert_eq(role_id.read({ [raw] = "value" }, raw), "value", "an unnormalizable key still resolves raw")
  end)

  it("test_read_returns_nil_when_no_slot_matches", function()
    _assert_eq(role_id.read({ [1] = "a" }, 2), nil, "a missing key reads nil")
  end)

  it("test_write_returns_nil_when_the_map_is_not_a_table", function()
    _assert_eq(role_id.write(nil, 1, "x"), nil, "a nil map writes nothing")
  end)

  it("test_write_returns_nil_when_the_key_cannot_be_normalized", function()
    _assert_eq(role_id.write({}, _labelled(""), "x"), nil, "an unnormalizable key writes nothing")
  end)

  it("test_write_writes_under_the_normalized_integer_key_and_clears_the_string_duplicate", function()
    local map = { ["5"] = "stale" }
    local written = role_id.write(map, 5, "fresh")
    _assert_eq(written, 5, "write returns the normalized key")
    _assert_eq(map[5], "fresh", "value is stored under the integer key")
    _assert_eq(map["5"], nil, "the string-keyed duplicate is cleared")
  end)

  it("test_write_writes_string_ids_without_clearing_anything", function()
    local map = {}
    local written = role_id.write(map, "hero", "v")
    _assert_eq(written, "hero", "a string id is returned unchanged")
    _assert_eq(map["hero"], "v", "value is stored under the string key")
  end)


end)
