-- 原生 LuaUnit(推翻自研 busted 兼容运行器决策的迁移):describe/it 拍平为文件级 Test* 类,
-- after_each → tearDown,断言从裸 assert 切到 lu.assertEvalToTrue,
-- 用例数与改写前一一对应(5 例)。

local lu = require("luaunit")
local roster_debug = require("src.app.roster_debug")
local debug_flags = require("src.config.gameplay.debug_flags")

local function _count(map)
  local n = 0
  for _ in pairs(map or {}) do
    n = n + 1
  end
  return n
end

TestRosterDebug = {}

function TestRosterDebug:tearDown()
  debug_flags.reset()
end

function TestRosterDebug:test_returns_nil_by_default_because_debug_auto_all_roles_defaults_off()
  debug_flags.reset()
  local result = roster_debug.build_auto_players(
    { { role_id = 1 }, { role_id = 2 }, { role_id = 3 } }
  )
  lu.assertEvalToTrue(result == nil, "default flags must never auto-drive any seat")
end

function TestRosterDebug:test_returns_nil_when_debug_auto_all_roles_is_disabled()
  debug_flags.debug_auto_all_roles = false
  local result = roster_debug.build_auto_players(
    { { role_id = 1 }, { role_id = 2 } }
  )
  lu.assertEvalToTrue(result == nil, "disabled debug flag must not produce an auto map")
end

function TestRosterDebug:test_marks_every_seat_including_the_primary_one_when_the_flag_is_on()
  debug_flags.debug_auto_all_roles = true
  local result = roster_debug.build_auto_players(
    { { role_id = 11 }, { role_id = 22 }, { role_id = 33 } }
  )
  lu.assertEvalToTrue(result ~= nil, "flag on should produce an auto map")
  lu.assertEvalToTrue(result[11] == true, "the primary seat should be auto-driven under all-roles debug")
  lu.assertEvalToTrue(result[22] == true, "second seat should be auto-driven")
  lu.assertEvalToTrue(result[33] == true, "third seat should be auto-driven")
  lu.assertEvalToTrue(_count(result) == 3, "every seat should be marked")
end

function TestRosterDebug:test_skips_entries_without_a_role_id_but_keeps_later_valid_seats()
  debug_flags.debug_auto_all_roles = true
  local result = roster_debug.build_auto_players(
    { { role_id = 1 }, { role_id = nil }, { role_id = 7 } }
  )
  lu.assertEvalToTrue(result ~= nil, "valid seats should still produce a map")
  lu.assertEvalToTrue(result[1] == true, "the first seat should be auto-driven")
  lu.assertEvalToTrue(result[7] == true, "the valid later seat should be auto-driven")
  lu.assertEvalToTrue(_count(result) == 2, "the role_id-less seat should contribute no entry")
end

function TestRosterDebug:test_marks_the_lone_primary_seat_when_all_roles_debug_is_on()
  debug_flags.debug_auto_all_roles = true
  local result = roster_debug.build_auto_players({ { role_id = 5 } })
  lu.assertEvalToTrue(result ~= nil, "all-roles debug should mark even a single-seat roster")
  lu.assertEvalToTrue(result[5] == true, "the lone primary seat should be auto-driven")
  lu.assertEvalToTrue(_count(result) == 1, "only the present seat should be marked")
end

function TestRosterDebug:test_all_roles_debug_starts_from_slot_one_not_zero()
  -- #293:L17 `1` -> `0` 只在 0 号槽有内容时可分——钉住「从 1 号位开始」的边界。
  debug_flags.debug_auto_all_roles = true
  local result = roster_debug.build_auto_players({
    [0] = { role_id = 99 },
  })
  lu.assertEvalToTrue(result == nil,
    "all-roles debug must start from slot 1, so an index-0-only roster yields nothing")
end


return TestRosterDebug
