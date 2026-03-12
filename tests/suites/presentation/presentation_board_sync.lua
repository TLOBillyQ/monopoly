local support = require("support.presentation_support")
local _assert_eq = support.assert_eq
local _with_patches = support.with_patches
local gameplay_rules = require("src.core.config.gameplay_rules")
local runtime_state = require("src.core.state_access.runtime_state")
local vec3 = require("fixtures.vec3")

local function _build_board_refresh_test_env(opts)
  opts = opts or {}
  local calls = {}
  local unit = opts.unit or {}
  local ground_y = opts.ground_y or 0
  local tile_y_1 = opts.tile_y_1 or 0
  local tile_y_2 = opts.tile_y_2 or 0
  local state = {
    board_scene = {
      ground = {
        get_position = function()
          return { y = ground_y }
        end,
      },
    },
    tile_positions = {
      [1] = vec3.with_add(10, tile_y_1, 20),
      [2] = vec3.with_add(20, tile_y_2, 30),
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
  local board_cfg = gameplay_rules.board
  local patches = {
    { target = anchors, key = "ensure_tile_anchors", value = function() end },
    { target = startup_render, key = "apply", value = function() end },
    { target = player_units, key = "ensure_player_units", value = function() end },
    { target = gameplay_rules, key = "board", value = { player_min_ground_offset = 0.5 } },
  }
  if type(extra_patches) == "table" then
    for _, patch in ipairs(extra_patches) do
      patches[#patches + 1] = patch
    end
  end
  _with_patches(patches, function()
    fn()
    gameplay_rules.board = board_cfg
  end)
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
  _assert_eq(env.target_pos.y, 0.5, "refresh should clamp player y to configured minimum")
  _assert_eq(env.target_pos.z, 20, "refresh should snap to tile z")
end

local function _test_board_refresh_falls_back_to_ai_stop_before_set_position()
  local board_view = require("src.presentation.view.render.board")
  local env = _build_board_refresh_test_env()
  local fixed_zero = { kind = "fixed_zero", value = 0 }
  env.unit.ai_command_stop_move = function(duration)
    _assert_eq(duration, fixed_zero, "refresh should pass Fix32 zero into ai stop fallback")
    env.calls[#env.calls + 1] = "ai_command_stop_move"
  end
  env.unit.stop_anim = function()
    env.calls[#env.calls + 1] = "stop_anim"
  end
  env.unit.set_position = function(pos)
    env.calls[#env.calls + 1] = "set_position"
    env.target_pos = pos
  end

  _with_board_refresh_patches({
    { target = math, key = "tofixed", value = function(value)
      _assert_eq(value, 0, "ai stop fallback should only request zero duration")
      return fixed_zero
    end },
  }, function()
    board_view.refresh(env.state, env.ui_model, function() end, function() return "presentation_board_sync" end)
  end)

  _assert_eq(env.calls[1], "ai_command_stop_move", "refresh should fall back to ai stop before sync")
  _assert_eq(env.calls[2], "stop_anim", "refresh should stop anim after ai stop fallback")
  _assert_eq(env.calls[3], "set_position", "refresh should snap after ai stop fallback")
  _assert_eq(env.target_pos.x, 10, "refresh should still snap to tile x after ai stop fallback")
  _assert_eq(env.target_pos.y, 0.5, "refresh should use configured y offset after ai stop fallback")
end

local function _test_board_refresh_prefers_forced_move_stop_and_model_stop_before_set_position()
  local board_view = require("src.presentation.view.render.board")
  local env = _build_board_refresh_test_env()
  env.unit.stop_forced_move = function()
    env.calls[#env.calls + 1] = "stop_forced_move"
  end
  env.unit.ai_command_stop_move = function()
    env.calls[#env.calls + 1] = "ai_command_stop_move"
  end
  env.unit.stop_anim = function()
    env.calls[#env.calls + 1] = "stop_anim"
  end
  env.unit.model_stop_animation = function()
    env.calls[#env.calls + 1] = "model_stop_animation"
  end
  env.unit.set_position = function(pos)
    env.calls[#env.calls + 1] = "set_position"
    env.target_pos = pos
  end

  _with_board_refresh_patches(nil, function()
    board_view.refresh(env.state, env.ui_model, function() end, function() return "presentation_board_sync" end)
  end)

  _assert_eq(env.calls[1], "stop_forced_move", "refresh should prefer forced-move stop before ai fallback")
  _assert_eq(env.calls[2], "stop_anim", "refresh should stop display anim after motion stop")
  _assert_eq(env.calls[3], "model_stop_animation", "refresh should stop model anim before snap")
  _assert_eq(env.calls[4], "set_position", "refresh should snap after stop_forced_move path")
  _assert_eq(env.calls[5], nil, "refresh should not fall through to ai stop when forced stop exists")
  _assert_eq(env.target_pos.x, 10, "refresh should preserve tile x on forced stop path")
  _assert_eq(env.target_pos.y, 0.5, "refresh should preserve configured y offset on forced stop path")
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
  _assert_eq(env.target_pos.y, 0.5, "vehicle sync should use configured y offset")
end

local function _test_board_refresh_keeps_base_y_when_already_above_minimum()
  local board_view = require("src.presentation.view.render.board")
  local env = _build_board_refresh_test_env({
    ground_y = 0,
    tile_y_1 = 0.75,
  })
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

  _assert_eq(env.target_pos.y, 0.75, "refresh should keep base y when already above configured minimum")
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
  env.state.board_scene._move_anim_runtime = {
    active_token_by_player_id = {
      [1] = "1:1",
    },
  }
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
  _assert_eq(env.state.board_scene._move_anim_runtime.active_token_by_player_id[1], nil,
    "pending sync replay should clear the active move token")
  _assert_eq(env.target_pos.y, 0.5, "pending sync should use configured y offset after wait_move_anim")
  _assert_eq(env.target_pos.z, 20, "pending sync should snap to the current tile position")
end

local function _test_board_refresh_clear_player_token_releases_sequence_lock()
  local board_view = require("src.presentation.view.render.board")
  local env = _build_board_refresh_test_env()
  local sequence_calls = {}
  env.state.board_scene._move_anim_runtime = {
    active_token_by_player_id = {
      [1] = "1:301",
    },
    active_sequence_by_player_id = {
      [1] = {
        token = "1:301",
        player_id = 1,
        seq = 301,
        total_time = 0.25,
        lock_released = false,
        anim_ctx = {
          on_sequence_lock = function(enabled, _, meta)
            sequence_calls[#sequence_calls + 1] = tostring(enabled) .. ":" .. tostring(meta and meta.reason)
          end,
        },
      },
    },
  }
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

  _assert_eq(sequence_calls[1], "true:board_sync_place_players", "board sync clear should release the sequence lock")
  _assert_eq(sequence_calls[2], nil, "board sync clear should only release once")
  _assert_eq(env.state.board_scene._move_anim_runtime.active_token_by_player_id[1], nil,
    "board sync clear should remove the stale move token")
  _assert_eq(env.state.board_scene._move_anim_runtime.active_sequence_by_player_id[1], nil,
    "board sync clear should remove the stale sequence entry")
end

local function _test_board_refresh_synthetic_actor_stops_ai_before_snap()
  local board_view = require("src.presentation.view.render.board")
  local runtime_ports = require("src.core.ports.runtime_ports")
  local env = _build_board_refresh_test_env({ position = 2 })
  env.state.board_scene._move_anim_runtime = {
    active_token_by_player_id = {},
    active_sequence_by_player_id = {},
    pending_synthetic_ai_stop_by_player_id = {
      [1] = true,
    },
  }
  env.unit.stop_ai = function()
    env.calls[#env.calls + 1] = "stop_ai"
  end
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

  _with_board_refresh_patches({
    { target = runtime_ports, key = "resolve_role", value = function(player_id)
      if player_id == 1 then
        return { is_synthetic_actor = true }
      end
      return nil
    end },
  }, function()
    board_view.refresh(env.state, env.ui_model, function() end, function() return "presentation_board_sync" end)
  end)

  _assert_eq(env.calls[1], "stop_ai", "synthetic refresh should stop ai before motion stop")
  _assert_eq(env.calls[2], "force_stop_move", "synthetic refresh should still stop motion before snap")
  _assert_eq(env.calls[3], "stop_anim", "synthetic refresh should still stop anim before snap")
  _assert_eq(env.calls[4], "set_position", "synthetic refresh should snap after stopping ai and motion")
  _assert_eq(env.state.board_scene._move_anim_runtime.pending_synthetic_ai_stop_by_player_id[1], nil,
    "synthetic refresh should consume the pending board-sync ai stop marker")
end

local function _test_board_refresh_idle_synthetic_actor_skips_stop_ai()
  local board_view = require("src.presentation.view.render.board")
  local runtime_ports = require("src.core.ports.runtime_ports")
  local env = _build_board_refresh_test_env({ position = 2 })
  env.state.board_scene._move_anim_runtime = {
    active_token_by_player_id = {},
    active_sequence_by_player_id = {},
    pending_synthetic_ai_stop_by_player_id = {},
  }
  env.unit.stop_ai = function()
    env.calls[#env.calls + 1] = "stop_ai"
  end
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

  _with_board_refresh_patches({
    { target = runtime_ports, key = "resolve_role", value = function(player_id)
      if player_id == 1 then
        return { is_synthetic_actor = true }
      end
      return nil
    end },
  }, function()
    board_view.refresh(env.state, env.ui_model, function() end, function() return "presentation_board_sync" end)
  end)

  _assert_eq(env.calls[1], "force_stop_move", "idle synthetic refresh should skip stop_ai and stop motion first")
  _assert_eq(env.calls[2], "stop_anim", "idle synthetic refresh should still stop anim before snap")
  _assert_eq(env.calls[3], "set_position", "idle synthetic refresh should still snap to tile position")
  _assert_eq(env.calls[4], nil, "idle synthetic refresh should not call stop_ai")
end

local function _test_board_refresh_pending_synthetic_ai_stop_consumes_only_once()
  local board_view = require("src.presentation.view.render.board")
  local runtime_ports = require("src.core.ports.runtime_ports")
  local env = _build_board_refresh_test_env({ position = 2 })
  env.state.board_scene._move_anim_runtime = {
    active_token_by_player_id = {},
    active_sequence_by_player_id = {},
    pending_synthetic_ai_stop_by_player_id = {
      [1] = true,
    },
  }
  env.unit.stop_ai = function()
    env.calls[#env.calls + 1] = "stop_ai"
  end
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

  _with_board_refresh_patches({
    { target = runtime_ports, key = "resolve_role", value = function(player_id)
      if player_id == 1 then
        return { is_synthetic_actor = true }
      end
      return nil
    end },
  }, function()
    board_view.refresh(env.state, env.ui_model, function() end, function() return "presentation_board_sync" end)
    env.ui_model.board.vehicle_resync_seq = 1
    board_view.refresh(env.state, env.ui_model, function() end, function() return "presentation_board_sync" end)
  end)

  _assert_eq(env.calls[1], "stop_ai", "first refresh should consume pending synthetic ai stop")
  _assert_eq(env.calls[5], "force_stop_move", "second refresh should skip stop_ai and go straight to motion stop")
  _assert_eq(env.calls[6], "stop_anim", "second refresh should still stop anim")
  _assert_eq(env.calls[7], "set_position", "second refresh should still snap position")
  _assert_eq(env.calls[8], nil, "second refresh should not invoke stop_ai again")
end

local function _test_board_scene_init_binds_units_and_target_pick_metadata()
  local board_scene = require("src.presentation.view.render.board_scene")
  local runtime_ports = require("src.core.ports.runtime_ports")
  local state = {}
  local players = {
    { id = 1 },
    { id = 2 },
  }
  local queried = { units = {}, single = {} }

  local function new_unit(id)
    local unit = { _id = id }
    unit.set_physics_active = function(active)
      unit.physics_active = active
    end
    unit.get_child_by_name = function(_, _)
      return {
        set_billboard_text = function(_, text)
          queried.billboard_text = text
        end,
      }
    end
    unit.set_model_visible = function(visible)
      unit.model_visible = visible
    end
    return unit
  end

  _with_patches({
    {
      target = runtime_ports,
      key = "resolve_role",
      value = function(player_id)
        return {
          get_ctrl_unit = function()
            return { role_unit_id = player_id }
          end,
        }
      end,
    },
    {
      target = _G,
      key = "LuaAPI",
      value = {
        query_units = function(names)
          queried.units[#queried.units + 1] = names
          local out = {}
          for i = 1, #names do
            out[i] = new_unit(i)
          end
          return out
        end,
        query_unit = function(name)
          queried.single[#queried.single + 1] = name
          if name == "ground" then
            return new_unit(999)
          end
          return new_unit(name)
        end,
        get_unit_id = function(unit)
          return unit._id
        end,
      },
    },
  }, function()
    local scene = board_scene.init(state, { path = {} }, { players = players })
    _assert_eq(scene.units_by_player_id[1].role_unit_id, 1, "board_scene should bind player 1 unit")
    _assert_eq(scene.units_by_player_id[2].role_unit_id, 2, "board_scene should bind player 2 unit")
    _assert_eq(scene.target_pick.tile_index_by_unit_id[1], 1, "board_scene should map tile unit id to tile index")
    _assert_eq(scene.target_pick.marker_unit_id, "可选择地块", "board_scene should store marker unit id")
    assert(scene.target_pick.arrow_unit ~= nil, "board_scene should bind arrow unit")
    assert(scene.ground ~= nil, "board_scene should bind ground unit")
    assert(state.board_scene == scene, "board_scene init should persist scene on state")
  end)
end

local function _test_tile_renderer_renders_land_metadata()
  local tile_renderer = require("src.presentation.view.render.tile_renderer")
  local captured = {}
  local unit = {
    get_child_by_name = function(name)
      if name == "name" or name == "price" then
        return {
          set_billboard_text = function(text)
            captured[name] = text
          end,
        }
      end
      if name == "color" then
        return {
          set_paint_area_color = function(_, color)
            captured.color = color
          end,
        }
      end
      return nil
    end,
  }

  tile_renderer.render_tile(unit, 1, 2)

  assert(captured.name ~= nil, "tile renderer should render land name")
  assert(captured.price ~= nil, "tile renderer should render land price")
  assert(captured.color ~= nil, "tile renderer should render owner color")
end

local function _test_player_units_resolve_roles_by_name_and_role_id()
  local player_units = require("src.presentation.view.render.board.player_units")
  local resolved_role = {
    get_roleid = function()
      return 1
    end,
    get_name = function()
      return "P1"
    end,
    get_ctrl_unit = function()
      return { unit = "unit_1" }
    end,
  }
  local state = {}
  local players = {
    { id = 1, name = "P1" },
  }
  local log_calls = {}

  _with_patches({
    { target = require("src.core.ports.runtime_ports"), key = "resolve_roles", value = function()
      return { resolved_role }
    end },
  }, function()
    player_units.ensure_player_units(state, players, function(_, _, key)
      log_calls[#log_calls + 1] = key
    end, function()
      return "presentation_board_sync"
    end)
  end)

  _assert_eq(state.player_units[1] and state.player_units[1].unit, "unit_1",
    "player_units should map runtime unit by role id/name")
  _assert_eq(state.player_units_missing, false, "player_units should clear missing flag after mapping")
  _assert_eq(log_calls[1], "player_units_ready", "player_units should emit ready log once")
end

local function _test_player_units_falls_back_to_resolve_role_when_roles_list_missing()
  local player_units = require("src.presentation.view.render.board.player_units")
  local state = {}
  local players = {
    { id = 2, name = "P2" },
  }

  _with_patches({
    { target = require("src.core.ports.runtime_ports"), key = "resolve_roles", value = function()
      return {}
    end },
    { target = require("src.core.ports.runtime_ports"), key = "resolve_role", value = function(player_id)
      if player_id == 2 then
        return {
          get_roleid = function()
            return 2
          end,
          get_ctrl_unit = function()
            return { unit = "unit_2" }
          end,
        }
      end
      return nil
    end },
  }, function()
    player_units.ensure_player_units(state, players, function() end, function()
      return "presentation_board_sync"
    end)
  end)

  _assert_eq(state.player_units[2] and state.player_units[2].unit, "unit_2",
    "player_units should fall back to resolve_role when resolve_roles is empty")
end

local function _test_tile_anchors_collect_positions_render_tiles_and_spacing()
  local anchors = require("src.presentation.view.render.board.anchors")
  local render_calls = {}
  local log_calls = {}
  local state = {}
  local board = {
    tile_states = {
      land_a = { owner_id = "role_1" },
    },
    tiles = {
      { id = "land_a", type = "land" },
      { id = "chance_b", type = "chance" },
    },
  }
  local scene = {
    tiles = {
      [1] = {
        get_position = function()
          return { x = 0, y = 0, z = 0 }
        end,
      },
      [2] = {
        get_position = function()
          return { x = 10, y = 0, z = 0 }
        end,
      },
    },
  }

  _with_patches({
    {
      target = math,
      key = "Vector3",
      value = function(x, y, z)
        return vec3.with_sub_length(x, y, z)
      end,
    },
    {
      target = require("src.presentation.view.render.tile_renderer"),
      key = "render_tile",
      value = function(unit, tile_id, owner_id)
        render_calls[#render_calls + 1] = {
          unit = unit,
          tile_id = tile_id,
          owner_id = owner_id,
        }
      end,
    },
  }, function()
    anchors.ensure_tile_anchors(state, board, scene, 2, function(_, level, key, prefix, message, count)
      log_calls[#log_calls + 1] = { level = level, key = key, prefix = prefix, message = message, count = count }
    end, function()
      return "presentation_board_sync"
    end)
  end)

  _assert_eq(state.tile_units, scene.tiles, "ensure_tile_anchors should cache tile units")
  _assert_eq(state.tile_positions[1].x, 0, "ensure_tile_anchors should cache first tile position")
  _assert_eq(state.tile_positions[2].x, 10, "ensure_tile_anchors should cache second tile position")
  assert(math.abs(state.tile_spacing - 2.8) < 0.000001,
    "ensure_tile_anchors should derive tile spacing from neighboring tiles")
  _assert_eq(render_calls[1].tile_id, "land_a", "ensure_tile_anchors should render the first tile id")
  _assert_eq(render_calls[1].owner_id, "role_1", "ensure_tile_anchors should include land owner ids")
  _assert_eq(render_calls[2].tile_id, "chance_b", "ensure_tile_anchors should render non-land tiles too")
  _assert_eq(render_calls[2].owner_id, nil, "ensure_tile_anchors should omit owner ids for tiles without state")
  _assert_eq(log_calls[1].key, "tiles_ready", "ensure_tile_anchors should log the ready marker once")
end

local function _test_tile_anchors_return_early_when_cache_is_ready()
  local anchors = require("src.presentation.view.render.board.anchors")
  local render_calls = 0
  local log_calls = 0
  local state = {
    tile_positions = {
      { x = 1, y = 0, z = 0 },
      { x = 2, y = 0, z = 0 },
    },
  }
  local board = {
    tile_states = {},
    tiles = {
      { id = "a", type = "land" },
      { id = "b", type = "land" },
    },
  }
  local scene = {
    tiles = {
      [1] = { get_position = function() return { x = 0, y = 0, z = 0 } end },
      [2] = { get_position = function() return { x = 10, y = 0, z = 0 } end },
    },
  }

  _with_patches({
    {
      target = require("src.presentation.view.render.tile_renderer"),
      key = "render_tile",
      value = function()
        render_calls = render_calls + 1
      end,
    },
  }, function()
    anchors.ensure_tile_anchors(state, board, scene, 2, function()
      log_calls = log_calls + 1
    end, function()
      return "presentation_board_sync"
    end)
  end)

  _assert_eq(render_calls, 0, "ensure_tile_anchors should skip re-render when cached positions already cover tile count")
  _assert_eq(log_calls, 0, "ensure_tile_anchors should skip logging when cache is already ready")
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
      name = "_test_board_refresh_prefers_forced_move_stop_and_model_stop_before_set_position",
      run = _test_board_refresh_prefers_forced_move_stop_and_model_stop_before_set_position,
    },
    {
      name = "_test_board_refresh_stops_vehicle_before_vehicle_set_position",
      run = _test_board_refresh_stops_vehicle_before_vehicle_set_position,
    },
    {
      name = "_test_board_refresh_keeps_base_y_when_already_above_minimum",
      run = _test_board_refresh_keeps_base_y_when_already_above_minimum,
    },
    {
      name = "_test_board_refresh_suppresses_stop_and_snap_during_wait_move_anim",
      run = _test_board_refresh_suppresses_stop_and_snap_during_wait_move_anim,
    },
    {
      name = "_test_board_refresh_replays_pending_sync_with_stop_after_wait_move_anim",
      run = _test_board_refresh_replays_pending_sync_with_stop_after_wait_move_anim,
    },
    {
      name = "_test_board_refresh_clear_player_token_releases_sequence_lock",
      run = _test_board_refresh_clear_player_token_releases_sequence_lock,
    },
    {
      name = "_test_board_refresh_synthetic_actor_stops_ai_before_snap",
      run = _test_board_refresh_synthetic_actor_stops_ai_before_snap,
    },
    {
      name = "_test_board_refresh_idle_synthetic_actor_skips_stop_ai",
      run = _test_board_refresh_idle_synthetic_actor_skips_stop_ai,
    },
    {
      name = "_test_board_refresh_pending_synthetic_ai_stop_consumes_only_once",
      run = _test_board_refresh_pending_synthetic_ai_stop_consumes_only_once,
    },
    {
      name = "_test_board_scene_init_binds_units_and_target_pick_metadata",
      run = _test_board_scene_init_binds_units_and_target_pick_metadata,
    },
    {
      name = "_test_tile_renderer_renders_land_metadata",
      run = _test_tile_renderer_renders_land_metadata,
    },
    {
      name = "_test_player_units_resolve_roles_by_name_and_role_id",
      run = _test_player_units_resolve_roles_by_name_and_role_id,
    },
    {
      name = "_test_player_units_falls_back_to_resolve_role_when_roles_list_missing",
      run = _test_player_units_falls_back_to_resolve_role_when_roles_list_missing,
    },
    {
      name = "_test_tile_anchors_collect_positions_render_tiles_and_spacing",
      run = _test_tile_anchors_collect_positions_render_tiles_and_spacing,
    },
    {
      name = "_test_tile_anchors_return_early_when_cache_is_ready",
      run = _test_tile_anchors_return_early_when_cache_is_ready,
    },
  },
}
