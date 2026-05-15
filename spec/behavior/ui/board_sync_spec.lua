local support = require("spec.support.ui_support")
local _assert_eq = support.assert_eq
local _with_patches = support.with_patches
local board_geometry = require("src.config.gameplay.camera_follow")
local runtime_state = require("src.state.runtime")
local vec3 = require("spec.fixtures.vec3")

if not math.Vector3 then
  function math.Vector3(x, y, z)
    return { x = x, y = y, z = z }
  end
end

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
  local anchors = require("src.ui.render.board.anchors")
  local startup_render = require("src.ui.render.board.startup_render")
  local player_units = require("src.ui.render.board.player_units")
  local board_cfg = {
    player_min_ground_offset = board_geometry.player_min_ground_offset,
  }
  local patches = {
    { target = anchors, key = "ensure_tile_anchors", value = function() end },
    { target = startup_render, key = "apply", value = function() end },
    { target = player_units, key = "ensure_player_units", value = function() end },
    { target = board_geometry, key = "player_min_ground_offset", value = 0.5 },
  }
  if type(extra_patches) == "table" then
    for _, patch in ipairs(extra_patches) do
      patches[#patches + 1] = patch
    end
  end
  _with_patches(patches, function()
    fn()
    board_geometry.player_min_ground_offset = board_cfg.player_min_ground_offset
  end)
end

describe("presentation.board_sync", function()
  it("_test_board_refresh_stops_force_move_before_set_position", function()
    local board_view = require("src.ui.render.board")
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
  end)

  it("_test_board_refresh_updates_follow_target_on_snap", function()
    local board_view = require("src.ui.render.board")
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

    local follow_target = runtime_state.get_follow_target_position(env.state, 1)
    assert(follow_target ~= nil, "refresh should publish follow target position on snap")
    _assert_eq(follow_target.x, 10, "follow target should snap to tile x")
    _assert_eq(follow_target.y, 0.5, "follow target should use configured minimum y")
    _assert_eq(follow_target.z, 20, "follow target should snap to tile z")
  end)

  it("_test_board_refresh_falls_back_to_ai_stop_before_set_position", function()
    local board_view = require("src.ui.render.board")
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
  end)

  it("_test_board_refresh_prefers_forced_move_stop_and_model_stop_before_set_position", function()
    local board_view = require("src.ui.render.board")
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
  end)

  it("_test_board_refresh_keeps_base_y_when_already_above_minimum", function()
    local board_view = require("src.ui.render.board")
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
  end)

  it("_test_board_refresh_suppresses_stop_and_snap_during_wait_move_anim", function()
    local board_view = require("src.ui.render.board")
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
  end)

  it("_test_board_refresh_replays_pending_sync_with_stop_after_wait_move_anim", function()
    local board_view = require("src.ui.render.board")
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
  end)

  it("_test_board_refresh_clear_player_token_releases_sequence_lock", function()
    local board_view = require("src.ui.render.board")
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
  end)

  it("_test_board_refresh_synthetic_actor_stops_force_move_before_snap", function()
    local board_view = require("src.ui.render.board")
    local runtime_ports = require("src.foundation.ports.runtime_ports")
    local env = _build_board_refresh_test_env({ position = 2 })
    env.state.board_scene._move_anim_runtime = {
      active_token_by_player_id = {},
      active_sequence_by_player_id = {},
    }
    env.unit.force_stop_move = function()
      env.calls[#env.calls + 1] = "force_stop_move"
    end
    env.unit.ai_command_stop_move = function()
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
      { target = runtime_ports, key = "resolve_role", value = function(player_id)
        if player_id == 1 then
          return { is_synthetic_actor = true }
        end
        return nil
      end },
    }, function()
      board_view.refresh(env.state, env.ui_model, function() end, function() return "presentation_board_sync" end)
    end)

    _assert_eq(env.calls[1], "force_stop_move", "synthetic refresh should stop motion before snap")
    _assert_eq(env.calls[2], "ai_command_stop_move", "synthetic refresh should also reset ai movement before snap")
    _assert_eq(env.calls[3], "stop_anim", "synthetic refresh should still stop anim before snap")
    _assert_eq(env.calls[4], "set_position", "synthetic refresh should snap after stopping motion")
  end)

  it("_test_board_refresh_synthetic_actor_matches_regular_stop_flow", function()
    local board_view = require("src.ui.render.board")
    local runtime_ports = require("src.foundation.ports.runtime_ports")
    local env = _build_board_refresh_test_env({ position = 2 })
    env.state.board_scene._move_anim_runtime = {
      active_token_by_player_id = {},
      active_sequence_by_player_id = {},
    }
    env.unit.force_stop_move = function()
      env.calls[#env.calls + 1] = "force_stop_move"
    end
    env.unit.ai_command_stop_move = function()
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
      { target = runtime_ports, key = "resolve_role", value = function(player_id)
        if player_id == 1 then
          return { is_synthetic_actor = true }
        end
        return nil
      end },
    }, function()
      board_view.refresh(env.state, env.ui_model, function() end, function() return "presentation_board_sync" end)
    end)

    _assert_eq(env.calls[1], "force_stop_move", "synthetic refresh should stop motion first")
    _assert_eq(env.calls[2], "ai_command_stop_move", "synthetic refresh should also reset ai movement before snap")
    _assert_eq(env.calls[3], "stop_anim", "synthetic refresh should still stop anim before snap")
    _assert_eq(env.calls[4], "set_position", "synthetic refresh should still snap to tile position")
    _assert_eq(env.calls[5], nil, "synthetic refresh should not add extra stop calls")
  end)

  it("_test_board_refresh_replays_pending_sync_with_synthetic_ai_stop_before_snap", function()
    local board_view = require("src.ui.render.board")
    local runtime_ports = require("src.foundation.ports.runtime_ports")
    local env = _build_board_refresh_test_env({
      phase = "wait_move_anim",
      move_anim = { seq = 1 },
      position = 2,
    })
    env.state.board_scene._move_anim_runtime = {
      active_token_by_player_id = {
        [1] = "1:1",
      },
    }
    env.unit.force_stop_move = function()
      env.calls[#env.calls + 1] = "force_stop_move"
    end
    env.unit.ai_command_stop_move = function()
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
      { target = runtime_ports, key = "resolve_role", value = function(player_id)
        if player_id == 1 then
          return { is_synthetic_actor = true }
        end
        return nil
      end },
    }, function()
      board_view.refresh(env.state, env.ui_model, function() end, function() return "presentation_board_sync" end)
      _assert_eq(#env.calls, 0, "suppressed refresh should not stop or snap synthetic actor")
      env.ui_model.board.phase = "start"
      env.ui_model.board.move_anim = nil
      board_view.refresh(env.state, env.ui_model, function() end, function() return "presentation_board_sync" end)
    end)

    _assert_eq(env.calls[1], "force_stop_move", "synthetic pending sync should stop force move first")
    _assert_eq(env.calls[2], "ai_command_stop_move", "synthetic pending sync should reset ai movement before snap")
    _assert_eq(env.calls[3], "stop_anim", "synthetic pending sync should stop anim before snap")
    _assert_eq(env.calls[4], "set_position", "synthetic pending sync should snap after synthetic stop")
    _assert_eq(env.target_pos.x, 20, "synthetic pending sync should snap to the current tile x")
    _assert_eq(env.target_pos.z, 30, "synthetic pending sync should snap to the current tile z")
  end)

  it("_test_board_scene_init_binds_units", function()
    local board_scene = require("src.ui.render.board.scene")
    local runtime_ports = require("src.foundation.ports.runtime_ports")
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
      assert(scene.ground ~= nil, "board_scene should bind ground unit")
      assert(state.board_scene == scene, "board_scene init should persist scene on state")
    end)
  end)

  it("_test_tile_renderer_renders_land_metadata", function()
    local tile_renderer = require("src.ui.render.tile")
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
  end)

  it("_test_player_units_resolve_roles_by_name_and_role_id", function()
    local player_units = require("src.ui.render.board.player_units")
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
      { target = require("src.foundation.ports.runtime_ports"), key = "resolve_roles", value = function()
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
  end)

  it("_test_player_units_falls_back_to_resolve_role_when_roles_list_missing", function()
    local player_units = require("src.ui.render.board.player_units")
    local state = {}
    local players = {
      { id = 2, name = "P2" },
    }

    _with_patches({
      { target = require("src.foundation.ports.runtime_ports"), key = "resolve_roles", value = function()
        return {}
      end },
      { target = require("src.foundation.ports.runtime_ports"), key = "resolve_role", value = function(player_id)
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
  end)

  it("_test_tile_anchors_collect_positions_render_tiles_and_spacing", function()
    local anchors = require("src.ui.render.board.anchors")
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
        target = require("src.ui.render.tile"),
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
  end)

  it("_test_tile_anchors_return_early_when_cache_is_ready", function()
    local anchors = require("src.ui.render.board.anchors")
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
        target = require("src.ui.render.tile"),
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
  end)

  it("_test_building_effects_require_does_not_need_host_vector3", function()
    local module_name = "src.ui.render.building_effects"
    local original_vector3 = math.Vector3
    local original_loaded = package.loaded[module_name]
    math.Vector3 = nil
    package.loaded[module_name] = nil

    local ok, loaded_or_err = pcall(require, module_name)

    package.loaded[module_name] = original_loaded
    math.Vector3 = original_vector3
    assert(ok, "building_effects require should not call math.Vector3: " .. tostring(loaded_or_err))
    _assert_eq(type(loaded_or_err.spawn_upgrade_building_units), "function",
      "building_effects should load its public API without host Vector3")
  end)

  it("_test_building_effects_spawn_upgrade_building_units_creates_group_and_updates_billboard", function()
    local building_effects = require("src.ui.render.building_effects")

    local billboard_calls = {}
    local created_units = {}

    local txt_mock = {
      set_billboard_text = function(text)
        billboard_calls[#billboard_calls + 1] = text
      end,
    }

    local scene = {
      buildings = {
        [1] = {
          get_position = function()
            return vec3.with_add(10.0, 0.0, 20.0)
          end,
        },
      },
      building_unit_groups = {},
      building_txt = {
        [1] = txt_mock,
      },
      presentation_runtime = {
        host_runtime = {
          destroy_unit_with_children = function() end,
          create_unit_group = function(group_id, pos, rot)
            created_units[#created_units + 1] = {
              group_id = group_id,
              pos = pos,
              rot = rot,
            }
            return { _group_id = group_id }
          end,
        },
      },
    }

    local result = building_effects.spawn_upgrade_building_units(scene, vec3.with_add(0.0, 0.0, 0.0), 1, 1, scene.presentation_runtime)

    _assert_eq(result, true, "spawn_upgrade_building_units should return true on success")
    _assert_eq(scene.building_unit_groups[1] ~= nil, true, "spawn_upgrade_building_units should store created unit")
    _assert_eq(billboard_calls[#billboard_calls], "一级建筑", "spawn_upgrade_building_units should set billboard text to building level")
  end)

  it("_test_building_effects_spawn_upgrade_returns_false_when_building_missing", function()
    local building_effects = require("src.ui.render.building_effects")

    local scene = {
      buildings = {
        [1] = nil,
      },
      building_unit_groups = {},
      presentation_runtime = {
        host_runtime = {
          destroy_unit_with_children = function() end,
          create_unit_group = function() return {} end,
        },
      },
    }

    local result = building_effects.spawn_upgrade_building_units(scene, math.Vector3(0.0, 0.0, 0.0), 1, 1, scene.presentation_runtime)

    _assert_eq(result, false, "spawn_upgrade_building_units should return false when building is nil")
  end)

  it("_test_building_effects_spawn_upgrade_returns_false_when_prefab_missing", function()
    local building_effects = require("src.ui.render.building_effects")
    local prefab = require("Data.Prefab")

    local scene = {
      buildings = {
        [1] = {
          get_position = function()
            return math.Vector3(10.0, 0.0, 20.0)
          end,
        },
      },
      building_unit_groups = {},
      presentation_runtime = {
        host_runtime = {
          destroy_unit_with_children = function() end,
          create_unit_group = function() return {} end,
        },
      },
    }

    local original_group = prefab.group["一级建筑"]
    prefab.group["一级建筑"] = nil

    local result = building_effects.spawn_upgrade_building_units(scene, math.Vector3(0.0, 0.0, 0.0), 1, 1, scene.presentation_runtime)

    prefab.group["一级建筑"] = original_group

    _assert_eq(result, false, "spawn_upgrade_building_units should return false when prefab group is missing")
  end)

  it("_test_building_effects_spawn_upgrade_returns_false_when_create_fails", function()
    local building_effects = require("src.ui.render.building_effects")

    local scene = {
      buildings = {
        [1] = {
          get_position = function()
            return vec3.with_add(10.0, 0.0, 20.0)
          end,
        },
      },
      building_unit_groups = {},
      presentation_runtime = {
        host_runtime = {
          destroy_unit_with_children = function() end,
          create_unit_group = function() return nil end,
        },
      },
    }

    local result = building_effects.spawn_upgrade_building_units(scene, vec3.with_add(0.0, 0.0, 0.0), 1, 1, scene.presentation_runtime)

    _assert_eq(result, false, "spawn_upgrade_building_units should return false when create_unit_group returns nil")
  end)

  it("_test_board_refresh_hides_eliminated_player_unit", function()
    local board_view = require("src.ui.render.board")
    local runtime_constants = require("src.config.gameplay.runtime_constants")
    local p1_calls = {}
    local p2_calls = {}
    local p1_unit = {
      force_stop_move = function() p1_calls[#p1_calls + 1] = "force_stop_move" end,
      stop_anim = function() p1_calls[#p1_calls + 1] = "stop_anim" end,
      set_position = function() p1_calls[#p1_calls + 1] = "set_position" end,
    }
    local p2_park_pos = nil
    local p2_unit = {
      force_stop_move = function() p2_calls[#p2_calls + 1] = "force_stop_move" end,
      stop_anim = function() p2_calls[#p2_calls + 1] = "stop_anim" end,
      set_position = function(pos) p2_calls[#p2_calls + 1] = "set_position"; p2_park_pos = pos end,
      set_model_visible = function(v) p2_calls[#p2_calls + 1] = "set_model_visible:" .. tostring(v) end,
    }
    local state = {
      board_scene = {
        ground = { get_position = function() return { y = 0 } end },
      },
      tile_positions = {
        [1] = vec3.with_add(10, 0, 20),
        [2] = vec3.with_add(20, 0, 30),
      },
      tile_spacing = 0,
      player_units = { [1] = p1_unit, [2] = p2_unit },
      _log_once = {},
    }
    local ui_model = {
      board = {
        phase = "start",
        tile_count = 2,
        tiles = { { id = 1 }, { id = 2 } },
        players = {
          { id = 1, name = "P1", position = 1, eliminated = false },
          { id = 2, name = "P2", position = 2, eliminated = true },
        },
      },
    }

    _with_board_refresh_patches(nil, function()
      board_view.refresh(state, ui_model, function() end, function() return "board_sync_eliminated" end)
    end)

    assert(#p1_calls > 0, "non-eliminated player should be placed normally")
    local found_hide = false
    local found_park = false
    for _, call in ipairs(p2_calls) do
      if call == "set_model_visible:false" then found_hide = true end
      if call == "set_position" then found_park = true end
    end
    assert(found_hide, "eliminated player unit should have set_model_visible(false) called")
    assert(found_park, "eliminated player unit should be parked offscreen")
    local park = runtime_constants.entity_pool_park_pos
    _assert_eq(p2_park_pos.y, park.y, "eliminated player should be parked at entity_pool_park_pos.y")
  end)
end)
