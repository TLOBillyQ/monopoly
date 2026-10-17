-- event_feed.publish 的守卫与布尔归一化:#293 复核——_bool_or_false 的
-- or→and 变异(or 变异让真值塌成 false)与两处 return false 均未测。
require("test.bootstrap").install_package_paths()
local luassert = assert

local event_feed = require("src.rules.ports.event_feed")

describe("TestEventFeedGuards", function()
it("test_publish_returns_false_without_inputs", function()
  luassert.truthy(event_feed.publish(nil, {}) == false,
    "nil game should not publish")
  luassert.truthy(event_feed.publish({}, nil) == false,
    "nil event should not publish")
end)

it("test_publish_rejects_invalid_event", function()
  luassert.truthy(event_feed.publish({}, {}) == false,
    "event without kind/text should not publish")
end)

it("test_publish_normalizes_the_port_result_to_boolean", function()
  -- #293:_bool_or_false 的 or→and 变异会让真值塌成 false。
  local calls = 0
  local game = {
    event_feed_port = {
      publish = function()
        calls = calls + 1
        return "truthy"
      end,
    },
  }
  luassert.truthy(event_feed.publish(game, { kind = "k", text = "t" }) == true,
    "truthy port result should normalize to true")
  -- lint-allow: call-count event_feed_port 经 game 注入,发布次数即被测单元的对外输出
  luassert.truthy(calls == 1, "port should be called once")
end)

it("test_publish_passes_through_falsy_port_result", function()
  local game = {
    event_feed_port = {
      publish = function() return nil end,
    },
  }
  luassert.truthy(event_feed.publish(game, { kind = "k", text = "t" }) == false,
    "nil port result should normalize to false")
end)

end)
