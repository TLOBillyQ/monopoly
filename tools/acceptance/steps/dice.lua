local number_utils = require("src.foundation.number")
local game_driver = require("tools.acceptance.game_driver")
local event_kinds = require("src.config.gameplay.event_kinds")

local dice_steps = {}

local function _ctx(world) return world.driver end
local function _player(world) return game_driver.current_player(world.driver) end

function dice_steps.handlers()
  return {
    ["当前玩家准备掷骰"] = function(world)
      world.dice_count = 2
      return true
    end,

    ["玩家的骰子数量为<p1>"] = function(world, example)
      local count = number_utils.to_integer(example.p1)
      if count == nil then
        return nil, "invalid dice count: " .. tostring(example.p1)
      end
      world.dice_count = count
      return true
    end,

    ["玩家掷骰"] = function(world)
      game_driver.roll_dice(_ctx(world), _player(world), world.dice_count)
      return true
    end,

    ["每颗骰子的结果在<p2>到<p3>之间"] = function(world, example)
      local min_val = number_utils.to_integer(example.p2)
      local max_val = number_utils.to_integer(example.p3)
      local rolls = game_driver.last_rolls(_ctx(world))
      for i, result in ipairs(rolls) do
        if result < min_val or result > max_val then
          return nil, "die " .. tostring(i) .. " result " .. tostring(result)
            .. " not in [" .. tostring(min_val) .. "," .. tostring(max_val) .. "]"
        end
      end
      return true
    end,

    ["移动步数等于所有骰子结果之和"] = function(world)
      local rolls = game_driver.last_rolls(_ctx(world))
      local total = game_driver.last_total(_ctx(world))
      if #rolls ~= world.dice_count then
        return nil, "expected " .. tostring(world.dice_count) .. " dice, got " .. tostring(#rolls)
      end
      local expected = 0
      for _, v in ipairs(rolls) do expected = expected + v end
      if total ~= expected then
        return nil, "expected steps " .. tostring(expected) .. ", got " .. tostring(total)
      end
      return true
    end,

    ["玩家名为小明"] = function(world)
      _player(world).name = "小明"
      return true
    end,

    ["玩家掷骰得到结果3和5"] = function(world)
      game_driver.set_next_rolls(_ctx(world), {3, 5})
      game_driver.roll_dice(_ctx(world), _player(world), 2)
      return true
    end,

    ["事件日志包含投骰记录"] = function(world)
      for _, event in ipairs(game_driver.events(_ctx(world))) do
        if event.kind == event_kinds.dice_roll then
          return true
        end
      end
      return nil, "no dice_roll event in log"
    end,

    ["记录显示各骰子值和总数8"] = function(world)
      local total = game_driver.last_total(_ctx(world))
      local rolls = game_driver.last_rolls(_ctx(world))
      if total ~= 8 then
        return nil, "expected total 8, got " .. tostring(total)
      end
      if not rolls or #rolls ~= 2 then
        return nil, "expected 2 dice, got " .. tostring(rolls and #rolls or 0)
      end
      local sum = 0
      for _, v in ipairs(rolls) do sum = sum + v end
      if sum ~= 8 then
        return nil, "dice sum " .. tostring(sum) .. " != 8"
      end
      return true
    end,

    ["玩家使用了遥控骰子设定点数为<p4>"] = function(world, example)
      local val = number_utils.to_integer(example.p4)
      if val == nil then
        return nil, "invalid remote dice value: " .. tostring(example.p4)
      end
      game_driver.apply_remote_dice(_ctx(world), _player(world), world.dice_count, val)
      return true
    end,

    ["每颗骰子结果均为<p4>"] = function(world, example)
      local expected = number_utils.to_integer(example.p4)
      local rolls = game_driver.last_rolls(_ctx(world))
      for i, result in ipairs(rolls) do
        if result ~= expected then
          return nil, "die " .. tostring(i) .. " expected " .. tostring(expected)
            .. ", got " .. tostring(result)
        end
      end
      return true
    end,

    ["移动步数为<p5>"] = function(world, example)
      local expected = number_utils.to_integer(example.p5)
      local total = game_driver.last_total(_ctx(world))
      if total ~= expected then
        return nil, "expected total " .. tostring(expected) .. ", got " .. tostring(total)
      end
      return true
    end,

    ["玩家使用了遥控骰子设定点数为5"] = function(world)
      game_driver.apply_remote_dice(_ctx(world), _player(world), world.dice_count, 5)
      return true
    end,

    ["遥控骰子效果被消耗"] = function(world)
      local player = _player(world)
      if player.status and player.status.pending_remote_dice ~= nil then
        return nil, "remote dice was not consumed"
      end
      return true
    end,

    ["下次掷骰恢复随机"] = function(world)
      local player = _player(world)
      if player.status and player.status.pending_remote_dice ~= nil then
        return nil, "override not cleared after consumption"
      end
      return true
    end,

    ["玩家持有骰子加倍卡且倍率为<p6>"] = function(world, example)
      local mult = number_utils.to_integer(example.p6)
      if mult == nil then
        return nil, "invalid multiplier: " .. tostring(example.p6)
      end
      game_driver.set_dice_multiplier(_ctx(world), _player(world), mult)
      return true
    end,

    ["玩家掷骰得到原始点数<p7>"] = function(world, example)
      local raw = number_utils.to_integer(example.p7)
      if raw == nil then
        return nil, "invalid raw total: " .. tostring(example.p7)
      end
      game_driver.set_next_rolls(_ctx(world), {raw})
      game_driver.roll_dice(_ctx(world), _player(world), 1)
      return true
    end,

    ["实际移动步数为<p8>"] = function(world, example)
      local expected = number_utils.to_integer(example.p8)
      local total = game_driver.last_total(_ctx(world))
      if total ~= expected then
        return nil, "expected actual steps " .. tostring(expected) .. ", got " .. tostring(total)
      end
      return true
    end,

    ["加倍卡效果消耗后倍率重置为1"] = function(world)
      local player = _player(world)
      local mult = player.status and player.status.pending_dice_multiplier or 1
      if mult ~= 1 then
        return nil, "multiplier should be 1, got " .. tostring(mult)
      end
      return true
    end,

    ["玩家使用了遥控骰子设定点数为6"] = function(world)
      game_driver.apply_remote_dice(_ctx(world), _player(world), world.dice_count, 6)
      return true
    end,

    ["玩家持有骰子加倍卡且倍率为2"] = function(world)
      game_driver.set_dice_multiplier(_ctx(world), _player(world), 2)
      return true
    end,

    ["每颗骰子结果为6"] = function(world)
      local rolls = game_driver.last_rolls(_ctx(world))
      for i, result in ipairs(rolls) do
        if result ~= 6 then
          return nil, "die " .. tostring(i) .. " expected 6, got " .. tostring(result)
        end
      end
      return true
    end,

    ["实际移动步数为24"] = function(world)
      local total = game_driver.last_total(_ctx(world))
      if total ~= 24 then
        return nil, "expected 24, got " .. tostring(total)
      end
      return true
    end,

    ["玩家没有骰子加倍卡"] = function(world)
      game_driver.set_dice_multiplier(_ctx(world), _player(world), 1)
      return true
    end,

    ["玩家掷骰得到原始点数7"] = function(world)
      game_driver.set_next_rolls(_ctx(world), {7})
      game_driver.roll_dice(_ctx(world), _player(world), 1)
      return true
    end,

    ["实际移动步数为7"] = function(world)
      local total = game_driver.last_total(_ctx(world))
      if total ~= 7 then
        return nil, "expected 7, got " .. tostring(total)
      end
      return true
    end,
  }
end

return dice_steps
