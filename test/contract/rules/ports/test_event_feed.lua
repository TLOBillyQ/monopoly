local luassert = assert

local event_feed = require("src.rules.ports.event_feed")

describe("TestEventFeed", function()

it("test_returns_false_when_game_port_missing", function()
  local ok = event_feed.publish({}, { kind = "turn_start", text = "start" })
  luassert.is.equal(false, ok)
end)

it("test_returns_false_when_required_fields_missing", function()
  local game = {
    event_feed_port = {
      publish = function()
        return true
      end,
    },
  }

  luassert.is.equal(false, event_feed.publish(game, { text = "x" }))
  luassert.is.equal(false, event_feed.publish(game, { kind = "k" }))
end)

it("test_calls_port_publish_and_returns_true", function()
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
  luassert.is.equal(true, ok)
  luassert.is.same(game, called_game)
  luassert.is.same(event, called_event)
end)

end)
