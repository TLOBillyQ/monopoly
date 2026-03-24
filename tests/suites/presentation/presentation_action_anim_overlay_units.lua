local action_anim = require("src.ui.render.action_anim")
local host_runtime = require("src.host.eggy")
local support = require("support.presentation_action_anim_support")

local _with_patches = support.with_patches

local function _test_action_anim_roadblock_overlay_uses_4x_scale()
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
end

local function _test_anim_unit_overlay_clear_obstacles_multi_branch_creates_multiple_robot_groups()
  local overlay = require("src.ui.render.anim_unit_overlay")
  local state = support.build_min_state()
  local cleared_calls = {}
  local group_calls = {}
  local scheduled_callbacks = {}

  _with_patches({
    {
      target = host_runtime,
      key = "create_unit_group",
      value = function(group_id, pos)
        group_calls[#group_calls + 1] = {
          group_id = group_id,
          pos = pos,
        }
        return { _group_id = group_id }
      end,
    },
    {
      target = host_runtime,
      key = "schedule",
      value = function(callback)
        scheduled_callbacks[#scheduled_callbacks + 1] = callback
      end,
    },
  }, function()
    overlay.play_clear_obstacles(state, {
      branches = {
        {
          { tile_index = 2, has_obstacle = true },
          { tile_index = 3, has_obstacle = false },
          { tile_index = 5, has_obstacle = false },
        },
        {
          { tile_index = 6, has_obstacle = false },
          { tile_index = 7, has_obstacle = true },
          { tile_index = 8, has_obstacle = false },
        },
      },
      player_id = 1,
      duration = 0.5,
    }, 0.5, {
      clear_overlay = function(_, kind, tile_index)
        cleared_calls[#cleared_calls + 1] = kind .. ":" .. tostring(tile_index)
      end,
    })
  end)

  assert(#group_calls == 2, "clear_obstacles with 2 branches should create 2 robot unit groups")
  assert(#cleared_calls == 4, "clear_obstacles should clear obstacles from branch 1 (tile 2) and branch 2 (tile 7)")
  assert(cleared_calls[1] == "roadblock:2", "should clear roadblock from branch 1, tile 2")
  assert(cleared_calls[2] == "mine:2", "should clear mine from branch 1, tile 2")
  assert(cleared_calls[3] == "roadblock:7", "should clear roadblock from branch 2, tile 7")
  assert(cleared_calls[4] == "mine:7", "should clear mine from branch 2, tile 7")
end

local function _test_anim_unit_overlay_clear_obstacles_clears_each_overlay_and_spawns_robot()
  local overlay = require("src.ui.render.anim_unit_overlay")
  local state = support.build_min_state()
  local cleared_calls = {}
  local group_calls = {}
  local scheduled_callbacks = {}

  _with_patches({
    {
      target = host_runtime,
      key = "create_unit_group",
      value = function(group_id, pos)
        group_calls[#group_calls + 1] = {
          group_id = group_id,
          pos = pos,
        }
        return { _group_id = group_id }
      end,
    },
    {
      target = host_runtime,
      key = "schedule",
      value = function(callback)
        scheduled_callbacks[#scheduled_callbacks + 1] = callback
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
      duration = 0.5,
    }, 0.5, {
      clear_overlay = function(_, kind, tile_index)
        cleared_calls[#cleared_calls + 1] = kind .. ":" .. tostring(tile_index)
      end,
    })
  end)

  assert(#group_calls == 1, "clear_obstacles should create one unit group for single branch")
  assert(group_calls[1].pos.x == 0.0 and group_calls[1].pos.y == 1.0 and group_calls[1].pos.z == 0.0,
    "clear_obstacles robot group should spawn above the acting player tile")
  assert(#cleared_calls == 4, "clear_obstacles should clear roadblock and mine for each tile with has_obstacle=true")
  assert(cleared_calls[1] == "roadblock:2", "clear_obstacles should clear roadblock for tile 2 (has_obstacle=true)")
  assert(cleared_calls[2] == "mine:2", "clear_obstacles should clear mine for tile 2")
  assert(cleared_calls[3] == "roadblock:4", "clear_obstacles should clear roadblock for tile 4 (has_obstacle=true)")
  assert(cleared_calls[4] == "mine:4", "clear_obstacles should clear mine for tile 4")
end


local function _test_anim_unit_overlay_play_missile_clears_overlays_and_spawns_transient()
  local overlay = require("src.ui.render.anim_unit_overlay")
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
end

local function _test_anim_units_play_missile_stops_and_snaps_targets_before_followup()
  local units = require("src.ui.render.anim_units")
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
      target = require("src.ui.render.anim_unit_overlay"),
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
end

return {
  name = "presentation.action_anim_overlay_units",
  tests = {
    { name = "action_anim_roadblock_overlay_uses_4x_scale", run = _test_action_anim_roadblock_overlay_uses_4x_scale },
    { name = "anim_unit_overlay_clear_obstacles_clears_each_overlay_and_spawns_robot", run = _test_anim_unit_overlay_clear_obstacles_clears_each_overlay_and_spawns_robot },
    { name = "anim_unit_overlay_clear_obstacles_multi_branch_creates_multiple_robot_groups", run = _test_anim_unit_overlay_clear_obstacles_multi_branch_creates_multiple_robot_groups },
    { name = "anim_unit_overlay_play_missile_clears_overlays_and_spawns_transient", run = _test_anim_unit_overlay_play_missile_clears_overlays_and_spawns_transient },
    { name = "anim_units_play_missile_stops_and_snaps_targets_before_followup", run = _test_anim_units_play_missile_stops_and_snaps_targets_before_followup },
  },
}
