---@diagnostic disable: undefined-global, undefined-field
local lu = require("luaunit")

local support = require("test.support.shared_support")

local action_anim_port = require("src.foundation.ports.action_anim")
local turn_roll = require("src.turn.phases.roll")
local turn_move = require("src.turn.phases.move")

TestNarrowRuntimePorts = {}

function TestNarrowRuntimePorts:test_action_anim_port_requires_anim_gate_port()
  local game = support.new_game({ ai = {} })
  game.anim_gate_port = nil
  game.ui_port = {
    wait_action_anim = true,
  }

  local ok, err = pcall(function()
    action_anim_port.is_enabled(game)
  end)

  lu.assertEquals(ok, false, "action_anim_port should reject missing anim_gate_port")
  lu.assertNotNil(err, "action_anim_port should report missing anim_gate_port")
  lu.assertTrue(tostring(err):find("missing anim_gate_port", 1, true) ~= nil,
    "action_anim_port should report missing anim_gate_port")
end

function TestNarrowRuntimePorts:test_turn_roll_rejects_missing_anim_gate_port_even_with_ui_port()
  local game = support.new_game({ ai = {} })
  local player = game:current_player()
  game.anim_gate_port = nil
  game.ui_port = {
    wait_action_anim = true,
  }

  local ok, err = pcall(function()
    turn_roll._phase_roll({ game = game }, {
      player = player,
      rolls = { 2 },
      raw_total = 2,
      total = 2,
    })
  end)

  lu.assertEquals(ok, false, "turn_roll should reject missing anim_gate_port")
  lu.assertNotNil(err, "turn_roll should report missing anim_gate_port")
  lu.assertTrue(tostring(err):find("missing anim_gate_port", 1, true) ~= nil,
    "turn_roll should report missing anim_gate_port")
end

function TestNarrowRuntimePorts:test_turn_move_rejects_missing_anim_gate_port_even_with_ui_port()
  local game = support.new_game({ ai = {} })
  local player = game:current_player()
  game.last_turn = game.last_turn or {}
  game.anim_gate_port = nil
  game.ui_port = {
    wait_move_anim = true,
  }

  local ok, err = pcall(function()
    turn_move({ game = game }, {
      player = player,
      total = 1,
      raw_total = 1,
    })
  end)

  lu.assertEquals(ok, false, "turn_move should reject missing anim_gate_port")
  lu.assertNotNil(err, "turn_move should report missing anim_gate_port")
  lu.assertTrue(tostring(err):find("missing anim_gate_port", 1, true) ~= nil,
    "turn_move should report missing anim_gate_port")
end


return TestNarrowRuntimePorts
