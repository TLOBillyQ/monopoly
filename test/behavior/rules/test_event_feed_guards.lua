-- event_feed.publish 的守卫与布尔归一化:#293 复核——_bool_or_false 的
-- or→and 变异(or 变异让真值塌成 false)与两处 return false 均未测。
local lu = require("luaunit")

local event_feed = require("src.rules.ports.event_feed")

TestEventFeedGuards = {}

function TestEventFeedGuards:test_publish_returns_false_without_inputs()
  lu.assertEvalToTrue(event_feed.publish(nil, {}) == false,
    "nil game should not publish")
  lu.assertEvalToTrue(event_feed.publish({}, nil) == false,
    "nil event should not publish")
end

function TestEventFeedGuards:test_publish_rejects_invalid_event()
  lu.assertEvalToTrue(event_feed.publish({}, {}) == false,
    "event without kind/text should not publish")
end

function TestEventFeedGuards:test_publish_normalizes_the_port_result_to_boolean()
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
  lu.assertEvalToTrue(event_feed.publish(game, { kind = "k", text = "t" }) == true,
    "truthy port result should normalize to true")
  lu.assertEvalToTrue(calls == 1, "port should be called once")
end

function TestEventFeedGuards:test_publish_passes_through_falsy_port_result()
  local game = {
    event_feed_port = {
      publish = function() return nil end,
    },
  }
  lu.assertEvalToTrue(event_feed.publish(game, { kind = "k", text = "t" }) == false,
    "nil port result should normalize to false")
end

return TestEventFeedGuards
