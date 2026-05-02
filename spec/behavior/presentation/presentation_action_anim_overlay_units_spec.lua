local action_anim = require("src.ui.render.action_anim")
local host_runtime = require("src.host")
local overlay_compute = require("src.ui.render.anim.overlay_compute")
local visual_sync = require("src.ui.render.board.visual_sync")
local overlay_runtime = require("src.ui.render.anim.overlay_runtime")
local logger = require("src.foundation.log.logger")
local tip_queue = require("src.foundation.coordination.tip_queue")
local runtime_context = require("src.host.context")
local support = require("support.presentation_action_anim_support")

local _with_patches = support.with_patches

local function _drain_scheduled(queue, limit)
  local max_count = limit or math.huge
  local executed = 0
  while #queue > 0 and executed < max_count do
    local entry = table.remove(queue, 1)
    executed = executed + 1
    entry.callback()
  end
  return executed
end

local function _new_robot_handle(pos, records)
  local handle = {
    pos = pos,
    moves = {},
  }
  handle.set_position_smooth = function(next_pos)
    handle.pos = next_pos
    handle.moves[#handle.moves + 1] = next_pos
    records.moves[#records.moves + 1] = next_pos
  end
  handle.set_position = function(next_pos)
    handle.pos = next_pos
    handle.moves[#handle.moves + 1] = next_pos
    records.moves[#records.moves + 1] = next_pos
  end
  return handle
end







if not math.Vector3 then
  function math.Vector3(x, y, z)
    return { x = x, y = y, z = z }
  end
end

local function _with_overlay_patches(patches, fn)
  local function _refresh_runtime_ctx()
    local lua_api = {}
    if type(LuaAPI) == "table" then
      for key, value in pairs(LuaAPI) do
        lua_api[key] = value
      end
    end
    if type(SetTimeOut) == "function" then
      lua_api.call_delay_time = function(delay, cb)
        return SetTimeOut(delay, cb)
      end
    elseif type(lua_api.call_delay_time) ~= "function" then
      lua_api.call_delay_time = function(_, cb)
        if cb then
          cb()
          return true
        end
        return false
      end
    end
    runtime_context.set_current(runtime_context.new({
      GameAPI = GameAPI,
      LuaAPI = lua_api,
    }))
    tip_queue.configure_runtime({
      presenter = function(text, duration)
        if GlobalAPI and type(GlobalAPI.show_tips) == "function" then
          return GlobalAPI.show_tips(text, duration)
        end
        return false
      end,
      scheduler = function(delay, cb)
        return lua_api.call_delay_time(delay, cb)
      end,
      test_mode = logger.is_test_mode(),
    })
  end

  local originals = {}
  for i, patch in ipairs(patches) do
    local target = patch.target or _G
    originals[i] = { target = target, key = patch.key, value = target[patch.key] }
    target[patch.key] = patch.value
  end
  _refresh_runtime_ctx()
  local ok, err = xpcall(fn, debug.traceback)
  for i = #originals, 1, -1 do
    local patch = originals[i]
    patch.target[patch.key] = patch.value
  end
  _refresh_runtime_ctx()
  if not ok then
    error(err)
  end
end

local function _build_overlay_state()
  return {
    ui = {},
    board_scene = {
      tiles = {
        [1] = {
          get_position = function()
            return math.Vector3(0.0, 0.0, 0.0)
          end,
        },
      },
      buildings = {
        [1] = {
          get_position = function()
            return math.Vector3(10.0, 0.0, 0.0)
          end,
        },
      },
    },
    game = {
      board = {
        get_tile = function()
          return { name = "测试地块" }
        end,
      },
      find_player_by_id = function()
        return { position = 1, name = "测试玩家" }
      end,
    },
  }
end

local function _make_host_unit(x, y, z)
  if type(newproxy) == "function" then
    local unit = newproxy(true)
    getmetatable(unit).__index = {
      get_position = function()
        return math.Vector3(x, y, z)
      end,
    }
    return unit
  end
  return {
    get_position = function()
      return math.Vector3(x, y, z)
    end,
  }
end

describe("presentation.action_anim_overlay_units", function()
  it("action_anim_roadblock_overlay_uses_4x_scale", function()
    local state = support.build_min_state()
    local unit_calls = 0
    local group_calls = 0
    local captured_scale = nil

    _with_patches({
      {
        target = host_runtime,
        key = "create_unit_with_scale",
        value = function(_, _, _, scale)
          unit_calls = unit_calls + 1
          captured_scale = scale
          return { _unit_id = 1 }
        end,
      },
      {
        target = host_runtime,
        key = "create_unit_group",
        value = function()
          group_calls = group_calls + 1
          return { _group_id = 1 }
        end,
      },
    }, function()
      action_anim.play(state, { kind = "roadblock", tile_index = 1, duration = 0.2 })
    end)

    assert(unit_calls == 1, "roadblock should spawn via unit path")
    assert(group_calls == 0, "roadblock should not spawn via group path")
    assert(captured_scale ~= nil, "roadblock should pass explicit scale")
    assert(captured_scale.x == 4.0 and captured_scale.y == 4.0 and captured_scale.z == 4.0, "roadblock should use 4x scale")
  end)

  it("action_anim_robot_overlay_uses_robot_scale_not_v3_one", function()
    local overlay = require("src.ui.render.anim.unit_overlay")
    local state = support.build_min_state({
      mutate = function(target)
        target.board_scene.tiles[2] = {
          get_position = function()
            return math.Vector3(10.0, 0.0, 0.0)
          end,
        }
        target.board_scene.tiles[3] = {
          get_position = function()
            return math.Vector3(20.0, 0.0, 0.0)
          end,
        }
        target.board_scene.tiles[4] = {
          get_position = function()
            return math.Vector3(20.0, 10.0, 0.0)
          end,
        }
      end,
    })
    local captured_scales = {}
    local scheduled_callbacks = {}

    _with_patches({
      {
        target = host_runtime,
        key = "create_unit_with_scale",
        value = function(_, pos, _, scale)
          captured_scales[#captured_scales + 1] = scale
          local records = { spawn_pos = pos, moves = {} }
          return _new_robot_handle(pos, records)
        end,
      },
      {
        target = host_runtime,
        key = "schedule",
        value = function(delay, callback)
          scheduled_callbacks[#scheduled_callbacks + 1] = {
            delay = delay,
            callback = callback,
          }
        end,
      },
      {
        target = host_runtime,
        key = "destroy_unit",
        value = function() end,
      },
    }, function()
      overlay.play_clear_obstacles(state, {
        branches = {
          {
            { tile_index = 2, has_obstacle = false },
            { tile_index = 3, has_obstacle = true },
          },
          {
            { tile_index = 2, has_obstacle = false },
            { tile_index = 4, has_obstacle = true },
          },
        },
        player_id = 1,
        duration = 0.4,
      }, 0.4, {
        clear_overlay = function() end,
      })
      _drain_scheduled(scheduled_callbacks)
    end)

    assert(#captured_scales >= 2, "root and fork robot should both be spawned via create_unit_with_scale")
    for i, scale in ipairs(captured_scales) do
      assert(
        not (scale.x == 1.0 and scale.y == 1.0 and scale.z == 1.0),
        "robot scale must not be v3_one (1,1,1) — regression guard for spawn #" .. i
      )
      assert(
        scale.x == 0.86 and scale.y == 0.30 and scale.z == 0.17,
        "robot scale must match robot_scale constant (0.86,0.30,0.17) for spawn #" .. i
      )
    end
  end)

  it("anim_unit_overlay_clear_obstacles_walks_per_step_then_clears_and_destroys", function()
    local overlay = require("src.ui.render.anim.unit_overlay")
    local state = support.build_min_state({
      mutate = function(target)
        target.board_scene.tiles[2] = {
          get_position = function()
            return math.Vector3(10.0, 0.0, 0.0)
          end,
        }
        target.board_scene.tiles[3] = {
          get_position = function()
            return math.Vector3(20.0, 0.0, 0.0)
          end,
        }
        target.board_scene.tiles[4] = {
          get_position = function()
            return math.Vector3(30.0, 0.0, 0.0)
          end,
        }
      end,
    })
    local cleared_calls = {}
    local unit_calls = {}
    local scheduled_callbacks = {}
    local destroyed_handles = {}
    local robot_records = {}

    _with_patches({
      {
        target = host_runtime,
        key = "create_unit_with_scale",
        value = function(unit_id, pos)
          local records = { spawn_pos = pos, moves = {} }
          local handle = _new_robot_handle(pos, records)
          robot_records[#robot_records + 1] = records
          unit_calls[#unit_calls + 1] = {
            unit_id = unit_id,
            pos = pos,
            handle = handle,
          }
          return handle
        end,
      },
      {
        target = host_runtime,
        key = "schedule",
        value = function(delay, callback)
          scheduled_callbacks[#scheduled_callbacks + 1] = {
            delay = delay,
            callback = callback,
          }
        end,
      },
        {
          target = host_runtime,
          key = "destroy_unit",
          value = function(handle)
            destroyed_handles[#destroyed_handles + 1] = handle
          end,
      },
    }, function()
      overlay.play_clear_obstacles(state, {
        branches = {
          {
            { tile_index = 2, has_obstacle = true },
            { tile_index = 3, has_obstacle = false },
            { tile_index = 4, has_obstacle = true },
          },
        },
        player_id = 1,
        duration = 0.6,
      }, 0.6, {
        clear_overlay = function(_, kind, tile_index)
          cleared_calls[#cleared_calls + 1] = kind .. ":" .. tostring(tile_index)
        end,
      })
      assert(#unit_calls == 1, "single branch should create exactly one robot")
      assert(unit_calls[1].pos.x == 0.0 and unit_calls[1].pos.y == 1.0 and unit_calls[1].pos.z == 0.0,
        "clear_obstacles robot unit should spawn above the acting player tile")
      assert(#scheduled_callbacks == 1 and math.abs(scheduled_callbacks[1].delay - 0.2) < 0.0001,
        "single branch should schedule the first move using duration / path_len")
      assert(#cleared_calls == 0, "single branch should not clear overlays before the first arrival")

      _drain_scheduled(scheduled_callbacks)
    end)

    assert(#cleared_calls == 4, "single branch should clear roadblock and mine only on obstacle tiles after arrival")
    assert(cleared_calls[1] == "roadblock:2", "clear_obstacles should clear roadblock for tile 2 (has_obstacle=true)")
    assert(cleared_calls[2] == "mine:2", "clear_obstacles should clear mine for tile 2")
    assert(cleared_calls[3] == "roadblock:4", "clear_obstacles should clear roadblock for tile 4 (has_obstacle=true)")
    assert(cleared_calls[4] == "mine:4", "clear_obstacles should clear mine for tile 4")
    assert(#destroyed_handles == 1, "single branch robot should be destroyed after finishing the path")
    assert(#robot_records[1].moves == 3, "single branch robot should move once per tile in the branch")
  end)

  it("anim_unit_overlay_clear_obstacles_splits_at_fork_and_destroys_all_robots", function()
    local overlay = require("src.ui.render.anim.unit_overlay")
    local state = support.build_min_state({
      mutate = function(target)
        target.board_scene.tiles[2] = {
          get_position = function()
            return math.Vector3(10.0, 0.0, 0.0)
          end,
        }
        target.board_scene.tiles[3] = {
          get_position = function()
            return math.Vector3(20.0, 0.0, 0.0)
          end,
        }
        target.board_scene.tiles[4] = {
          get_position = function()
            return math.Vector3(20.0, 10.0, 0.0)
          end,
        }
        target.board_scene.tiles[5] = {
          get_position = function()
            return math.Vector3(30.0, 0.0, 0.0)
          end,
        }
        target.board_scene.tiles[6] = {
          get_position = function()
            return math.Vector3(30.0, 10.0, 0.0)
          end,
        }
      end,
    })
    local cleared_calls = {}
    local unit_calls = {}
    local scheduled_callbacks = {}
    local destroyed_handles = {}
    local robot_records = {}

    _with_patches({
      {
        target = host_runtime,
        key = "create_unit_with_scale",
        value = function(unit_id, pos)
          local records = { spawn_pos = pos, moves = {} }
          local handle = _new_robot_handle(pos, records)
          robot_records[#robot_records + 1] = records
          unit_calls[#unit_calls + 1] = {
            unit_id = unit_id,
            pos = pos,
            handle = handle,
          }
          return handle
        end,
      },
      {
        target = host_runtime,
        key = "schedule",
        value = function(delay, callback)
          scheduled_callbacks[#scheduled_callbacks + 1] = {
            delay = delay,
            callback = callback,
          }
        end,
      },
        {
          target = host_runtime,
          key = "destroy_unit",
          value = function(handle)
            destroyed_handles[#destroyed_handles + 1] = handle
          end,
      },
    }, function()
      overlay.play_clear_obstacles(state, {
        branches = {
          {
            { tile_index = 2, has_obstacle = false },
            { tile_index = 3, has_obstacle = true },
            { tile_index = 5, has_obstacle = false },
          },
          {
            { tile_index = 2, has_obstacle = false },
            { tile_index = 4, has_obstacle = true },
            { tile_index = 6, has_obstacle = false },
          },
        },
        player_id = 1,
        duration = 0.6,
      }, 0.6, {
        clear_overlay = function(_, kind, tile_index)
          cleared_calls[#cleared_calls + 1] = kind .. ":" .. tostring(tile_index)
        end,
      })
      assert(#unit_calls == 1, "merged branches should start with one robot before the fork")
      assert(#scheduled_callbacks == 1 and math.abs(scheduled_callbacks[1].delay - 0.2) < 0.0001,
        "first step should be scheduled with duration / longest_branch_len")
      assert(#cleared_calls == 0, "overlays should not clear before robot reaches obstacle tiles")

      _drain_scheduled(scheduled_callbacks, 1)

      assert(#unit_calls == 2, "robot should split only after reaching the fork tile")
      assert(unit_calls[2].pos.x == 10.0 and unit_calls[2].pos.y == 1.0 and unit_calls[2].pos.z == 0.0,
        "forked robot should spawn at the fork position instead of the player start")

      _drain_scheduled(scheduled_callbacks)
    end)

    assert(#cleared_calls == 4, "forked branches should clear only obstacle tiles across both branches")
    assert(cleared_calls[1] == "roadblock:3", "first branch should clear roadblock on tile 3 after the split")
    assert(cleared_calls[2] == "mine:3", "first branch should clear mine on tile 3 after the split")
    assert(cleared_calls[3] == "roadblock:4", "second branch should clear roadblock on tile 4 after the split")
    assert(cleared_calls[4] == "mine:4", "second branch should clear mine on tile 4 after the split")
    assert(#destroyed_handles == 2, "every spawned robot should be destroyed after reaching its leaf")
    assert(#robot_records[1].moves == 3, "primary robot should walk fork -> branch -> leaf")
    assert(#robot_records[2].moves == 2, "forked robot should continue from split point to its leaf")
  end)

  it("anim_unit_overlay_play_missile_clears_overlays_and_spawns_transient", function()
    local overlay = require("src.ui.render.anim.unit_overlay")
    local prefab = require("Data.Prefab")
    local state = support.build_min_state()
    local cleared_calls = {}
    local transient_calls = {}

    state.presentation_runtime = {
      host_runtime = {
        create_unit_group = function(group_id, pos)
          transient_calls[#transient_calls + 1] = {
            group_id = group_id,
            pos = pos,
          }
          return { _group_id = group_id }
        end,
        create_unit = function(unit_id, pos)
          transient_calls[#transient_calls + 1] = {
            unit_id = unit_id,
            pos = pos,
          }
          return { _unit_id = unit_id }
        end,
        schedule = function() end,
      },
    }

    local original_group = prefab.group["导弹"]
    prefab.group["导弹"] = 9999

    _with_patches({
      {
        target = host_runtime,
        key = "create_unit_group",
        value = function(group_id, pos)
          transient_calls[#transient_calls + 1] = {
            group_id = group_id,
            pos = pos,
          }
          return { _group_id = group_id }
        end,
      },
      {
        target = host_runtime,
        key = "create_unit",
        value = function(unit_id, pos)
          transient_calls[#transient_calls + 1] = {
            unit_id = unit_id,
            pos = pos,
          }
          return { _unit_id = unit_id }
        end,
      },
    }, function()
      overlay.play_missile(state, {
        tile_index = 1,
      }, 0.5, {
        clear_overlay = function(_, kind, tile_index)
          cleared_calls[#cleared_calls + 1] = kind .. ":" .. tostring(tile_index)
        end,
      })
    end)

    prefab.group["导弹"] = original_group

    assert(#cleared_calls == 2, "play_missile should clear roadblock and mine")
    assert(cleared_calls[1] == "roadblock:1", "play_missile should clear roadblock first")
    assert(cleared_calls[2] == "mine:1", "play_missile should clear mine second")
    assert(#transient_calls >= 1, "play_missile should spawn at least one transient")
  end)

  it("anim_units_play_missile_stops_and_snaps_targets_before_followup", function()
    local units = require("src.ui.render.anim.units")
    local calls = {}
    local state = support.build_min_state({
      mutate = function(target)
        target.board_scene.units_by_player_id = {
          [2] = {
            get_position = function()
              return math.Vector3(0.0, 0.0, 0.0)
            end,
          },
        }
        target.board_scene.tiles[3] = {
          get_position = function()
            return math.Vector3(30.0, 0.0, 0.0)
          end,
        }
      end,
    })

    _with_patches({
      {
        target = require("src.ui.render.move_anim"),
        key = "prepare_player_for_snap",
        value = function(_, player_id, _anim, reason)
          calls[#calls + 1] = "prepare:" .. tostring(player_id) .. ":" .. tostring(reason)
        end,
      },
      {
        target = require("src.ui.render.move_anim"),
        key = "snap_player_to_index",
        value = function(_, player_id, to_index, _anim, reason)
          calls[#calls + 1] = "snap:" .. tostring(player_id) .. ":" .. tostring(to_index) .. ":" .. tostring(reason)
          return 0
        end,
      },
      {
        target = require("src.ui.render.anim.unit_overlay"),
        key = "play_missile",
        value = function()
          calls[#calls + 1] = "overlay"
        end,
      },
    }, function()
      units.play_missile(state, {
        tile_index = 1,
        target_player_ids = { 2 },
        to_index = 3,
      }, 0.5, {
        clear_overlay = function() end,
      })
    end)

    assert(calls[1] == "prepare:2:missile", "missile should stop targets before overlay playback")
    assert(calls[2] == "overlay", "missile should play strike overlay after stop phase")
    assert(calls[3] == "snap:2:3:play_sequence_missile_target", "missile should snap targets after strike overlay starts")
  end)

  it("overlay_compute_reads_host_unit_position_without_table_guard", function()
    local state = _build_overlay_state()
    state.board_scene.tiles[1] = _make_host_unit(5.0, 6.0, 7.0)

    local pos = overlay_compute.overlay_pos_for_tile(state, 1)
    assert(pos.x == 5.0, "overlay compute should preserve host unit x")
    assert(pos.y == 7.0, "overlay compute should add y offset on host unit position")
    assert(pos.z == 7.0, "overlay compute should preserve host unit z")
  end)

  it("visual_sync_overlay_uses_host_unit_position", function()
    local state = _build_overlay_state()
    state.board_scene.tiles[1] = _make_host_unit(12.0, 3.0, 4.0)
    state.game.board = {
      has_roadblock = function()
        return false
      end,
      has_mine = function()
        return true
      end,
    }
    local spawn_calls = {}

    _with_overlay_patches({
      {
        target = overlay_runtime,
        key = "spawn_overlay",
        value = function(scene, kind, tile_index, group_id, unit_id, pos)
          spawn_calls[#spawn_calls + 1] = {
            kind = kind,
            tile_index = tile_index,
            pos = pos,
          }
          return true
        end,
      },
    }, function()
      local handled = visual_sync.sync_overlay_visual(state, 1)
      assert(handled == true, "visual sync should handle mine overlay")
    end)

    assert(#spawn_calls == 1, "visual sync should spawn one mine overlay")
    assert(spawn_calls[1].kind == "mine", "visual sync should spawn mine overlay")
    assert(spawn_calls[1].pos.x == 12.0, "visual sync should pass host unit x")
    assert(spawn_calls[1].pos.y == 4.0, "visual sync should add overlay y offset")
    assert(spawn_calls[1].pos.z == 4.0, "visual sync should pass host unit z")
  end)

  it("overlay_runtime_spawn_transient_schedules_destroy_for_groups", function()
    local calls = {
      create_group = 0,
      destroy = 0,
      scheduled = 0,
    }

    _with_overlay_patches({
      {
        target = host_runtime,
        key = "create_unit_group",
        value = function(group_id, pos)
          calls.create_group = calls.create_group + 1
          return { id = group_id, pos = pos }
        end,
      },
      {
        target = host_runtime,
        key = "destroy_unit_with_children",
        value = function()
          calls.destroy = calls.destroy + 1
        end,
      },
      {
        target = host_runtime,
        key = "schedule",
        value = function(delay, fn)
          calls.scheduled = delay
          fn()
        end,
      },
    }, function()
      overlay_runtime.spawn_transient(2001, nil, math.Vector3(1, 2, 3), 0.5, {
        host_runtime = host_runtime,
      })
    end)

    assert(calls.create_group == 1, "spawn_transient should create one transient group")
    assert(calls.scheduled == 0.5, "spawn_transient should schedule delayed cleanup")
    assert(calls.destroy == 1, "spawn_transient should destroy transient group after delay")
  end)
end)
