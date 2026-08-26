-- 原生 LuaUnit(推翻自研 busted 兼容运行器决策的迁移):两个 describe 拍平成两个 Test* 类,断言从
-- 裸 assert 切到 lu.assertEvalToTrue,用例数与改写前一一对应
-- (host-managed rewards 3 例 + 迁自 property 车道的 config properties 2 例 = 5 例)。

local lu = require("luaunit")
local support = require("test.support.shared_support")
local _assert_eq = support.assert_eq
local share_task = require("src.app.host_integrations.share_task")

local EXPECTED_TASKS = {
  { period = "每日", name = "每日分享", progress_source = "分享次数", target_progress = 1, reward_amount = 1000 },
  { period = "永久", name = "邀请1人", progress_source = "首次进入地图的人数", target_progress = 1, reward_amount = 1800 },
  { period = "永久", name = "邀请3人", progress_source = "首次进入地图的人数", target_progress = 3, reward_amount = 6800 },
  { period = "永久", name = "邀请5人", progress_source = "首次进入地图的人数", target_progress = 5, reward_amount = 12800 },
  { period = "永久", name = "邀请10人", progress_source = "首次进入地图的人数", target_progress = 10, reward_amount = 36800 },
  { period = "永久", name = "邀请20人", progress_source = "首次进入地图的人数", target_progress = 20, reward_amount = 99800 },
}

TestShareTaskHostManagedRewards = {}

function TestShareTaskHostManagedRewards:test_mirrors_the_configured_host_task_rewards()
  for _, expected in ipairs(EXPECTED_TASKS) do
    local task = share_task.find_task(expected.period, expected.name)
    lu.assertEvalToTrue(task ~= nil, "missing share task config: " .. expected.period .. "/" .. expected.name)
    _assert_eq(task.progress_source, expected.progress_source, expected.name .. " progress source")
    _assert_eq(task.target_progress, expected.target_progress, expected.name .. " target progress")
    _assert_eq(task.reward_currency, "金币", expected.name .. " reward currency")
    _assert_eq(task.reward_amount, expected.reward_amount, expected.name .. " reward amount")
  end
end

function TestShareTaskHostManagedRewards:test_returns_nil_for_unknown_task_names()
  _assert_eq(share_task.find_task("每日", "不存在"), nil, "unknown share task should not resolve")
  _assert_eq(share_task.find_task("永久", "每日分享"), nil, "period is part of the task identity")
end

function TestShareTaskHostManagedRewards:test_does_not_grant_currency_from_lua_when_a_host_task_is_claimable()
  local task = share_task.find_task("每日", "每日分享")
  local player = { id = 1, cash = 500 }
  local result = share_task.claim(nil, player, task)

  _assert_eq(result.ok, false, "share task claim should stay host-managed")
  _assert_eq(result.reason, "host_managed", "share task claim should explain the no-op")
  _assert_eq(player.cash, 500, "Lua share task claim must not add currency")
end

-- ===== 迁自 test/property/test_share_task.lua（#190, 测试极简化决策：property 车道退场，性质并入 behavior）=====
do
  local property = require("test.support.property")

  local function _prop_assert_eq(actual, expected, message)
    lu.assertEvalToTrue(actual == expected, (message or "assertion failed")
      .. ": expected " .. tostring(expected)
      .. ", got " .. tostring(actual))
  end

  local function _gen_task(rng)
    return rng:pick(share_task.tasks)
  end

  TestShareTaskConfigProperties = {}

  function TestShareTaskConfigProperties:test_lookup_round_trips_every_configured_task_identity()
    property.for_all(_gen_task, function(task)
      local found = share_task.find_task(task.period, task.name)

      _prop_assert_eq(found, task, "configured task should resolve by period/name")
      _prop_assert_eq(share_task.reward_for(task.period, task.name), task.reward_amount,
        "reward_for should mirror task reward")
    end)
  end

  function TestShareTaskConfigProperties:test_host_managed_claims_never_mutate_supplied_player_cash()
    property.for_all(function(rng)
      return {
        task = _gen_task(rng),
        cash = rng:int(0, 1000000),
      }
    end, function(case)
      local player = { id = 1, cash = case.cash }
      local result = share_task.claim(nil, player, case.task)

      _prop_assert_eq(result.ok, false, "claim should stay host-managed")
      _prop_assert_eq(result.reason, "host_managed", "claim should explain host ownership")
      _prop_assert_eq(player.cash, case.cash, "claim should not mutate player cash")
    end)
  end
end


-- mutate 车道统一返回全部类（#283 多类文件 return 首类假幸存方向）：
-- 正常车道扫 _G 收全部 Test* 类，但 mutate 内建 runner 只跑 return 的表，
-- 只 return 首个类会让其余类的用例在变异车道完全不执行。合并全部类，
-- 每个 test* 方法跑所属类 setUp/tearDown（见 multi_class_return）。
return require("test.support.multi_class_return").merge(
  TestShareTaskHostManagedRewards,
  TestShareTaskConfigProperties
)
