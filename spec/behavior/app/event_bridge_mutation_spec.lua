-- Mutation-pinning spec for src/app/event_bridge.lua.
-- Drives M.install with a fake LuaAPI so we can capture a registered event
-- callback, invoke it, and observe that state.game is set from get_current_game.

local runtime_context = require("src.host.context")
local visual_hold = require("src.ui.visual_hold")
local event_bridge = require("src.app.event_bridge")

describe("event_bridge _dispatch_or_defer L16 get_current_game survivor", function()
  it("stores the get_current_game() result on state.game when an event fires (L16 ->nil)", function()
    local registered = {}
    local fake_ctx = {
      env = {
        LuaAPI = {
          global_register_custom_event = function(name, callback)
            registered[name] = callback
          end,
        },
      },
    }
    local saved_ctx = runtime_context.current()
    runtime_context.set_current(fake_ctx)

    -- state.game is assigned before run_or_defer runs, so a no-op stub is enough
    -- to isolate the L16 assignment without invoking downstream handlers.
    local saved_run_or_defer = visual_hold.run_or_defer
    visual_hold.run_or_defer = function() end

    local sentinel_game = { marker = "the_current_game" }
    local state = {}
    event_bridge.install(state, function() return sentinel_game end)

    -- Invoke the first registered callback with the host's (self, _, data) shape.
    local _, callback = next(registered)
    local fired = callback ~= nil
    if callback then
      callback(nil, nil, { payload = true })
    end

    visual_hold.run_or_defer = saved_run_or_defer
    runtime_context.set_current(saved_ctx)

    assert(fired, "at least one event must have been registered to invoke")
    -- L16 `get_current_game()` -> nil would leave state.game = nil.
    assert(state.game == sentinel_game,
      "state.game must be the get_current_game() result; got " .. tostring(state.game))
  end)
end)
