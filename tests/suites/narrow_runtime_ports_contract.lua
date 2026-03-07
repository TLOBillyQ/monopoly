local support = require("TestSupport")
local _assert_eq = support.assert_eq

local action_anim_port = require("src.core.ActionAnimPort")
local turn_roll = require("src.game.flow.turn.TurnRoll")
local turn_move = require("src.game.flow.turn.TurnMove")

local function _test_game_requires_explicit_popup_port()
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

  _assert_eq(ok, false, "ensure_popup_port should reject missing popup_port")
  assert(tostring(err):find("missing popup_port", 1, true) ~= nil,
    "ensure_popup_port should report missing popup_port")
end

local function _test_game_requires_explicit_tile_feedback_port()
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

  _assert_eq(ok, false, "ensure_tile_feedback_port should reject missing tile_feedback_port")
  assert(tostring(err):find("missing tile_feedback_port", 1, true) ~= nil,
    "ensure_tile_feedback_port should report missing tile_feedback_port")
end

local function _test_action_anim_port_requires_anim_gate_port()
  local game = support.new_game({ ai = {} })
  game.anim_gate_port = nil
  game.ui_port = {
    wait_action_anim = true,
  }

  local ok, err = pcall(function()
    action_anim_port.is_enabled(game)
  end)

  _assert_eq(ok, false, "action_anim_port should reject missing anim_gate_port")
  assert(tostring(err):find("missing anim_gate_port", 1, true) ~= nil,
    "action_anim_port should report missing anim_gate_port")
end

local function _test_turn_roll_rejects_missing_anim_gate_port_even_with_ui_port()
  local game = support.new_game({ ai = {} })
  local player = game:current_player()
  game.anim_gate_port = nil
  game.ui_port = {
    wait_action_anim = true,
  }

  local ok, err = pcall(function()
    turn_roll({ game = game }, {
      player = player,
      rolls = { 2 },
      raw_total = 2,
      total = 2,
    })
  end)

  _assert_eq(ok, false, "turn_roll should reject missing anim_gate_port")
  assert(tostring(err):find("missing anim_gate_port", 1, true) ~= nil,
    "turn_roll should report missing anim_gate_port")
end

local function _test_turn_move_rejects_missing_anim_gate_port_even_with_ui_port()
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

  _assert_eq(ok, false, "turn_move should reject missing anim_gate_port")
  assert(tostring(err):find("missing anim_gate_port", 1, true) ~= nil,
    "turn_move should report missing anim_gate_port")
end

return {
  name = "narrow_runtime_ports_contract",
  tests = {
    { name = "game_requires_explicit_popup_port", run = _test_game_requires_explicit_popup_port },
    { name = "game_requires_explicit_tile_feedback_port", run = _test_game_requires_explicit_tile_feedback_port },
    { name = "action_anim_port_requires_anim_gate_port", run = _test_action_anim_port_requires_anim_gate_port },
    { name = "turn_roll_rejects_missing_anim_gate_port_even_with_ui_port", run = _test_turn_roll_rejects_missing_anim_gate_port_even_with_ui_port },
    { name = "turn_move_rejects_missing_anim_gate_port_even_with_ui_port", run = _test_turn_move_rejects_missing_anim_gate_port_even_with_ui_port },
  },
}
