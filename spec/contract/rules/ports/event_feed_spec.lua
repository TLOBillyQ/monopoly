local event_feed = require("src.rules.ports.event_feed")

describe("rules.ports.event_feed", function()
  it("returns false when game port missing", function()
    local ok = event_feed.publish({}, { kind = "turn_start", text = "start" })
    assert.equals(false, ok)
  end)

  it("returns false when required fields missing", function()
    local game = {
      event_feed_port = {
        publish = function()
          return true
        end,
      },
    }

    assert.equals(false, event_feed.publish(game, { text = "x" }))
    assert.equals(false, event_feed.publish(game, { kind = "k" }))
  end)

  it("calls port publish and returns true", function()
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
    assert.equals(true, ok)
    assert.equals(game, called_game)
    assert.equals(event, called_event)
  end)
end)
