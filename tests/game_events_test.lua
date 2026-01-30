local GameEvents = require("Library.Monopoly.GameEvents")

local events = GameEvents.new()
local called = 0
local last = nil

events:on("ping", function(payload)
  called = called + 1
  last = payload
end)

events:emit("ping", { value = 42 })

assert(called == 1, "event handler should be called once")
assert(last and last.value == 42, "event payload should pass through")

print("ok - game events")
