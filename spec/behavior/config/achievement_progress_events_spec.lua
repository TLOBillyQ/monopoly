local EXPECTED = {
  ["游戏胜利"] = { ids = { 1, 2, 3, 4 }, default_amount = 1 },
  ["买下地块"] = { ids = { 5, 6, 7, 8 }, default_amount = 1 },
  ["收取金币"] = { ids = { 9, 10, 11, 12 }, default_amount = 1 },
  ["支付税金"] = { ids = { 13, 14, 15, 16 }, default_amount = 1 },
  ["使用道具卡"] = { ids = { 17, 18, 19, 20 }, default_amount = 1 },
  ["抽到机会卡"] = { ids = { 21, 22, 23, 24 }, default_amount = 1 },
  ["黑市购买道具"] = { ids = { 25, 26, 27, 28 }, default_amount = 1 },
  ["加盖1级建筑"] = { ids = { 29 }, default_amount = 1 },
  ["加盖2级建筑"] = { ids = { 30 }, default_amount = 1 },
  ["加盖3级建筑"] = { ids = { 31 }, default_amount = 1 },
  ["被福神附身"] = { ids = { 32 }, default_amount = 1 },
  ["被财神附身"] = { ids = { 33 }, default_amount = 1 },
  ["被穷神附身"] = { ids = { 34 }, default_amount = 1 },
  ["被送进医院"] = { ids = { 35 }, default_amount = 1 },
  ["被送进深山"] = { ids = { 36 }, default_amount = 1 },
  ["获得三个连续地块"] = { ids = { 37 }, default_amount = 1 },
  ["被怪兽拆除房屋"] = { ids = { 38 }, default_amount = 1 },
  ["被台风拆除房屋"] = { ids = { 39 }, default_amount = 1 },
  ["使用小猪佩奇皮肤"] = { ids = { 40 }, default_amount = 1 },
  ["使用小猪乔治皮肤"] = { ids = { 41 }, default_amount = 1 },
  ["使用海绵宝宝皮肤"] = { ids = { 42 }, default_amount = 1 },
  ["使用派大星皮肤"] = { ids = { 43 }, default_amount = 1 },
  ["使用奶龙皮肤"] = { ids = { 44 }, default_amount = 1 },
  ["使用水豚嘟嘟皮肤"] = { ids = { 45 }, default_amount = 1 },
}

local function _assert_ids(actual, expected, event_name)
  assert(type(actual) == "table", event_name .. " ids should be a table")
  assert(#actual == #expected, event_name .. " id count mismatch")
  for index, id in ipairs(expected) do
    assert(actual[index] == id,
      event_name .. " id " .. tostring(index) .. " mismatch: expected " .. tostring(id)
        .. ", got " .. tostring(actual[index]))
  end
end

describe("achievement_progress_events config", function()
  it("maps every gameplay progress event to the exported achievement ids", function()
    package.loaded["src.config.content.achievement_progress_events"] = nil
    local progress_events = require("src.config.content.achievement_progress_events")
    local actual_count = 0
    for event_name in pairs(progress_events) do
      actual_count = actual_count + 1
      assert(EXPECTED[event_name] ~= nil, "unexpected achievement progress event: " .. tostring(event_name))
    end

    local expected_count = 0
    for event_name, expected in pairs(EXPECTED) do
      expected_count = expected_count + 1
      local actual = progress_events[event_name]
      assert(actual ~= nil, "missing achievement progress event: " .. tostring(event_name))
      _assert_ids(actual.ids, expected.ids, event_name)
      assert(actual.default_amount == expected.default_amount,
        event_name .. " default amount mismatch: expected " .. tostring(expected.default_amount)
          .. ", got " .. tostring(actual.default_amount))
    end

    assert(actual_count == expected_count,
      "achievement progress event count mismatch: expected " .. tostring(expected_count)
        .. ", got " .. tostring(actual_count))
  end)
end)
