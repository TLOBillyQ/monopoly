local player_colors = require("src.presentation.shared.PlayerColors")

local function _assert_eq(actual, expected, msg)
  assert(actual == expected, (msg or "") .. " expected=" .. tostring(expected) .. " actual=" .. tostring(actual))
end

local function _test_remap_by_index_integer_ids()
  player_colors.remap_by_index({
    { id = 1 }, { id = 2 }, { id = 3 }, { id = 4 },
  })
  _assert_eq(player_colors.resolve_owner_color(1), 0x4fc3f7, "player 1 should be blue")
  _assert_eq(player_colors.resolve_owner_color(2), 0x81c784, "player 2 should be green")
  _assert_eq(player_colors.resolve_owner_color(3), 0xffb74d, "player 3 should be orange")
  _assert_eq(player_colors.resolve_owner_color(4), 0xe57373, "player 4 should be red")
  _assert_eq(player_colors.resolve_owner_color(999), 0xcfcfcf, "unknown id returns default")
end

local function _test_remap_by_index_role_ids()
  player_colors.remap_by_index({
    { id = "role_abc" }, { id = "role_def" }, { id = 9999 },
  })
  _assert_eq(player_colors.resolve_owner_color("role_abc"), 0x4fc3f7, "role_abc should be blue (index 1)")
  _assert_eq(player_colors.resolve_owner_color("role_def"), 0x81c784, "role_def should be green (index 2)")
  _assert_eq(player_colors.resolve_owner_color(9999), 0xffb74d, "9999 should be orange (index 3)")
  _assert_eq(player_colors.resolve_owner_color(1), 0xcfcfcf, "integer 1 should no longer match")
end

local function _test_remap_by_index_caps_at_4()
  player_colors.remap_by_index({
    { id = "a" }, { id = "b" }, { id = "c" }, { id = "d" }, { id = "e" },
  })
  _assert_eq(player_colors.resolve_owner_color("d"), 0xe57373, "4th player should be red")
  _assert_eq(player_colors.resolve_owner_color("e"), 0xcfcfcf, "5th player has no color")
end

local function _test_remap_by_index_nil_safe()
  player_colors.remap_by_index(nil)
  player_colors.remap_by_index({})
  _assert_eq(player_colors.resolve_owner_color(1), 0xcfcfcf, "empty remap returns default")
end

return {
  name = "presentation_player_colors",
  tests = {
    { name = "remap_by_index_integer_ids", run = _test_remap_by_index_integer_ids },
    { name = "remap_by_index_role_ids", run = _test_remap_by_index_role_ids },
    { name = "remap_by_index_caps_at_4", run = _test_remap_by_index_caps_at_4 },
    { name = "remap_by_index_nil_safe", run = _test_remap_by_index_nil_safe },
  },
}
