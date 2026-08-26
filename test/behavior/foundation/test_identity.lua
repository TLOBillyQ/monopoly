---@diagnostic disable: need-check-nil, undefined-field

local support = require("test.support.shared_support")
local _assert_eq = support.assert_eq
local role_id = require("src.foundation.identity")

local function _labelled(text)
  return setmetatable({}, {
    __tostring = function()
      return text
    end,
  })
end

-- 原生 LuaUnit 迁移:describe 嵌套(normalize/equals/read/write)均无钩子,按规则
-- 不拆类,直接合并进外层 TestRoleIdIdentity,方法名以 describe 名作前缀保证唯一
-- 且保留原嵌套语义;断言仍走 shared_support.assert_eq,用例数与改写前一一对应
-- (5 + 3 + 5 + 4 = 17 例)。
TestRoleIdIdentity = {}

function TestRoleIdIdentity:test_normalize_returns_nil_for_nil()
  _assert_eq(role_id.normalize(nil), nil, "nil normalizes to nil")
end

function TestRoleIdIdentity:test_normalize_coerces_numeric_ids_and_numeric_strings_to_integers()
  _assert_eq(role_id.normalize(5), 5, "integer id stays an integer")
  _assert_eq(role_id.normalize("7"), 7, "numeric string becomes an integer")
end

function TestRoleIdIdentity:test_normalize_keeps_non_numeric_strings_unchanged()
  _assert_eq(role_id.normalize("hero"), "hero", "non-numeric string is preserved")
end

function TestRoleIdIdentity:test_normalize_falls_back_to_tostring_for_non_string_non_numeric_values()
  _assert_eq(role_id.normalize(_labelled("guild")), "guild", "tostring fallback supplies the id")
end

function TestRoleIdIdentity:test_normalize_returns_nil_when_the_tostring_fallback_is_empty()
  _assert_eq(role_id.normalize(_labelled("")), nil, "an empty tostring fallback yields nil")
end

function TestRoleIdIdentity:test_equals_treats_numeric_and_string_forms_of_an_id_as_equal()
  _assert_eq(role_id.equals(3, "3"), true, "3 and \"3\" are the same role")
end

function TestRoleIdIdentity:test_equals_is_false_for_different_ids()
  _assert_eq(role_id.equals(3, 4), false, "different ids are not equal")
end

function TestRoleIdIdentity:test_equals_is_false_when_either_side_normalizes_to_nil()
  _assert_eq(role_id.equals(nil, 3), false, "nil never equals a real id")
  _assert_eq(role_id.equals(_labelled(""), 3), false, "an unnormalizable value never equals a real id")
end

function TestRoleIdIdentity:test_read_returns_nil_when_the_map_is_not_a_table()
  _assert_eq(role_id.read(nil, 1), nil, "a nil map reads nil")
  _assert_eq(role_id.read("nope", 1), nil, "a non-table map reads nil")
end

function TestRoleIdIdentity:test_read_reads_through_the_normalized_integer_key()
  _assert_eq(role_id.read({ [1] = "a" }, "1"), "a", "a string key resolves to the integer slot")
end

function TestRoleIdIdentity:test_read_falls_back_to_the_stringified_normalized_key()
  _assert_eq(role_id.read({ ["1"] = "a" }, 1), "a", "an integer key resolves to the string slot")
end

function TestRoleIdIdentity:test_read_falls_back_to_the_raw_key_when_normalization_fails()
  local raw = _labelled("")
  _assert_eq(role_id.read({ [raw] = "value" }, raw), "value", "an unnormalizable key still resolves raw")
end

function TestRoleIdIdentity:test_read_returns_nil_when_no_slot_matches()
  _assert_eq(role_id.read({ [1] = "a" }, 2), nil, "a missing key reads nil")
end

function TestRoleIdIdentity:test_write_returns_nil_when_the_map_is_not_a_table()
  _assert_eq(role_id.write(nil, 1, "x"), nil, "a nil map writes nothing")
end

function TestRoleIdIdentity:test_write_returns_nil_when_the_key_cannot_be_normalized()
  _assert_eq(role_id.write({}, _labelled(""), "x"), nil, "an unnormalizable key writes nothing")
end

function TestRoleIdIdentity:test_write_writes_under_the_normalized_integer_key_and_clears_the_string_duplicate()
  local map = { ["5"] = "stale" }
  local written = role_id.write(map, 5, "fresh")
  _assert_eq(written, 5, "write returns the normalized key")
  _assert_eq(map[5], "fresh", "value is stored under the integer key")
  _assert_eq(map["5"], nil, "the string-keyed duplicate is cleared")
end

function TestRoleIdIdentity:test_write_writes_string_ids_without_clearing_anything()
  local map = {}
  local written = role_id.write(map, "hero", "v")
  _assert_eq(written, "hero", "a string id is returned unchanged")
  _assert_eq(map["hero"], "v", "value is stored under the string key")
end


return TestRoleIdIdentity
