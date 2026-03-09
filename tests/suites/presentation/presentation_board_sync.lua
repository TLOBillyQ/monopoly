local support = require("TestSupport")
local _assert_eq = support.assert_eq
local _with_patches = support.with_patches
local runtime_state = require("src.core.state_access.runtime_state")
local vec3 = require("fixtures.vec3")

local function _build_board_refresh_test_env(opts)
  opts = opts or {}
  local calls = {}
  local unit = opts.unit or {}
  local state = {
    board_scene = {
      ground = {
        get_position = function()
          return { y = 0 }
        end,
      },
    },
    tile_positions = {
      [1] = vec3.with_add(10, 0, 20),
      [2] = vec3.with_add(20, 0, 30),
    },
    tile_spacing = 0,
    player_units = {
      [1] = unit,
    },
    _log_once = {},
  }
  local ui_model = {
    board = {
      phase = opts.phase or "start",
      move_anim = opts.move_anim,
      move_followup_pending = opts.move_followup_pending == true,
      vehicle_resync_seq = opts.vehicle_resync_seq or 0,
      tile_count = 2,
      tiles = {
        { id = 1 },
        { id = 2 },
      },
      players = {
        {
          id = 1,
          name = "P1",
          position = opts.position or 1,
          eliminated = false,
          seat_id = opts.seat_id,
        },
      },
    },
  }
  return {
    calls = calls,
    state = state,
    ui_model = ui_model,
    unit = unit,
  }
end

local function _with_board_refresh_patches(extra_patches, fn)
  local anchors = require("src.presentation.view.render.board.anchors")
  local startup_render = require("src.presentation.view.render.board.startup_render")
  local player_units = require("src.presentation.view.render.board.player_units")
  local patches = {
    { target = anchors, key = "ensure_tile_anchors", value = function() end },
    { target = startup_render, key = "apply", value = function() end },
    { target = player_units, key = "ensure_player_units", value = function() end },
  }
  if type(extra_patches) == "table" then
    for _, patch in ipairs(extra_patches) do
      patches[#patches + 1] = patch
    end
  end
  _with_patches(patches, fn)
end

local function _test_board_refresh_stops_force_move_before_set_position()
  local board_view = require("src.presentation.view.render.board")
  local env = _build_board_refresh_test_env()
  env.unit.force_stop_move = function()
    env.calls[#env.calls + 1] = "force_stop_move"
  end
  env.unit.stop_anim = function()
    env.calls[#env.calls + 1] = "stop_anim"
  end
  env.unit.set_position = function(pos)
    env.calls[#env.calls + 1] = "set_position"
    env.target_pos = pos
  end

  _with_board_refresh_patches(nil, function()
    board_view.refresh(env.state, env.ui_model, function() end, function() return "presentation_board_sync" end)
  end)

  _assert_eq(env.calls[1], "force_stop_move", "refresh should stop force move before position sync")
  _assert_eq(env.calls[2], "stop_anim", "refresh should stop anim before position sync")
  _assert_eq(env.calls[3], "set_position", "refresh should snap after stopping force move")
  _assert_eq(env.target_pos.x, 10, "refresh should snap to tile x")
  _assert_eq(env.target_pos.z, 20, "refresh should snap to tile z")
end

local function _test_board_refresh_falls_back_to_ai_stop_before_set_position()
  local board_view = require("src.presentation.view.render.board")
  local env = _build_board_refresh_test_env()
  env.unit.ai_command_stop_move = function(duration)
    env.calls[#env.calls + 1] = "ai_command_stop_move:" .. tostring(duration)
  end
  env.unit.stop_anim = function()
    env.calls[#env.calls + 1] = "stop_anim"
  end
  env.unit.set_position = function(pos)
    env.calls[#env.calls + 1] = "set_position"
    env.target_pos = pos
  end

  _with_board_refresh_patches(nil, function()
    board_view.refresh(env.state, env.ui_model, function() end, function() return "presentation_board_sync" end)
  end)

  _assert_eq(env.calls[1], "ai_command_stop_move:0", "refresh should fall back to ai stop before sync")
  _assert_eq(env.calls[2], "stop_anim", "refresh should stop anim after ai stop fallback")
  _assert_eq(env.calls[3], "set_position", "refresh should snap after ai stop fallback")
  _assert_eq(env.target_pos.x, 10, "refresh should still snap to tile x after ai stop fallback")
end

local function _test_board_refresh_stops_vehicle_before_vehicle_set_position()
  local board_view = require("src.presentation.view.render.board")
  local runtime_ports = require("src.core.ports.runtime_ports")
  local gameplay_read_port = require("src.presentation.model.gameplay_read_port")
  local env = _build_board_refresh_test_env({ seat_id = 4001 })
  local vehicle_helper = {
    emit_vehicle_stop = function(role_id)
      env.calls[#env.calls + 1] = "emit_vehicle_stop:" .. tostring(role_id)
    end,
    emit_vehicle_set_position = function(role_id, pos)
      env.calls[#env.calls + 1] = "emit_vehicle_set_position:" .. tostring(role_id)
      env.target_pos = pos
    end,
  }
  env.unit.force_stop_move = function()
    env.calls[#env.calls + 1] = "force_stop_move"
  end
  env.unit.stop_anim = function()
    env.calls[#env.calls + 1] = "stop_anim"
  end
  env.unit.set_position = function()
    env.calls[#env.calls + 1] = "set_position"
  end

  _with_board_refresh_patches({
    { target = runtime_ports, key = "resolve_vehicle_helper", value = function() return vehicle_helper end },
    { target = gameplay_read_port, key = "resolve_vehicle_seat_id", value = function(seat_id) return seat_id end },
  }, function()
    board_view.refresh(env.state, env.ui_model, function() end, function() return "presentation_board_sync" end)
  end)

  _assert_eq(env.calls[1], "emit_vehicle_stop:1", "vehicle sync should stop vehicle first")
  _assert_eq(env.calls[2], "force_stop_move", "vehicle sync should also stop the ctrl unit")
  _assert_eq(env.calls[3], "stop_anim", "vehicle sync should stop anim before snap")
  _assert_eq(env.calls[4], "emit_vehicle_set_position:1", "vehicle sync should snap vehicle after stop")
  _assert_eq(env.calls[5], nil, "vehicle sync should not fall back to unit.set_position")
  _assert_eq(env.target_pos.x, 10, "vehicle sync should target tile x")
end

local function _test_board_refresh_suppresses_stop_and_snap_during_wait_move_anim()
  local board_view = require("src.presentation.view.render.board")
  local env = _build_board_refresh_test_env({
    phase = "wait_move_anim",
    move_anim = { seq = 1 },
  })
  local board_runtime = runtime_state.ensure_board_runtime(env.state)
  env.unit.force_stop_move = function()
    env.calls[#env.calls + 1] = "force_stop_move"
  end
  env.unit.stop_anim = function()
    env.calls[#env.calls + 1] = "stop_anim"
  end
  env.unit.set_position = function()
    env.calls[#env.calls + 1] = "set_position"
  end

  _with_board_refresh_patches(nil, function()
    board_view.refresh(env.state, env.ui_model, function() end, function() return "presentation_board_sync" end)
  end)

  _assert_eq(#env.calls, 0, "wait_move_anim should suppress stop and snap")
  _assert_eq(board_runtime.board_sync_pending, true, "wait_move_anim should mark board_sync_pending")
end

local function _test_board_refresh_replays_pending_sync_with_stop_after_wait_move_anim()
  local board_view = require("src.presentation.view.render.board")
  local env = _build_board_refresh_test_env({
    phase = "wait_move_anim",
    move_anim = { seq = 1 },
  })
  local board_runtime = runtime_state.ensure_board_runtime(env.state)
  env.unit.force_stop_move = function()
    env.calls[#env.calls + 1] = "force_stop_move"
  end
  env.unit.stop_anim = function()
    env.calls[#env.calls + 1] = "stop_anim"
  end
  env.unit.set_position = function(pos)
    env.calls[#env.calls + 1] = "set_position"
    env.target_pos = pos
  end

  _with_board_refresh_patches(nil, function()
    board_view.refresh(env.state, env.ui_model, function() end, function() return "presentation_board_sync" end)
    _assert_eq(#env.calls, 0, "suppressed refresh should not stop or snap")
    env.ui_model.board.phase = "start"
    env.ui_model.board.move_anim = nil
    board_view.refresh(env.state, env.ui_model, function() end, function() return "presentation_board_sync" end)
  end)

  _assert_eq(env.calls[1], "force_stop_move", "pending sync should stop motion after wait_move_anim")
  _assert_eq(env.calls[2], "stop_anim", "pending sync should stop anim after motion stop")
  _assert_eq(env.calls[3], "set_position", "pending sync should snap after stop")
  _assert_eq(board_runtime.board_sync_pending, false, "pending sync should clear board_sync_pending after replay")
  _assert_eq(env.target_pos.z, 20, "pending sync should snap to the current tile position")
end

return {
  name = "presentation.board_sync",
  tests = {
    {
      name = "_test_board_refresh_stops_force_move_before_set_position",
      run = _test_board_refresh_stops_force_move_before_set_position,
    },
    {
      name = "_test_board_refresh_falls_back_to_ai_stop_before_set_position",
      run = _test_board_refresh_falls_back_to_ai_stop_before_set_position,
    },
    {
      name = "_test_board_refresh_stops_vehicle_before_vehicle_set_position",
      run = _test_board_refresh_stops_vehicle_before_vehicle_set_position,
    },
    {
      name = "_test_board_refresh_suppresses_stop_and_snap_during_wait_move_anim",
      run = _test_board_refresh_suppresses_stop_and_snap_during_wait_move_anim,
    },
    {
      name = "_test_board_refresh_replays_pending_sync_with_stop_after_wait_move_anim",
      run = _test_board_refresh_replays_pending_sync_with_stop_after_wait_move_anim,
    },
  },
}
