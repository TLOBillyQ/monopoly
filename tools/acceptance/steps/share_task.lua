local number_utils = require("src.foundation.number")
local share_task = require("src.app.host_integrations.share_task")

local share_task_steps = {}

local function _ensure_player(world)
  if world.share_task_player == nil then
    world.share_task_player = { id = 1, cash = 500 }
  end
  return world.share_task_player
end

local function _current_task(world)
  return world.share_task and world.share_task.task or nil
end

function share_task_steps.handlers()
  return {
    ["宿主已配置<任务周期>分享任务<任务名称>"] = function(world, example)
      local task = share_task.find_task(example["任务周期"], example["任务名称"])
      if task == nil then
        return nil, "missing share task config: " .. tostring(example["任务周期"]) .. "/" .. tostring(example["任务名称"])
      end
      world.share_task = { task = task }
      return true
    end,

    ["任务按<进度来源>累计进度"] = function(world, example)
      local task = _current_task(world)
      if task == nil then
        return nil, "share task config was not selected"
      end
      local expected = example["进度来源"]
      if task.progress_source ~= expected then
        return nil, "expected progress source " .. tostring(expected) .. ", got " .. tostring(task.progress_source)
      end
      return true
    end,

    ["任务进度达到<目标进度>"] = function(world, example)
      local task = _current_task(world)
      if task == nil then
        return nil, "share task config was not selected"
      end
      local expected = number_utils.to_integer(example["目标进度"])
      if task.target_progress ~= expected then
        return nil, "expected target progress " .. tostring(expected) .. ", got " .. tostring(task.target_progress)
      end
      world.share_task.progress = expected
      return true
    end,

    ["宿主任务奖励货币数量为<奖励货币>"] = function(world, example)
      local task = _current_task(world)
      if task == nil then
        return nil, "share task config was not selected"
      end
      local expected = number_utils.to_integer(example["奖励货币"])
      if task.reward_currency ~= "金币" then
        return nil, "expected reward currency 金币, got " .. tostring(task.reward_currency)
      end
      if task.reward_amount ~= expected then
        return nil, "expected reward amount " .. tostring(expected) .. ", got " .. tostring(task.reward_amount)
      end
      return true
    end,

    ["Lua侧不额外发放分享任务货币"] = function(world)
      local player = _ensure_player(world)
      local before = player.cash
      local result = share_task.claim(nil, player, _current_task(world))
      if type(result) ~= "table" or result.ok ~= false or result.reason ~= "host_managed" then
        return nil, "expected host-managed no-op claim"
      end
      if player.cash ~= before then
        return nil, "expected Lua share task claim to leave cash " .. tostring(before) .. ", got " .. tostring(player.cash)
      end
      return true
    end,
  }
end

return share_task_steps
