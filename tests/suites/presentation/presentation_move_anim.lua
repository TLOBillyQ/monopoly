local support = require("TestSupport")
local _assert_eq = support.assert_eq
local _with_patches = support.with_patches
local logger = require("src.core.utils.logger")
local gameplay_rules = require("src.core.config.gameplay_rules")
local move_anim = require("src.presentation.view.render.move_anim")
local runtime_ports = require("src.core.ports.runtime_ports")
local vec3 = require("fixtures.vec3")

local function _test_move_anim_sequence_stops_unit_when_duration_finishes()
  local _vec3 = vec3.with_sub_length
  local scheduled = {}
  local calls = {}
  local scene = {
    tiles = {
      [1] = { get_position = function() return _vec3(0, 0, 0) end },
      [2] = { get_position = function() return _vec3(10, 0, 0) end },
    },
    units_by_player_id = {
      [1] = {
        start_move_by_direction = function()
          calls[#calls + 1] = "start_move_by_direction"
        end,
        force_stop_move = function()
          calls[#calls + 1] = "force_stop_move"
        end,
        stop_anim = function()
          calls[#calls + 1] = "stop_anim"
        end,
      },
    },
  }

  local total = nil
  _with_patches({
    { target = runtime_ports, key = "schedule", value = function(delay, fn)
      scheduled[#scheduled + 1] = { delay = delay, fn = fn }
    end },
  }, function()
    total = move_anim.play_sequence(scene, {
      player_id = 1,
      seq = 11,
      from_index = 1,
      to_index = 2,
      direction = { x = 1, y = 0, z = 0 },
    })
  end)

  assert(total and total > 0, "move sequence should report positive duration")
  _assert_eq(calls[1], "start_move_by_direction", "move sequence should start unit move immediately")
  _assert_eq(#scheduled, 1, "move sequence should schedule one explicit finish-stop callback")
  scheduled[1].fn()
  _assert_eq(calls[2], "force_stop_move", "finish callback should stop movement")
  _assert_eq(calls[3], "stop_anim", "finish callback should stop looping anim")
end

local function _test_move_anim_stale_finish_callback_does_not_stop_new_sequence()
  local _vec3 = vec3.with_sub_length
  local scheduled = {}
  local calls = {}
  local scene = {
    tiles = {
      [1] = { get_position = function() return _vec3(0, 0, 0) end },
      [2] = { get_position = function() return _vec3(10, 0, 0) end },
      [3] = { get_position = function() return _vec3(20, 0, 0) end },
    },
    units_by_player_id = {
      [1] = {
        start_move_by_direction = function()
          calls[#calls + 1] = "start_move_by_direction"
        end,
        force_stop_move = function()
          calls[#calls + 1] = "force_stop_move"
        end,
        stop_anim = function()
          calls[#calls + 1] = "stop_anim"
        end,
      },
    },
  }

  _with_patches({
    { target = runtime_ports, key = "schedule", value = function(delay, fn)
      scheduled[#scheduled + 1] = { delay = delay, fn = fn }
    end },
  }, function()
    move_anim.play_sequence(scene, {
      player_id = 1,
      seq = 21,
      from_index = 1,
      to_index = 2,
      direction = { x = 1, y = 0, z = 0 },
    })
    move_anim.play_sequence(scene, {
      player_id = 1,
      seq = 22,
      from_index = 2,
      to_index = 3,
      direction = { x = 1, y = 0, z = 0 },
    })
  end)

  _assert_eq(#scheduled, 2, "overlapping sequences should schedule two finish callbacks")
  scheduled[1].fn()
  _assert_eq(#calls, 2, "stale finish callback should not stop the new active sequence")
  scheduled[2].fn()
  _assert_eq(calls[3], "force_stop_move", "active finish callback should stop movement")
  _assert_eq(calls[4], "stop_anim", "active finish callback should stop anim")
end

local function _test_move_anim_debug_log_writes_when_enabled()
  local _vec3 = vec3.with_sub_length
  local scene = {
    tiles = {
      [1] = { get_position = function() return _vec3(0, 0, 0) end },
      [2] = { get_position = function() return _vec3(10, 0, 0) end },
    },
    units_by_player_id = {
      [1] = {
        start_move_by_direction = function() end,
        force_stop_move = function() end,
        stop_anim = function() end,
      },
    },
  }

  logger.clear()
  _with_patches({
    { target = gameplay_rules, key = "move_anim_debug_log_enabled", value = true },
    { target = logger, key = "info_per_turn_limit", value = 100 },
    { target = logger, key = "info_turn_provider", value = nil },
    { target = runtime_ports, key = "schedule", value = function(_, fn)
      fn()
    end },
  }, function()
    move_anim.play_sequence(scene, {
      player_id = 1,
      seq = 31,
      from_index = 1,
      to_index = 2,
      direction = { x = 1, y = 0, z = 0 },
    })
  end)

  local text = logger.get_text_by_level("info")
  assert(string.find(text, "[MoveAnim] play_sequence_start", 1, true) ~= nil, "debug log should include sequence start")
  assert(string.find(text, "[MoveAnim] finish_stop", 1, true) ~= nil, "debug log should include finish stop")
end

return {
  name = "presentation.move_anim",
  tests = {
    {
      name = "_test_move_anim_sequence_stops_unit_when_duration_finishes",
      run = _test_move_anim_sequence_stops_unit_when_duration_finishes,
    },
    {
      name = "_test_move_anim_stale_finish_callback_does_not_stop_new_sequence",
      run = _test_move_anim_stale_finish_callback_does_not_stop_new_sequence,
    },
    {
      name = "_test_move_anim_debug_log_writes_when_enabled",
      run = _test_move_anim_debug_log_writes_when_enabled,
    },
  },
}
