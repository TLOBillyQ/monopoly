local luax = require("test.support.luax")
local P = require("test.support.shared_support")
local _assert_eq = P.assert_eq
local overlay_runtime = require("src.ui.render.anim.overlay_runtime")
local runtime_constants = require("src.config.gameplay.runtime_constants")

local function _new_host_spy(overrides)
  local calls = {}
  local hr = {
    create_unit_group = function(group_id, pos, rot)
      calls[#calls + 1] = { "create_unit_group", group_id, pos, rot }
      return "group_handle"
    end,
    create_unit_with_scale = function(unit_id, pos, rot, scale)
      calls[#calls + 1] = { "create_unit_with_scale", unit_id, pos, rot, scale }
      return "unit_handle"
    end,
    destroy_unit = function(handle)
      calls[#calls + 1] = { "destroy_unit", handle }
    end,
    destroy_unit_with_children = function(handle, recurse)
      calls[#calls + 1] = { "destroy_unit_with_children", handle, recurse }
    end,
    schedule = function(duration, fn)
      calls[#calls + 1] = { "schedule", duration, fn }
    end,
  }
  for key, value in pairs(overrides or {}) do
    hr[key] = value
  end
  return hr, calls
end

local function _new_scene()
  return { overlay_units = nil }
end

TestOverlayRuntimeSpawn = {}

function TestOverlayRuntimeSpawn:test_spawns_a_unit_overlay_and_records_it_in_the_kind_bucket()
  local scene = _new_scene()
  local hr, calls = _new_host_spy()
  local ok = overlay_runtime.spawn_overlay(scene, "mine", 5, nil, "mine_unit", { x = 1 }, nil,
    { host_runtime = hr })

  _assert_eq(ok, true, "spawning a known overlay kind should report success")
  _assert_eq(calls[1][1], "create_unit_with_scale", "unit overlays should be created with a scale")
  _assert_eq(scene.overlay_units.mines[5].handle, "unit_handle", "the mine bucket should hold the handle")
  _assert_eq(scene.overlay_units.mines[5].kind, "unit", "the entry should be tagged as a plain unit")
end

function TestOverlayRuntimeSpawn:test_spawns_a_group_overlay_into_the_roadblock_bucket()
  local scene = _new_scene()
  local hr, calls = _new_host_spy()
  local ok = overlay_runtime.spawn_overlay(scene, "roadblock", 2, "rb_group", nil, { x = 1 }, nil,
    { host_runtime = hr })

  _assert_eq(ok, true, "spawning a group overlay should report success")
  _assert_eq(calls[1][1], "create_unit_group", "group overlays should be created as a unit group")
  _assert_eq(scene.overlay_units.roadblocks[2].kind, "group", "the entry should be tagged as a group")
end

function TestOverlayRuntimeSpawn:test_defaults_the_unit_scale_to_the_identity_vector()
  local scene = _new_scene()
  local hr, calls = _new_host_spy()
  overlay_runtime.spawn_overlay(scene, "mine", 5, nil, "mine_unit", { x = 1 }, nil, { host_runtime = hr })

  _assert_eq(calls[1][5], runtime_constants.v3_one, "a missing scale should fall back to the identity scale")
  _assert_eq(calls[1][4], runtime_constants.q_zero, "overlays should spawn with the zero rotation")
end

function TestOverlayRuntimeSpawn:test_passes_an_explicit_unit_scale_through_to_the_host()
  local scene = _new_scene()
  local scale = { x = 2, y = 2, z = 2 }
  local hr, calls = _new_host_spy()
  overlay_runtime.spawn_overlay(scene, "mine", 5, nil, "mine_unit", { x = 1 }, scale, { host_runtime = hr })

  _assert_eq(calls[1][5], scale, "an explicit scale should reach the host unchanged")
end

function TestOverlayRuntimeSpawn:test_acquires_a_pooled_unit_when_the_host_offers_a_pool()
  local scene = _new_scene()
  local acquired = nil
  local hr = _new_host_spy({
    acquire_unit = function(unit_id, pos, rot, scale)
      acquired = { unit_id, pos, rot, scale }
      return "pooled_handle"
    end,
  })
  local ok = overlay_runtime.spawn_overlay(scene, "mine", 5, nil, "mine_unit", { x = 1 }, nil,
    { host_runtime = hr })

  _assert_eq(ok, true, "a pooled spawn should report success")
  _assert_eq(acquired[1], "mine_unit", "the pool should be asked for the requested unit id")
  _assert_eq(acquired[4], runtime_constants.v3_one, "the pooled unit should get the default scale")
  _assert_eq(scene.overlay_units.mines[5].handle, "pooled_handle", "the bucket should hold the pooled handle")
  _assert_eq(scene.overlay_units.mines[5].pooled, true, "the entry should remember it came from the pool")
end

function TestOverlayRuntimeSpawn:test_reports_failure_when_the_pool_cannot_hand_out_a_unit()
  local scene = _new_scene()
  local hr = _new_host_spy({ acquire_unit = function() return nil end })
  local ok = overlay_runtime.spawn_overlay(scene, "mine", 5, nil, "mine_unit", { x = 1 }, nil,
    { host_runtime = hr })

  _assert_eq(ok, false, "an exhausted pool should report spawn failure")
  _assert_eq(scene.overlay_units.mines[5], nil, "a failed spawn should leave the bucket empty")
end

function TestOverlayRuntimeSpawn:test_reports_failure_when_the_group_spawn_fails()
  local scene = _new_scene()
  local hr = _new_host_spy({ create_unit_group = function() return nil end })
  local ok = overlay_runtime.spawn_overlay(scene, "roadblock", 2, "rb_group", nil, { x = 1 }, nil,
    { host_runtime = hr })

  _assert_eq(ok, false, "a failed group spawn should report failure")
  _assert_eq(scene.overlay_units.roadblocks[2], nil, "a failed spawn should leave the bucket empty")
end

function TestOverlayRuntimeSpawn:test_reports_failure_without_a_group_or_unit_id()
  local scene = _new_scene()
  local hr, calls = _new_host_spy()
  local ok = overlay_runtime.spawn_overlay(scene, "mine", 5, nil, nil, { x = 1 }, nil, { host_runtime = hr })

  _assert_eq(ok, false, "spawning nothing should report failure")
  _assert_eq(#calls, 0, "spawning nothing should not touch the host")
end

function TestOverlayRuntimeSpawn:test_reports_failure_for_an_unknown_overlay_kind()
  local scene = _new_scene()
  local hr, calls = _new_host_spy()
  local ok = overlay_runtime.spawn_overlay(scene, "banana", 5, nil, "mine_unit", { x = 1 }, nil,
    { host_runtime = hr })

  _assert_eq(ok, false, "an unknown overlay kind should report failure")
  _assert_eq(#calls, 0, "an unknown overlay kind should not touch the host")
end

function TestOverlayRuntimeSpawn:test_destroys_the_previous_entry_before_spawning_over_it()
  local scene = _new_scene()
  local hr, calls = _new_host_spy()
  overlay_runtime.spawn_overlay(scene, "mine", 5, nil, "mine_unit", { x = 1 }, nil, { host_runtime = hr })
  overlay_runtime.spawn_overlay(scene, "mine", 5, nil, "mine_unit_2", { x = 2 }, nil, { host_runtime = hr })

  _assert_eq(calls[2][1], "destroy_unit", "respawning on a taken tile should destroy the old handle first")
  _assert_eq(calls[2][2], "unit_handle", "the destroyed handle should be the previous entry's")
  _assert_eq(calls[3][1], "create_unit_with_scale", "the replacement should spawn after the destroy")
end

function TestOverlayRuntimeSpawn:test_makes_a_spawned_overlay_decorative()
  local scene = _new_scene()
  local physics, interact = nil, false
  local handle = {
    set_physics_active = function(active) physics = active end,
    disable_interact = function() interact = true end,
  }
  local hr = _new_host_spy({ create_unit_with_scale = function() return handle end })
  overlay_runtime.spawn_overlay(scene, "mine", 5, nil, "mine_unit", { x = 1 }, nil, { host_runtime = hr })

  _assert_eq(physics, false, "an overlay should drop physics so it cannot collide with pawns")
  _assert_eq(interact, true, "an overlay should drop interaction so it cannot steal taps")
end

function TestOverlayRuntimeSpawn:test_requires_a_scene_a_kind_a_tile_index_and_a_position()
  -- 精确消息钉(#262,kills 四条 assert 消息 -> nil)。
  local hr = _new_host_spy()
  local deps = { host_runtime = hr }
  luax.has_error(function()
    overlay_runtime.spawn_overlay(nil, "mine", 5, nil, "u", { x = 1 }, nil, deps)
  end, "missing board_scene")
  luax.has_error(function()
    overlay_runtime.spawn_overlay(_new_scene(), nil, 5, nil, "u", { x = 1 }, nil, deps)
  end, "missing kind")
  luax.has_error(function()
    overlay_runtime.spawn_overlay(_new_scene(), "mine", nil, nil, "u", { x = 1 }, nil, deps)
  end, "missing tile_index")
  luax.has_error(function()
    overlay_runtime.spawn_overlay(_new_scene(), "mine", 5, nil, "u", nil, nil, deps)
  end, "missing pos")
end

function TestOverlayRuntimeSpawn:test_destroys_a_create_path_entry_even_when_the_host_offers_a_pool()
  -- kills L49 create 路径第二返回 false->true 与 L60 and->or:
  -- 非池化 entry 即使宿主提供 release_unit 也必须走 destroy_unit。
  local scene = _new_scene()
  local released = nil
  local hr, calls = _new_host_spy({
    release_unit = function(unit_id, handle) released = { unit_id, handle } end,
  })
  overlay_runtime.spawn_overlay(scene, "mine", 5, nil, "mine_unit", { x = 1 }, nil, { host_runtime = hr })

  overlay_runtime.clear_overlay(scene, "mine", 5, { host_runtime = hr })

  _assert_eq(released, nil, "a non-pooled entry must not be released to the pool")
  _assert_eq(calls[2][1], "destroy_unit", "a create-path entry should be destroyed")
  _assert_eq(calls[2][2], "unit_handle", "destroy should carry the entry's handle")
end

function TestOverlayRuntimeSpawn:test_destroys_the_entry_and_frees_the_bucket_slot()
  local scene = _new_scene()
  local hr, calls = _new_host_spy()
  overlay_runtime.spawn_overlay(scene, "mine", 5, nil, "mine_unit", { x = 1 }, nil, { host_runtime = hr })

  overlay_runtime.clear_overlay(scene, "mine", 5, { host_runtime = hr })

  _assert_eq(calls[2][1], "destroy_unit", "clearing should destroy the spawned handle")
  _assert_eq(calls[2][2], "unit_handle", "clearing should destroy the entry's handle")
  _assert_eq(scene.overlay_units.mines[5], nil, "clearing should free the bucket slot")
end

function TestOverlayRuntimeSpawn:test_destroys_a_group_entry_with_its_children()
  local scene = _new_scene()
  local hr, calls = _new_host_spy()
  overlay_runtime.spawn_overlay(scene, "roadblock", 2, "rb_group", nil, { x = 1 }, nil, { host_runtime = hr })

  overlay_runtime.clear_overlay(scene, "roadblock", 2, { host_runtime = hr })

  _assert_eq(calls[2][1], "destroy_unit_with_children", "a group entry should be destroyed with its children")
  _assert_eq(calls[2][3], true, "the group destroy should recurse")
end

function TestOverlayRuntimeSpawn:test_releases_a_pooled_entry_back_to_the_pool_instead_of_destroying_it()
  local scene = _new_scene()
  local released = nil
  local hr, calls = _new_host_spy({
    acquire_unit = function() return "pooled_handle" end,
    release_unit = function(unit_id, handle) released = { unit_id, handle } end,
  })
  overlay_runtime.spawn_overlay(scene, "mine", 5, nil, "mine_unit", { x = 1 }, nil, { host_runtime = hr })

  overlay_runtime.clear_overlay(scene, "mine", 5, { host_runtime = hr })

  _assert_eq(released[1], "mine_unit", "the release should carry the unit id")
  _assert_eq(released[2], "pooled_handle", "the release should return the acquired handle")
  _assert_eq(#calls, 0, "a pooled entry should never reach the host destroy path")
end

function TestOverlayRuntimeSpawn:test_clearing_an_empty_slot_is_a_no_op()
  local scene = _new_scene()
  local hr, calls = _new_host_spy()
  overlay_runtime.clear_overlay(scene, "mine", 5, { host_runtime = hr })

  _assert_eq(#calls, 0, "clearing an empty slot should not touch the host")
  _assert_eq(type(scene.overlay_units), "table", "clearing should still initialise the overlay buckets")
end

function TestOverlayRuntimeSpawn:test_clearing_an_unknown_kind_is_a_no_op()
  local scene = _new_scene()
  local hr, calls = _new_host_spy()
  overlay_runtime.clear_overlay(scene, "banana", 5, { host_runtime = hr })

  _assert_eq(#calls, 0, "clearing an unknown kind should not touch the host")
end

function TestOverlayRuntimeSpawn:test_requires_a_scene_a_kind_and_a_tile_index()
  -- 精确消息钉(#262,kills 三条 assert 消息 -> nil)。
  local deps = { host_runtime = _new_host_spy() }
  luax.has_error(function()
    overlay_runtime.clear_overlay(nil, "mine", 5, deps)
  end, "missing board_scene")
  luax.has_error(function()
    overlay_runtime.clear_overlay(_new_scene(), nil, 5, deps)
  end, "missing kind")
  luax.has_error(function()
    overlay_runtime.clear_overlay(_new_scene(), "mine", nil, deps)
  end, "missing tile_index")
end


return TestOverlayRuntimeSpawn
