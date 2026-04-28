local runtime_constants = require("src.config.gameplay.runtime_constants")
local move_anim = require("src.ui.render.move_anim")
local runtime_ports = require("src.core.ports.runtime_ports")
local gameplay_read_port = require("src.ui.pres.gameplay_read_port")
local support = require("support.move_anim_support")

local _assert_eq = support.assert_eq
local _with_patches = support.with_patches

local function _test_move_anim_teleport_snaps_local_player_without_starting_move()
  local calls = {}
  local target_pos = nil
  local scene = support.new_scene_with_linear_tiles(2, {
    units_by_player_id = {
      [1] = {
        start_move_by_direction = function() calls[#calls + 1] = "start_move_by_direction" end,
        force_stop_move = function() calls[#calls + 1] = "force_stop_move" end,
        stop_anim = function() calls[#calls + 1] = "stop_anim" end,
        set_position = function(pos)
          calls[#calls + 1] = "set_position"
          target_pos = pos
        end,
      },
    },
  })

  local duration = move_anim.play_teleport(scene, {
    player_id = 1,
    seq = 84,
    to_index = 2,
  })

  _assert_eq(duration, 0, "teleport move should finish immediately")
  _assert_eq(calls[1], "force_stop_move", "teleport should stop current motion before snap")
  _assert_eq(calls[2], "stop_anim", "teleport should stop current anim before snap")
  _assert_eq(calls[3], "set_position", "teleport should snap player unit directly")
  _assert_eq(calls[4], nil, "teleport should not start movement")
  _assert_eq(target_pos.x, 10, "teleport should snap to destination tile x")
end

local function _test_move_anim_teleport_snaps_synthetic_actor_without_force_start_move()
  local calls = {}
  local target_pos = nil
  local scene = support.new_scene_with_linear_tiles(2, {
    units_by_player_id = {
      [-2] = {
        force_start_move = function() calls[#calls + 1] = "force_start_move" end,
        force_stop_move = function() calls[#calls + 1] = "force_stop_move" end,
        ai_command_stop_move = function() calls[#calls + 1] = "ai_command_stop_move" end,
        stop_anim = function() calls[#calls + 1] = "stop_anim" end,
        set_position = function(pos)
          calls[#calls + 1] = "set_position"
          target_pos = pos
        end,
      },
    },
  })

  _with_patches({
    { target = runtime_ports, key = "resolve_role", value = function(player_id)
      if player_id == -2 then
        return { is_synthetic_actor = true }
      end
      return nil
    end },
  }, function()
    local duration = move_anim.play_teleport(scene, {
      player_id = -2,
      seq = 85,
      to_index = 2,
    })

    _assert_eq(duration, 0, "synthetic teleport should finish immediately")
  end)

  _assert_eq(calls[1], "force_stop_move", "synthetic teleport should stop forced motion first")
  _assert_eq(calls[2], "ai_command_stop_move", "synthetic teleport should clear host ai move state")
  _assert_eq(calls[3], "stop_anim", "synthetic teleport should stop anim before snap")
  _assert_eq(calls[4], "set_position", "synthetic teleport should snap unit directly")
  _assert_eq(calls[5], nil, "synthetic teleport should not start forced movement")
  _assert_eq(target_pos.x, 10, "synthetic teleport should snap to destination tile x")
end

local function _test_move_anim_teleport_snaps_vehicle_presentation()
  local calls = {}
  local target_pos = nil
  local scene = support.new_scene_with_linear_tiles(2, {
    units_by_player_id = {
      [1] = {
        force_stop_move = function() calls[#calls + 1] = "force_stop_move" end,
        stop_anim = function() calls[#calls + 1] = "stop_anim" end,
        set_position = function() calls[#calls + 1] = "set_position" end,
      },
    },
  })

  _with_patches({
    { target = gameplay_read_port, key = "resolve_vehicle_seat_id", value = function(vehicle_id)
      return vehicle_id == "vehicle_teleport" and 9 or nil
    end },
    { target = runtime_ports, key = "resolve_vehicle_helper", value = function()
      return {
        emit_vehicle_stop = function(player_id)
          calls[#calls + 1] = "emit_vehicle_stop:" .. tostring(player_id)
        end,
        emit_vehicle_set_position = function(player_id, pos)
          calls[#calls + 1] = "emit_vehicle_set_position:" .. tostring(player_id)
          target_pos = pos
        end,
      }
    end },
  }, function()
    local duration = move_anim.play_teleport(scene, {
      player_id = 1,
      seq = 86,
      to_index = 2,
      vehicle_id = "vehicle_teleport",
    })

    _assert_eq(duration, 0, "vehicle teleport should finish immediately")
  end)

  _assert_eq(calls[1], "emit_vehicle_stop:1", "vehicle teleport should stop vehicle first")
  _assert_eq(calls[2], "force_stop_move", "vehicle teleport should stop control unit motion")
  _assert_eq(calls[3], "stop_anim", "vehicle teleport should stop unit anim before snap")
  _assert_eq(calls[4], "emit_vehicle_set_position:1", "vehicle teleport should snap vehicle directly")
  _assert_eq(calls[5], nil, "vehicle teleport should not fall back to unit.set_position")
  _assert_eq(target_pos.x, 10, "vehicle teleport should snap to destination tile x")
end

local function _build_step_duration_scene(length)
  return support.new_scene_with_linear_tiles(2, {
    step_length = length,
  })
end

local function _test_move_anim_step_duration_uses_vehicle_accel_curve_for_short_hops()
  local duration = nil

  _with_patches({
    { target = runtime_constants, key = "vehicle_speed", value = 10 },
    { target = runtime_constants, key = "vehicle_accel", value = 5 },
    { target = gameplay_read_port, key = "resolve_vehicle_seat_id", value = function(vehicle_id)
      return vehicle_id == "vehicle_1" and 1 or nil
    end },
    { target = package.loaded, key = "src.ui.render.move_anim", value = nil },
  }, function()
    local fresh_move_anim = require("src.ui.render.move_anim")
    duration = fresh_move_anim.step_duration(_build_step_duration_scene(5), 1, 2, {
      vehicle_id = "vehicle_1",
    })
  end)

  _assert_eq(duration, 2, "vehicle step duration should use the accelerate-decelerate curve when hop is below critical distance")
end

local function _test_move_anim_step_duration_falls_back_to_linear_speed_when_vehicle_accel_missing()
  local duration = nil

  _with_patches({
    { target = runtime_constants, key = "vehicle_speed", value = 4 },
    { target = runtime_constants, key = "vehicle_accel", value = 0 },
    { target = gameplay_read_port, key = "resolve_vehicle_seat_id", value = function(vehicle_id)
      return vehicle_id == "vehicle_2" and 2 or nil
    end },
    { target = package.loaded, key = "src.ui.render.move_anim", value = nil },
  }, function()
    local fresh_move_anim = require("src.ui.render.move_anim")
    duration = fresh_move_anim.step_duration(_build_step_duration_scene(12), 1, 2, {
      vehicle_id = "vehicle_2",
    })
  end)

  _assert_eq(duration, 3, "vehicle step duration should fall back to linear speed when accel is unavailable")
end

return {
  name = "presentation.move_anim_teleport_and_vehicle",
  tests = {
    { name = "teleport_snaps_local_player_without_starting_move", run = _test_move_anim_teleport_snaps_local_player_without_starting_move },
    { name = "teleport_snaps_synthetic_actor_without_force_start_move", run = _test_move_anim_teleport_snaps_synthetic_actor_without_force_start_move },
    { name = "teleport_snaps_vehicle_presentation", run = _test_move_anim_teleport_snaps_vehicle_presentation },
    { name = "step_duration_uses_vehicle_accel_curve_for_short_hops", run = _test_move_anim_step_duration_uses_vehicle_accel_curve_for_short_hops },
    { name = "step_duration_falls_back_to_linear_speed_when_vehicle_accel_missing", run = _test_move_anim_step_duration_falls_back_to_linear_speed_when_vehicle_accel_missing },
  },
}
