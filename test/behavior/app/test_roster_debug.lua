require("test.bootstrap").install_package_paths()
local luassert = assert
local roster_debug = require("src.app.roster_debug")
local debug_flags = require("src.config.gameplay.debug_flags")

local function _count(map)
  local n = 0
  for _ in pairs(map or {}) do
    n = n + 1
  end
  return n
end

describe("TestRosterDebug", function()
  after_each(function()
    debug_flags.reset()
  end)

local function _test_returns_nil_by_default_because_debug_auto_all_roles_defaults_off()
  debug_flags.reset()
  local result = roster_debug.build_auto_players(
    { { role_id = 1 }, { role_id = 2 }, { role_id = 3 } }
  )
  luassert.truthy(result == nil, "default flags must never auto-drive any seat")
end

local function _test_returns_nil_when_debug_auto_all_roles_is_disabled()
  debug_flags.debug_auto_all_roles = false
  local result = roster_debug.build_auto_players(
    { { role_id = 1 }, { role_id = 2 } }
  )
  luassert.truthy(result == nil, "disabled debug flag must not produce an auto map")
end

local function _test_marks_every_seat_including_the_primary_one_when_the_flag_is_on()
  debug_flags.debug_auto_all_roles = true
  local result = roster_debug.build_auto_players(
    { { role_id = 11 }, { role_id = 22 }, { role_id = 33 } }
  )
  luassert.truthy(result ~= nil, "flag on should produce an auto map")
  luassert.truthy(result[11] == true, "the primary seat should be auto-driven under all-roles debug")
  luassert.truthy(result[22] == true, "second seat should be auto-driven")
  luassert.truthy(result[33] == true, "third seat should be auto-driven")
  luassert.truthy(_count(result) == 3, "every seat should be marked")
end

local function _test_skips_entries_without_a_role_id_but_keeps_later_valid_seats()
  debug_flags.debug_auto_all_roles = true
  local result = roster_debug.build_auto_players(
    { { role_id = 1 }, { role_id = nil }, { role_id = 7 } }
  )
  luassert.truthy(result ~= nil, "valid seats should still produce a map")
  luassert.truthy(result[1] == true, "the first seat should be auto-driven")
  luassert.truthy(result[7] == true, "the valid later seat should be auto-driven")
  luassert.truthy(_count(result) == 2, "the role_id-less seat should contribute no entry")
end

local function _test_marks_the_lone_primary_seat_when_all_roles_debug_is_on()
  debug_flags.debug_auto_all_roles = true
  local result = roster_debug.build_auto_players({ { role_id = 5 } })
  luassert.truthy(result ~= nil, "all-roles debug should mark even a single-seat roster")
  luassert.truthy(result[5] == true, "the lone primary seat should be auto-driven")
  luassert.truthy(_count(result) == 1, "only the present seat should be marked")
end

local function _test_all_roles_debug_starts_from_slot_one_not_zero()
  -- #293:L17 `1` -> `0` 只在 0 号槽有内容时可分——钉住「从 1 号位开始」的边界。
  debug_flags.debug_auto_all_roles = true
  local result = roster_debug.build_auto_players({
    [0] = { role_id = 99 },
  })
  luassert.truthy(result == nil,
    "all-roles debug must start from slot 1, so an index-0-only roster yields nothing")
end


it("test_returns_nil_by_default_because_debug_auto_all_roles_defaults_off", _test_returns_nil_by_default_because_debug_auto_all_roles_defaults_off)
it("test_returns_nil_when_debug_auto_all_roles_is_disabled", _test_returns_nil_when_debug_auto_all_roles_is_disabled)
it("test_marks_every_seat_including_the_primary_one_when_the_flag_is_on", _test_marks_every_seat_including_the_primary_one_when_the_flag_is_on)
it("test_skips_entries_without_a_role_id_but_keeps_later_valid_seats", _test_skips_entries_without_a_role_id_but_keeps_later_valid_seats)
it("test_marks_the_lone_primary_seat_when_all_roles_debug_is_on", _test_marks_the_lone_primary_seat_when_all_roles_debug_is_on)
it("test_all_roles_debug_starts_from_slot_one_not_zero", _test_all_roles_debug_starts_from_slot_one_not_zero)
end)
