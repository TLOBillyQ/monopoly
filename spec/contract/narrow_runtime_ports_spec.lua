---@diagnostic disable: undefined-global, undefined-field
local support = require("tests.support.shared_support")

local action_anim_port = require("src.core.ports.action_anim")
local turn_roll = require("src.turn.phases.roll")
local turn_move = require("src.turn.phases.move")

describe("narrow_runtime_ports_contract", function()
  it("game_requires_explicit_popup_port", function()
    local game = support.new_game({ ai = {} })
    game.popup_port = nil
    game.ui_port = {
      push_popup = function()
        error("legacy ui_port fallback should not be used")
      end,
    }

    local ok, err = pcall(function()
      game:ensure_popup_port()
    end)

    assert.equals(false, ok, "ensure_popup_port should reject missing popup_port")
    assert.is_not_nil(err, "ensure_popup_port should report missing popup_port")
    assert.is_true(tostring(err):find("missing popup_port", 1, true) ~= nil,
      "ensure_popup_port should report missing popup_port")
  end)

  it("game_requires_explicit_tile_feedback_port", function()
    local game = support.new_game({ ai = {} })
    game.tile_feedback_port = nil
    game.ui_port = {
      on_tile_upgraded = function()
        error("legacy ui_port fallback should not be used")
      end,
    }

    local ok, err = pcall(function()
      game:ensure_tile_feedback_port()
    end)

    assert.equals(false, ok, "ensure_tile_feedback_port should reject missing tile_feedback_port")
    assert.is_not_nil(err, "ensure_tile_feedback_port should report missing tile_feedback_port")
    assert.is_true(tostring(err):find("missing tile_feedback_port", 1, true) ~= nil,
      "ensure_tile_feedback_port should report missing tile_feedback_port")
  end)

  it("game_requires_explicit_board_visual_feedback_port", function()
    local game = support.new_game({ ai = {} })
    game.board_visual_feedback_port = nil

    local ok, err = pcall(function()
      game:ensure_board_visual_feedback_port()
    end)

    assert.equals(false, ok,
      "ensure_board_visual_feedback_port should reject missing board_visual_feedback_port")
    assert.is_not_nil(err, "ensure_board_visual_feedback_port should report missing board_visual_feedback_port")
    assert.is_true(tostring(err):find("missing board_visual_feedback_port", 1, true) ~= nil,
      "ensure_board_visual_feedback_port should report missing board_visual_feedback_port")
  end)

  it("action_anim_port_requires_anim_gate_port", function()
    local game = support.new_game({ ai = {} })
    game.anim_gate_port = nil
    game.ui_port = {
      wait_action_anim = true,
    }

    local ok, err = pcall(function()
      action_anim_port.is_enabled(game)
    end)

    assert.equals(false, ok, "action_anim_port should reject missing anim_gate_port")
    assert.is_not_nil(err, "action_anim_port should report missing anim_gate_port")
    assert.is_true(tostring(err):find("missing anim_gate_port", 1, true) ~= nil,
      "action_anim_port should report missing anim_gate_port")
  end)

  it("turn_roll_rejects_missing_anim_gate_port_even_with_ui_port", function()
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

    assert.equals(false, ok, "turn_roll should reject missing anim_gate_port")
    assert.is_not_nil(err, "turn_roll should report missing anim_gate_port")
    assert.is_true(tostring(err):find("missing anim_gate_port", 1, true) ~= nil,
      "turn_roll should report missing anim_gate_port")
  end)

  it("turn_move_rejects_missing_anim_gate_port_even_with_ui_port", function()
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

    assert.equals(false, ok, "turn_move should reject missing anim_gate_port")
    assert.is_not_nil(err, "turn_move should report missing anim_gate_port")
    assert.is_true(tostring(err):find("missing anim_gate_port", 1, true) ~= nil,
      "turn_move should report missing anim_gate_port")
  end)
end)
