---@diagnostic disable: undefined-global, undefined-field
local luassert = assert

local support = require("test.support.shared_support")

local action_anim_port = require("src.foundation.ports.action_anim")
local turn_roll = require("src.turn.phases.roll")
local turn_move = require("src.turn.phases.move")

describe("TestNarrowRuntimePorts", function()

  it("test_action_anim_port_requires_anim_gate_port", function()
  local game = support.new_game({ ai = {} })
  game.anim_gate_port = nil
  game.ui_port = {
    wait_action_anim = true,
  }

  local ok, err = pcall(function()
    action_anim_port.is_enabled(game)
  end)

  luassert.is.equal(false, ok, "action_anim_port should reject missing anim_gate_port")
  luassert.is_not_nil(err, "action_anim_port should report missing anim_gate_port")
  luassert.is_true(tostring(err):find("missing anim_gate_port", 1, true) ~= nil,
    "action_anim_port should report missing anim_gate_port")
  end)

  it("test_turn_roll_rejects_missing_anim_gate_port_even_with_ui_port", function()
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

  luassert.is.equal(false, ok, "turn_roll should reject missing anim_gate_port")
  luassert.is_not_nil(err, "turn_roll should report missing anim_gate_port")
  luassert.is_true(tostring(err):find("missing anim_gate_port", 1, true) ~= nil,
    "turn_roll should report missing anim_gate_port")
  end)

  it("test_turn_move_rejects_missing_anim_gate_port_even_with_ui_port", function()
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

  luassert.is.equal(false, ok, "turn_move should reject missing anim_gate_port")
  luassert.is_not_nil(err, "turn_move should report missing anim_gate_port")
  luassert.is_true(tostring(err):find("missing anim_gate_port", 1, true) ~= nil,
    "turn_move should report missing anim_gate_port")
  end)
end)
