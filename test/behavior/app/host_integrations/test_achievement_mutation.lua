-- Mutation-pinning specs for src/app/host_integrations/achievement.lua.
-- Catalog ids are 1..45 contiguous; progress events include "游戏胜利" -> {1,2,3,4}.
--
-- 原生 LuaUnit(推翻自研 busted 兼容运行器决策的迁移):三个平级 describe 拍平成三个 Test* 类,
-- after_each → tearDown,断言从裸 assert 切到 lu.assertEvalToTrue,
-- 用例数与改写前一一对应(5 例)。

local lu = require("luaunit")
local achievement = require("src.app.host_integrations.achievement")

TestAchievementMappedIdsForEvent = {}

function TestAchievementMappedIdsForEvent:tearDown()
  achievement.reset_for_tests()
end

function TestAchievementMappedIdsForEvent:test_returns_a_copy_of_the_mapped_ids_for_a_known_event_l15_ipairs_nil_l132_nil()
  local ids = achievement.mapped_ids_for_event("游戏胜利")
  -- L132 `_copy_ids(mapped.ids)` -> nil would return nil.
  lu.assertEvalToTrue(type(ids) == "table", "mapped ids must be a table; got " .. type(ids))
  -- L15 `ipairs(ids or {})` -> nil crashes the copy loop, failing (killing) the test.
  lu.assertEvalToTrue(#ids == 4, "游戏胜利 must map to 4 ids; got " .. tostring(#ids))
  lu.assertEvalToTrue(ids[1] == 1 and ids[2] == 2 and ids[3] == 3 and ids[4] == 4,
    "mapped ids must be {1,2,3,4}; got " .. tostring(ids[1]) .. "," .. tostring(ids[2])
    .. "," .. tostring(ids[3]) .. "," .. tostring(ids[4]))
end

function TestAchievementMappedIdsForEvent:test_returns_an_empty_table_for_an_unknown_event_l129()
  -- L129 `mapped == nil` -> `mapped ~= nil`: for a missing event the mutant
  -- skips the empty-return and indexes nil.ids, crashing (killing) the test.
  local ids = achievement.mapped_ids_for_event("no_such_event_zzz")
  lu.assertEvalToTrue(type(ids) == "table", "unknown event must return a table; got " .. type(ids))
  lu.assertEvalToTrue(#ids == 0, "unknown event must return an empty table; got #" .. tostring(#ids))
end

TestAchievementIdsAreContiguous = {}

function TestAchievementIdsAreContiguous:test_returns_false_when_the_range_count_matches_but_an_id_is_missing_l69_false_to_true()
  -- Catalog holds 45 ids (1..45). Range [2,46] has count 45 == #catalog, so the
  -- count guard passes and _has_every_id runs: find(46) is nil.
  -- L69 `return false` -> `true` would make the missing id look present.
  lu.assertEvalToTrue(achievement.ids_are_contiguous(2, 46) == false,
    "range [2,46] contains missing id 46 and must not be contiguous")
end

function TestAchievementIdsAreContiguous:test_returns_true_for_the_real_contiguous_range_1_45_sanity()
  lu.assertEvalToTrue(achievement.ids_are_contiguous(1, 45) == true,
    "the full catalog range must be contiguous")
end

TestAchievementCategoryCounts = {}

function TestAchievementCategoryCounts:test_counts_entries_per_category_l100()
  -- Catalog distribution (runtime): 简单=11 普通=6 困难=8 传奇=12 隐藏=8, total 45.
  -- L100 `tostring(entry.category or "")` -> nil crashes `counts[nil] = ...`.
  local counts = achievement.category_counts()
  lu.assertEvalToTrue(type(counts) == "table", "category_counts must return a table; got " .. type(counts))
  lu.assertEvalToTrue(counts["简单"] == 11 and counts["传奇"] == 12,
    "catalog category distribution is 简单=11 传奇=12; got " .. tostring(counts["简单"]) .. "," .. tostring(counts["传奇"]))
  local total = 0
  for _, count in pairs(counts) do
    total = total + count
  end
  lu.assertEvalToTrue(total == 45,
    "category counts must total the catalog size 45; got " .. tostring(total))
end

TestAchievementSetProgress = {}

function TestAchievementSetProgress:tearDown()
  achievement.reset_for_tests()
end

function TestAchievementSetProgress:test_returns_the_apply_progress_boolean_result_l152_to_nil()
  local captured = {}
  local adapter = {
    set_achievement_progress = function(id, count)
      captured.id = id
      captured.count = count
      return true
    end,
  }
  -- id 1 is valid, count 5 is integer -> _apply_progress reaches _call_host,
  -- adapter succeeds -> result true. L152 `_apply_progress(...)` -> nil returns nil.
  local result = achievement.set_progress(1, 5, adapter)
  lu.assertEvalToTrue(result == true, "set_progress must return true on success; got " .. tostring(result))
  lu.assertEvalToTrue(captured.id == 1 and captured.count == 5,
    "adapter must receive normalized (id, count); got "
    .. tostring(captured.id) .. "," .. tostring(captured.count))
end


-- mutate 车道统一返回全部类（#283 多类文件 return 首类假幸存方向）：
-- 正常车道扫 _G 收全部 Test* 类，但 mutate 内建 runner 只跑 return 的表，
-- 只 return 首个类会让其余类的用例在变异车道完全不执行。合并全部类，
-- 每个 test* 方法跑所属类 setUp/tearDown（见 multi_class_return）。
return require("test.support.multi_class_return").merge(
  TestAchievementMappedIdsForEvent,
  TestAchievementIdsAreContiguous,
  TestAchievementCategoryCounts,
  TestAchievementSetProgress
)
