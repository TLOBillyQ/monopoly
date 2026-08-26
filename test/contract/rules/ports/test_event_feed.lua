local lu = require("luaunit")

local event_feed = require("src.rules.ports.event_feed")

TestEventFeed = {}

function TestEventFeed:test_returns_false_when_game_port_missing()
  local ok = event_feed.publish({}, { kind = "turn_start", text = "start" })
  lu.assertEquals(ok, false)
end

function TestEventFeed:test_returns_false_when_required_fields_missing()
  local game = {
    event_feed_port = {
      publish = function()
        return true
      end,
    },
  }

  lu.assertEquals(event_feed.publish(game, { text = "x" }), false)
  lu.assertEquals(event_feed.publish(game, { kind = "k" }), false)
end

function TestEventFeed:test_calls_port_publish_and_returns_true()
  local called_game = nil
  local called_event = nil
  local game = {
    event_feed_port = {
      publish = function(_, arg_game, arg_event)
        called_game = arg_game
        called_event = arg_event
        return true
      end,
    },
  }
  local event = { kind = "turn_start", text = "回合开始", tip = true }

  local ok = event_feed.publish(game, event)
  lu.assertEquals(ok, true)
  lu.assertEquals(called_game, game)
  lu.assertEquals(called_event, event)
end


return TestEventFeed
