local number_utils = require("src.foundation.number")

local dice_steps = {}

local function _roll_dice(count, override_value)
  local results = {}
  for _ = 1, count do
    if override_value then
      results[#results + 1] = override_value
    else
      results[#results + 1] = math.random(1, 6)
    end
  end
  return results
end

local function _sum(values)
  local total = 0
  for _, v in ipairs(values) do
    total = total + v
  end
  return total
end

local function _set_raw_roll(world, raw_total)
  world.dice.results = { raw_total }
  world.dice.total = raw_total
  world.dice.actual_steps = raw_total * world.dice.multiplier
  if world.dice.multiplier > 1 then
    world.dice.consumed_multiplier = true
    world.dice.multiplier = 1
  end
end

local function _check_all_dice_equal(world, expected)
  for i, result in ipairs(world.dice.results) do
    if result ~= expected then
      return nil, "die " .. tostring(i) .. " expected " .. tostring(expected) .. ", got " .. tostring(result)
    end
  end
  return true
end

local function _check_actual_steps(world, expected)
  if world.dice.actual_steps ~= expected then
    return nil, "expected actual steps " .. tostring(expected) .. ", got " .. tostring(world.dice.actual_steps)
  end
  return true
end

function dice_steps.handlers()
  return {
    ["当前玩家准备掷骰"] = function(world)
      world.dice = {
        count = 2,
        min = 1,
        max = 6,
        override_value = nil,
        multiplier = 1,
        results = nil,
        total = nil,
        actual_steps = nil,
        consumed_remote = false,
        consumed_multiplier = false,
      }
      world.player = world.player or { name = "玩家1", items = {} }
      world.events = world.events or {}
      return true
    end,

    ["玩家的骰子数量为<p1>"] = function(world, example)
      local count = number_utils.to_integer(example.p1)
      if count == nil then
        return nil, "invalid dice count: " .. tostring(example.p1)
      end
      world.dice.count = count
      return true
    end,

    ["玩家掷骰"] = function(world)
      local results = _roll_dice(world.dice.count, world.dice.override_value)
      world.dice.results = results
      local raw_total = _sum(results)
      world.dice.total = raw_total
      world.dice.actual_steps = raw_total * world.dice.multiplier
      if world.dice.override_value then
        world.dice.consumed_remote = true
        world.dice.override_value = nil
      end
      if world.dice.multiplier > 1 then
        world.dice.consumed_multiplier = true
        world.dice.multiplier = 1
      end
      return true
    end,

    ["每颗骰子的结果在<p2>到<p3>之间"] = function(world, example)
      local min_val = number_utils.to_integer(example.p2)
      local max_val = number_utils.to_integer(example.p3)
      for i, result in ipairs(world.dice.results) do
        if result < min_val or result > max_val then
          return nil, "die " .. tostring(i) .. " result " .. tostring(result) .. " not in [" .. tostring(min_val) .. "," .. tostring(max_val) .. "]"
        end
      end
      return true
    end,

    ["移动步数等于所有骰子结果之和"] = function(world)
      local expected = _sum(world.dice.results)
      if world.dice.actual_steps ~= expected then
        return nil, "expected steps " .. tostring(expected) .. ", got " .. tostring(world.dice.actual_steps)
      end
      return true
    end,

    ["玩家名为小明"] = function(world)
      world.player.name = "小明"
      return true
    end,

    ["玩家掷骰得到结果3和5"] = function(world)
      world.dice.results = { 3, 5 }
      world.dice.total = 8
      world.dice.actual_steps = 8
      world.events[#world.events + 1] = {
        type = "dice_roll",
        player = world.player.name,
        values = { 3, 5 },
        total = 8,
      }
      return true
    end,

    ["事件日志包含投骰记录"] = function(world)
      local found = false
      for _, event in ipairs(world.events) do
        if event.type == "dice_roll" then
          found = true
          break
        end
      end
      if not found then
        return nil, "no dice_roll event in log"
      end
      return true
    end,

    ["记录显示各骰子值和总数8"] = function(world)
      for _, event in ipairs(world.events) do
        if event.type == "dice_roll" then
          if event.total ~= 8 then
            return nil, "expected total 8, got " .. tostring(event.total)
          end
          return true
        end
      end
      return nil, "no dice_roll event found"
    end,

    ["玩家使用了遥控骰子设定点数为<p4>"] = function(world, example)
      local val = number_utils.to_integer(example.p4)
      if val == nil then
        return nil, "invalid remote dice value: " .. tostring(example.p4)
      end
      world.dice.override_value = val
      return true
    end,

    ["每颗骰子结果均为<p4>"] = function(world, example)
      return _check_all_dice_equal(world, number_utils.to_integer(example.p4))
    end,

    ["移动步数为<p5>"] = function(world, example)
      return _check_actual_steps(world, number_utils.to_integer(example.p5))
    end,

    ["玩家使用了遥控骰子设定点数为5"] = function(world)
      world.dice.override_value = 5
      return true
    end,

    ["遥控骰子效果被消耗"] = function(world)
      if not world.dice.consumed_remote then
        return nil, "remote dice was not consumed"
      end
      return true
    end,

    ["下次掷骰恢复随机"] = function(world)
      if world.dice.override_value ~= nil then
        return nil, "override should be cleared after consumption"
      end
      return true
    end,

    ["玩家持有骰子加倍卡且倍率为<p6>"] = function(world, example)
      local mult = number_utils.to_integer(example.p6)
      if mult == nil then
        return nil, "invalid multiplier: " .. tostring(example.p6)
      end
      world.dice.multiplier = mult
      return true
    end,

    ["玩家掷骰得到原始点数<p7>"] = function(world, example)
      local raw = number_utils.to_integer(example.p7)
      if raw == nil then
        return nil, "invalid raw total: " .. tostring(example.p7)
      end
      _set_raw_roll(world, raw)
      return true
    end,

    ["实际移动步数为<p8>"] = function(world, example)
      return _check_actual_steps(world, number_utils.to_integer(example.p8))
    end,

    ["加倍卡效果消耗后倍率重置为1"] = function(world)
      if world.dice.multiplier ~= 1 then
        return nil, "multiplier should be reset to 1, got " .. tostring(world.dice.multiplier)
      end
      return true
    end,

    ["玩家使用了遥控骰子设定点数为6"] = function(world)
      world.dice.override_value = 6
      return true
    end,

    ["玩家持有骰子加倍卡且倍率为2"] = function(world)
      world.dice.multiplier = 2
      return true
    end,

    ["每颗骰子结果为6"] = function(world)
      return _check_all_dice_equal(world, 6)
    end,

    ["实际移动步数为24"] = function(world)
      return _check_actual_steps(world, 24)
    end,

    ["玩家没有骰子加倍卡"] = function(world)
      world.dice.multiplier = 1
      return true
    end,

    ["玩家掷骰得到原始点数7"] = function(world)
      _set_raw_roll(world, 7)
      return true
    end,

    ["实际移动步数为7"] = function(world)
      return _check_actual_steps(world, 7)
    end,
  }
end

return dice_steps
