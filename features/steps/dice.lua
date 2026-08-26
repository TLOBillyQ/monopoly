local dsl = require("packages.acceptance.step_dsl")
local game_driver = require("packages.acceptance.game_driver")
local event_kinds = require("src.config.gameplay.event_kinds")

-- 掷骰域（dice.feature）：全程走 game_driver 骰子动词，断言读 last_rolls /
-- last_total 与玩家 status 公开面。字面句族（设定点数为5/6、原始点数7 等）
-- 用 {} 行内捕获并到参数化句，与 <名:int> 注解句共用同一实现。

local function _ctx(w) return w.driver end
local function _player(w) return game_driver.current_player(w.driver) end
local function _rolls(w) return game_driver.last_rolls(_ctx(w)) or {} end
local function _total(w) return game_driver.last_total(_ctx(w)) end
local function _roll(w, count)
  w.dice_count = count or w.dice_count or 2
  game_driver.roll_dice(_ctx(w), _player(w), w.dice_count)
  return true
end
local function _sum(values)
  local total = 0
  for _, v in ipairs(values or {}) do total = total + v end
  return total
end
local function _each_roll_eq(w, expected)
  local rolls = _rolls(w)
  for i, result in ipairs(rolls) do
    local ok, msg = dsl.eq(result, expected, "第" .. i .. "颗骰子")
    if not ok then return nil, msg end
  end
  return dsl.truthy(#rolls > 0, "掷出骰子数")
end
local function _set_remote(w, a)
  game_driver.apply_remote_dice(_ctx(w), _player(w), w.dice_count or 2, a["设定值"])
  return true
end
local function _set_mult(w, a) game_driver.set_dice_multiplier(_ctx(w), _player(w), a["倍率"]) return true end
local function _roll_raw(w, a) game_driver.set_next_rolls(_ctx(w), { a["原始点数"] }) return _roll(w, 1) end
local function _assert_total(w, a) return dsl.eq(_total(w), a["实际步数"], "实际移动步数") end
local function _remote_cleared(w)
  local status = _player(w).status
  return dsl.eq(status and status.pending_remote_dice, nil, "遥控骰子残留效果")
end
return dsl.steps({
  ["当前玩家准备掷骰"] = function(w) w.dice_count = 2 return true end,
  ["玩家的骰子数量为<骰子数:int>"] = function(w, a) w.dice_count = a["骰子数"] return true end,
  ["玩家掷骰"] = function(w) return _roll(w) end,
  ["每颗骰子的结果在<最小值:int>到<最大值:int>之间"] = function(w, a)
    for i, result in ipairs(_rolls(w)) do
      local ok, msg = dsl.range(result, a["最小值"], a["最大值"], "第" .. i .. "颗骰子")
      if not ok then return nil, msg end
    end
    return true
  end,
  ["掷出骰子数为<验证骰子数:int>颗"] = function(w, a) return dsl.eq(#_rolls(w), a["验证骰子数"], "掷出骰子数") end,
  ["移动步数等于所有骰子结果之和"] = function(w)
    local ok, msg = dsl.eq(#_rolls(w), w.dice_count, "掷出骰子数")
    if not ok then return nil, msg end
    return dsl.eq(_total(w), _sum(_rolls(w)), "移动步数")
  end,
  ["玩家名为小明"] = function(w) _player(w).name = "小明" return true end,
  ["玩家掷骰得到结果{甲:int}和{乙:int}"] = function(w, a) game_driver.set_next_rolls(_ctx(w), { a["甲"], a["乙"] }) return _roll(w, 2) end,
  ["事件日志包含投骰记录"] = function(w)
    for _, event in ipairs(game_driver.events(_ctx(w))) do
      if event.kind == event_kinds.dice_roll then return true end
    end
    return nil, "事件日志: 期望包含投骰记录,实际没有"
  end,
  ["记录显示各骰子值和总数{总数:int}"] = function(w, a)
    local ok, msg = dsl.eq(_total(w), a["总数"], "记录总数")
    if not ok then return nil, msg end
    return dsl.eq(_sum(_rolls(w)), a["总数"], "各骰子值之和")
  end,
  ["玩家使用了遥控骰子设定点数为<设定值:int>"] = _set_remote,
  ["玩家使用了遥控骰子设定点数为{设定值:int}"] = _set_remote,
  ["每颗骰子结果均为<设定值:int>"] = function(w, a) return _each_roll_eq(w, a["设定值"]) end,
  ["每颗骰子结果为{设定值:int}"] = function(w, a) return _each_roll_eq(w, a["设定值"]) end,
  ["移动步数为<总步数:int>"] = function(w, a) return dsl.eq(_total(w), a["总步数"], "移动步数") end,
  ["遥控骰子效果被消耗"] = _remote_cleared,
  ["下次掷骰恢复随机"] = _remote_cleared,
  ["玩家持有骰子加倍卡且倍率为<倍率:int>"] = _set_mult,
  ["玩家持有骰子加倍卡且倍率为{倍率:int}"] = _set_mult,
  ["玩家没有骰子加倍卡"] = function(w) game_driver.set_dice_multiplier(_ctx(w), _player(w), 1) return true end,
  ["玩家掷骰得到原始点数<原始点数:int>"] = _roll_raw,
  ["玩家掷骰得到原始点数{原始点数:int}"] = _roll_raw,
  ["实际移动步数为<实际步数:int>"] = _assert_total,
  ["实际移动步数为{实际步数:int}"] = _assert_total,
  ["加倍卡效果消耗后倍率重置为1"] = function(w)
    local status = _player(w).status
    return dsl.eq(status and status.pending_dice_multiplier or 1, 1, "加倍卡倍率")
  end,
}, { name = "dice" })
