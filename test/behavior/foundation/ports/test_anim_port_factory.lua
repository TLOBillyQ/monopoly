require("test.bootstrap").install_package_paths()
-- busted injects the extensible assertion object into each file environment.
-- luacheck: ignore 143
local luassert = assert

local anim_port_factory = require("src.foundation.ports.anim_port_factory")

describe("TestAnimPortFactory", function()

  it("test_is_enabled_reads_gate_port", function()
    local port = anim_port_factory.build("move")
    local game_on = { anim_gate_port = { wait_move_anim = true } }
    local game_off = { anim_gate_port = { wait_move_anim = false } }
    luassert.truthy(port.is_enabled(game_on) == true, "gate true must enable the port")
    luassert.truthy(port.is_enabled(game_off) == false, "gate false must disable the port")
    luassert.truthy(port.is_enabled(nil) == false, "nil game must be disabled")
  end)

  it("test_queue_returns_false_when_queue_method_missing_l21", function()
    -- L21 `return false` -> true: without queue_move_anim the port must not
    -- report success.
    local port = anim_port_factory.build("move")
    local game = {
      anim_gate_port = { wait_move_anim = true },
      -- queue_move_anim deliberately absent
    }
    luassert.truthy(port.queue(game, { x = 1 }) == false, "queue must return false when the queue method is missing")
  end)

  it("test_queue_dispatches_payload_and_returns_true", function()
    local port = anim_port_factory.build("move")
    local captured = nil
    local game = {
      anim_gate_port = { wait_move_anim = true },
      queue_move_anim = function(self, payload)
        captured = payload
      end,
    }
    luassert.truthy(port.queue(game, { x = 1 }) == true, "queue must return true after dispatch")
    luassert.truthy(captured ~= nil and captured.x == 1, "queue method must receive the payload; got " .. tostring(captured))
  end)

  it("test_queue_returns_false_when_gate_disabled", function()
    local port = anim_port_factory.build("action")
    local game = {
      anim_gate_port = { wait_action_anim = false },
      queue_action_anim = function(self, payload) end,
    }
    luassert.truthy(port.queue(game, {}) == false, "queue must return false when the gate is disabled")
  end)

end)
