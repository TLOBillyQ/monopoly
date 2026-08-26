-- Mutation-pinning specs for src/foundation/ports/anim_port_factory.lua.
-- 原生 LuaUnit：文件级 Test* 类 + lu.assertEvalToTrue（实际在前）。

local lu = require("luaunit")
local anim_port_factory = require("src.foundation.ports.anim_port_factory")

TestAnimPortFactory = {}

function TestAnimPortFactory:test_is_enabled_reads_gate_port()
  local port = anim_port_factory.build("move")
  local game_on = { anim_gate_port = { wait_move_anim = true } }
  local game_off = { anim_gate_port = { wait_move_anim = false } }
  lu.assertEvalToTrue(port.is_enabled(game_on) == true,
    "gate true must enable the port")
  lu.assertEvalToTrue(port.is_enabled(game_off) == false,
    "gate false must disable the port")
  lu.assertEvalToTrue(port.is_enabled(nil) == false,
    "nil game must be disabled")
end

function TestAnimPortFactory:test_queue_returns_false_when_queue_method_missing_l21()
  -- L21 `return false` -> true: without queue_move_anim the port must not
  -- report success.
  local port = anim_port_factory.build("move")
  local game = {
    anim_gate_port = { wait_move_anim = true },
    -- queue_move_anim deliberately absent
  }
  lu.assertEvalToTrue(port.queue(game, { x = 1 }) == false,
    "queue must return false when the queue method is missing")
end

function TestAnimPortFactory:test_queue_dispatches_payload_and_returns_true()
  local port = anim_port_factory.build("move")
  local captured = nil
  local game = {
    anim_gate_port = { wait_move_anim = true },
    queue_move_anim = function(self, payload)
      captured = payload
    end,
  }
  lu.assertEvalToTrue(port.queue(game, { x = 1 }) == true,
    "queue must return true after dispatch")
  lu.assertEvalToTrue(captured ~= nil and captured.x == 1,
    "queue method must receive the payload; got " .. tostring(captured))
end

function TestAnimPortFactory:test_queue_returns_false_when_gate_disabled()
  local port = anim_port_factory.build("action")
  local game = {
    anim_gate_port = { wait_action_anim = false },
    queue_action_anim = function(self, payload) end,
  }
  lu.assertEvalToTrue(port.queue(game, {}) == false,
    "queue must return false when the gate is disabled")
end

return TestAnimPortFactory
