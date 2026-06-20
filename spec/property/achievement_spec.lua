local property = require("spec.support.property")
local achievement = require("src.app.host_integrations.achievement")
local event_progress = require("src.config.content.achievement_progress_events")

local EVENTS = {}
for name, mapped in pairs(event_progress) do
  EVENTS[#EVENTS + 1] = { name = name, default_amount = mapped.default_amount }
end
table.sort(EVENTS, function(left, right)
  return left.name < right.name
end)

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

  it("gameplay event routing adds exactly one explicit event delta to every mapped achievement", function()
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
      for _, id in ipairs(ids) do
        progress[id] = case.base_progress
      end

      achievement.configure_progress_adapter(_progress_adapter(progress, added))

      _assert_eq(achievement.record_gameplay_event(case.event.name, case.generated_amount), true,
        "known event should route progress")

      for _, id in ipairs(ids) do
        _assert_eq(added[id], case.generated_amount, "event should add exactly one delta")
        _assert_eq(achievement.current_progress(id), case.base_progress + case.generated_amount,
          "current progress should include exactly one delta")
      end
    end)
  end)

  it("gameplay event routing uses the configured default when no event value is supplied", function()
    property.for_all(function(rng)
      local event = rng:pick(EVENTS)
      return {
        event = event,
        base_progress = rng:int(0, 100000),
      }
    end, function(case)
      local progress = {}
      local added = {}
      local ids = achievement.mapped_ids_for_event(case.event.name)
      for _, id in ipairs(ids) do
        progress[id] = case.base_progress
      end

      achievement.configure_progress_adapter(_progress_adapter(progress, added))

      _assert_eq(achievement.record_gameplay_event(case.event.name), true,
        "known event should route default progress")

      for _, id in ipairs(ids) do
        _assert_eq(added[id], case.event.default_amount, "event should add the configured default")
        _assert_eq(achievement.current_progress(id), case.base_progress + case.event.default_amount,
          "current progress should include the configured default")
      end
    end)
  end)
end)
