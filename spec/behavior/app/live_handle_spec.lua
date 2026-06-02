-- live_handle is the single seam the e2e profile lane uses to reach the
-- running game model from inside the editor play runtime. It is deliberately
-- trivial (a stashed reference) so the unsuitable editor boundary stays thin.
local live_handle = require("src.app.testing.live_handle")

describe("app.testing.live_handle", function()
  before_each(function() live_handle.clear() end)

  it("returns nil before any game is set", function()
    assert.is_nil(live_handle.get())
  end)

  it("returns the most recently set game", function()
    local g1, g2 = { id = 1 }, { id = 2 }
    live_handle.set(g1)
    assert.equals(g1, live_handle.get())
    live_handle.set(g2)
    assert.equals(g2, live_handle.get())
  end)

  it("also stashes the app state so the lane can pump the loop", function()
    local game, state = { id = "g" }, { id = "s" }
    live_handle.set(game, state)
    assert.equals(game, live_handle.get())
    assert.equals(state, live_handle.get_state())
  end)

  it("get_state is nil before any session is set", function()
    assert.is_nil(live_handle.get_state())
  end)

  it("clear drops both stashed references", function()
    live_handle.set({ id = 1 }, { id = 2 })
    live_handle.clear()
    assert.is_nil(live_handle.get())
    assert.is_nil(live_handle.get_state())
  end)
end)
