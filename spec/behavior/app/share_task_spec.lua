local support = require("spec.support.shared_support")
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

describe("share_task host-managed rewards", function()
  it("mirrors the configured host task rewards", function()
    for _, expected in ipairs(EXPECTED_TASKS) do
      local task = share_task.find_task(expected.period, expected.name)
      assert(task ~= nil, "missing share task config: " .. expected.period .. "/" .. expected.name)
      _assert_eq(task.progress_source, expected.progress_source, expected.name .. " progress source")
      _assert_eq(task.target_progress, expected.target_progress, expected.name .. " target progress")
      _assert_eq(task.reward_currency, "金币", expected.name .. " reward currency")
      _assert_eq(task.reward_amount, expected.reward_amount, expected.name .. " reward amount")
    end
  end)

  it("returns nil for unknown task names", function()
    _assert_eq(share_task.find_task("每日", "不存在"), nil, "unknown share task should not resolve")
    _assert_eq(share_task.find_task("永久", "每日分享"), nil, "period is part of the task identity")
  end)

  it("does not grant currency from Lua when a host task is claimable", function()
    local task = share_task.find_task("每日", "每日分享")
    local player = { id = 1, cash = 500 }
    local result = share_task.claim(nil, player, task)

    _assert_eq(result.ok, false, "share task claim should stay host-managed")
    _assert_eq(result.reason, "host_managed", "share task claim should explain the no-op")
    _assert_eq(player.cash, 500, "Lua share task claim must not add currency")
  end)
end)
