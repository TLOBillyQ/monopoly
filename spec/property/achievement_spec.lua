local property = require("spec.support.property")
local achievement = require("src.app.host_integrations.achievement")

local EVENTS = {
  { name = "游戏胜利", amount = 1 },
  { name = "买下地块", amount = 1 },
  { name = "收取金币", amount = 500 },
  { name = "支付税金", amount = 3000 },
  { name = "使用道具卡", amount = 1 },
  { name = "抽到机会卡", amount = 1 },
  { name = "黑市购买道具", amount = 1 },
  { name = "加盖1级建筑" },
  { name = "加盖2级建筑" },
  { name = "加盖3级建筑" },
  { name = "被福神附身" },
  { name = "被财神附身" },
  { name = "被穷神附身" },
  { name = "被送进医院" },
  { name = "被送进深山" },
  { name = "获得三个连续地块" },
  { name = "被怪兽拆除房屋" },
  { name = "被台风拆除房屋" },
  { name = "使用小猪佩奇皮肤" },
  { name = "使用小猪乔治皮肤" },
  { name = "使用海绵宝宝皮肤" },
  { name = "使用派大星皮肤" },
  { name = "使用奶龙皮肤" },
  { name = "使用水豚嘟嘟皮肤" },
}

local function _assert_eq(actual, expected, message)
  assert(actual == expected, (message or "assertion failed")
    .. ": expected " .. tostring(expected)
    .. ", got " .. tostring(actual))
end

local function _copy(ids)
  local result = {}
  for index, id in ipairs(ids) do
    result[index] = id
  end
  return result
end

local function _same_array(left, right)
  if #left ~= #right then
    return false
  end
  for index, value in ipairs(left) do
    if right[index] ~= value then
      return false
    end
  end
  return true
end

local function _progress_adapter(progress, added)
  return {
    add_achievement_progress = function(id, amount)
      progress[id] = (progress[id] or 0) + amount
      added[id] = (added[id] or 0) + amount
      return true
    end,
    get_achievement_progress = function(id)
      return progress[id] or 0
    end,
  }
end

describe("achievement progress properties", function()
  after_each(function()
    achievement.reset_for_tests()
  end)

  it("mapped id lists are read-only snapshots from the caller perspective", function()
    property.for_all(function(rng)
      return rng:pick(EVENTS).name
    end, function(event_name)
      local first = achievement.mapped_ids_for_event(event_name)
      local expected = _copy(first)
      first[1] = -1

      local second = achievement.mapped_ids_for_event(event_name)
      assert(_same_array(second, expected), "mutating returned ids must not change mapping")
    end)
  end)

  it("gameplay event routing adds exactly one event delta to every mapped achievement", function()
    property.for_all(function(rng)
      local event = rng:pick(EVENTS)
      return {
        event = event,
        base_progress = rng:int(0, 100000),
        generated_amount = rng:int(1, 100000),
      }
    end, function(case)
      local progress = {}
      local added = {}
      local ids = achievement.mapped_ids_for_event(case.event.name)
      local amount = case.event.amount or case.generated_amount
      for _, id in ipairs(ids) do
        progress[id] = case.base_progress
      end

      achievement.configure_progress_adapter(_progress_adapter(progress, added))

      local event_value = case.event.amount and case.event.amount or amount
      _assert_eq(achievement.record_gameplay_event(case.event.name, event_value), true,
        "known event should route progress")

      for _, id in ipairs(ids) do
        _assert_eq(added[id], amount, "event should add exactly one delta")
        _assert_eq(achievement.current_progress(id), case.base_progress + amount,
          "current progress should include exactly one delta")
      end
    end)
  end)
end)
