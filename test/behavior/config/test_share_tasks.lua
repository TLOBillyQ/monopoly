-- src/config/content/share_tasks.lua 数据目录 pinning spec:宿主编辑器分享任务配置的
-- Lua 镜像,全表逐字段钉死,字面量变异无处逃。用例清 package.loaded 重放 chunk,
-- 让变异车道 suite-file map 归因到本 suite(与 skins_spec 同款;新表留缓存,无泄漏)。

-- 窄车道自备共享运行时端口基线（#217）：缺失才补装，在位 no-op。
do
  local baseline_guard = require("test.support.runtime_baseline_guard")
  if #baseline_guard.missing_ports() > 0 then
    baseline_guard.restore()
  end
end

local lu = require("luaunit")

TestShareTasks = {}

function TestShareTasks:test_pins_the_full_mirrored_share_task_config_field_by_field()
  package.loaded["src.config.content.share_tasks"] = nil
  local catalog = require("src.config.content.share_tasks")

  local expected = {
    { period = "每日", name = "每日分享", progress_source = "分享次数", target_progress = 1, reward_currency = "金币", reward_amount = 1000 },
    { period = "永久", name = "点赞1次本地图", progress_source = "evt_click_like", target_progress = 1, reward_currency = "金币", reward_amount = 1000 },
    { period = "永久", name = "收藏1次本地图", progress_source = "evt_add_collection", target_progress = 1, reward_currency = "金币", reward_amount = 1000 },
    { period = "永久", name = "订阅关注本图作者", progress_source = "evt_subscribe", target_progress = 1, reward_currency = "金币", reward_amount = 1000 },
    { period = "永久", name = "邀请1人", progress_source = "首次进入地图的人数", target_progress = 1, reward_currency = "金币", reward_amount = 1800 },
    { period = "永久", name = "邀请3人", progress_source = "首次进入地图的人数", target_progress = 3, reward_currency = "金币", reward_amount = 6800 },
    { period = "永久", name = "邀请5人", progress_source = "首次进入地图的人数", target_progress = 5, reward_currency = "金币", reward_amount = 12800 },
    { period = "永久", name = "邀请10人", progress_source = "首次进入地图的人数", target_progress = 10, reward_currency = "金币", reward_amount = 36800 },
    { period = "永久", name = "邀请20人", progress_source = "首次进入地图的人数", target_progress = 20, reward_currency = "金币", reward_amount = 99800 },
  }

  lu.assertEvalToTrue(#catalog == #expected, "share task count mismatch")
  for i, fields in ipairs(expected) do
    local entry = catalog[i]
    lu.assertEvalToTrue(entry.period == fields.period, "period mismatch at " .. tostring(i))
    lu.assertEvalToTrue(entry.name == fields.name, "name mismatch at " .. tostring(i))
    lu.assertEvalToTrue(entry.progress_source == fields.progress_source, "progress_source mismatch at " .. tostring(i))
    lu.assertEvalToTrue(entry.target_progress == fields.target_progress, "target_progress mismatch at " .. tostring(i))
    lu.assertEvalToTrue(entry.reward_currency == fields.reward_currency, "reward_currency mismatch at " .. tostring(i))
    lu.assertEvalToTrue(entry.reward_amount == fields.reward_amount, "reward_amount mismatch at " .. tostring(i))
  end
end


return TestShareTasks
