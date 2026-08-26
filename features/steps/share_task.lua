local dsl = require("packages.acceptance.step_dsl")
local share_task = require("src.app.host_integrations.share_task")
-- 分享任务域绑定（#192 簇 B）：断言真实 share_tasks 配置镜像与宿主托管语义。
local function _task(w) return w.share_task and w.share_task.task or nil, "分享任务配置未选中" end
return dsl.steps({
  ["宿主已配置<任务周期>分享任务<任务名称>"] = function(w, a)
    local task = share_task.find_task(a["任务周期"], a["任务名称"])
    if task == nil then return nil, "缺少分享任务配置: " .. tostring(a["任务周期"]) .. "/" .. tostring(a["任务名称"]) end
    w.share_task = { task = task }
  end,
  ["任务按<进度来源>累计进度"] = function(w, a)
    local task, err = _task(w)
    if not task then return nil, err end
    return dsl.eq(task.progress_source, a["进度来源"], "进度来源")
  end,
  ["任务进度达到<目标进度:int>"] = function(w, a)
    local task, err = _task(w)
    if not task then return nil, err end
    return dsl.eq(task.target_progress, a["目标进度"], "目标进度")
  end,
  ["Lua侧不额外发放分享任务货币"] = function(w)
    local p = { id = 1, cash = 500 }
    local result = share_task.claim(nil, p, (_task(w)))
    if type(result) ~= "table" or result.ok ~= false or result.reason ~= "host_managed" then return nil, "分享任务应为宿主托管 no-op" end
    return dsl.eq(p.cash, 500, "Lua 侧发放后金币")
  end,
  ["宿主任务奖励货币数量为<奖励货币:int>"] = function(w, a)
    local task, err = _task(w)
    if not task then return nil, err end
    return dsl.all(
      function() return dsl.eq(task.reward_currency, "金币", "奖励货币种类") end,
      function() return dsl.eq(task.reward_amount, a["奖励货币"], "奖励货币数量") end)
  end,
}, { name = "share_task" })
