local P = require("spec.support.shared_support")
local _assert_eq = P.assert_eq
local handle_ops = require("src.ui.render.anim.unit_overlay_handle")

describe("unit_overlay_handle", function()
  it("spawn_returns_nil_without_robot_id", function()
    local hr = { acquire_unit = function() return "never" end }
    _assert_eq(handle_ops.spawn(hr, nil, { x = 1 }), nil, "nil robot_id should skip spawn")
  end)

  it("spawn_prefers_acquire_unit", function()
    local seen = nil
    local hr = {
      acquire_unit = function(robot_id, pos, rotation, scale)
        seen = { robot_id = robot_id, pos = pos, rotation = rotation, scale = scale }
        return "pooled_handle"
      end,
      create_unit_with_scale = function() return "fresh_handle" end,
    }
    local pos = { x = 2 }
    _assert_eq(handle_ops.spawn(hr, "robot_a", pos), "pooled_handle", "should return acquire_unit handle")
    _assert_eq(seen.robot_id, "robot_a", "should pass robot_id")
    _assert_eq(seen.pos, pos, "should pass position")
    _assert_eq(seen.rotation ~= nil, true, "should pass host rotation")
    _assert_eq(seen.scale ~= nil, true, "should pass host scale")
  end)

  it("spawn_falls_back_to_create_unit_with_scale", function()
    local hr = {
      create_unit_with_scale = function(robot_id) return "fresh_" .. robot_id end,
    }
    _assert_eq(handle_ops.spawn(hr, "robot_b", { x = 3 }), "fresh_robot_b",
      "should fall back to create_unit_with_scale")
  end)

  it("spawn_returns_nil_when_runtime_lacks_spawn_methods", function()
    _assert_eq(handle_ops.spawn({}, "robot_c", { x = 4 }), nil,
      "no spawn capability should yield nil")
  end)

  it("destroy_ignores_nil_handle", function()
    local called = false
    local hr = { release_unit = function() called = true end }
    handle_ops.destroy(hr, "robot_a", nil)
    _assert_eq(called, false, "nil handle should not release")
  end)

  it("destroy_prefers_release_unit", function()
    local released = nil
    local hr = {
      release_unit = function(robot_id, handle) released = { robot_id, handle } end,
      destroy_unit = function() error("should not destroy when release available") end,
    }
    handle_ops.destroy(hr, "robot_a", "h1")
    _assert_eq(released[1], "robot_a", "should release with robot_id")
    _assert_eq(released[2], "h1", "should release the handle")
  end)

  it("destroy_falls_back_to_destroy_unit", function()
    local destroyed = nil
    local hr = { destroy_unit = function(handle) destroyed = handle end }
    handle_ops.destroy(hr, "robot_a", "h2")
    _assert_eq(destroyed, "h2", "should destroy the handle")
  end)

  it("destroy_falls_back_to_destroy_unit_with_children", function()
    local args = nil
    local hr = {
      destroy_unit_with_children = function(handle, recurse) args = { handle, recurse } end,
    }
    handle_ops.destroy(hr, "robot_a", "h3")
    _assert_eq(args[1], "h3", "should destroy the handle")
    _assert_eq(args[2], true, "should destroy children recursively")
  end)

  it("move_uses_set_position_smooth_when_available", function()
    local moved = nil
    local handle = { set_position_smooth = function(pos) moved = pos end }
    local result = handle_ops.move({}, "robot_a", handle, { x = 5 })
    _assert_eq(result, handle, "should keep the same handle")
    _assert_eq(moved.x, 5, "should pass position to smooth move")
  end)

  it("move_falls_back_to_set_position", function()
    local moved = nil
    local handle = { set_position = function(pos) moved = pos end }
    local result = handle_ops.move({}, "robot_a", handle, { x = 6 })
    _assert_eq(result, handle, "should keep the same handle")
    _assert_eq(moved.x, 6, "should pass position to plain move")
  end)

  it("move_respawns_when_handle_cannot_move", function()
    local destroyed = nil
    local hr = {
      release_unit = function(robot_id, handle) destroyed = { robot_id, handle } end,
      acquire_unit = function() return "respawned" end,
    }
    local result = handle_ops.move(hr, "robot_a", "stale_handle", { x = 7 })
    _assert_eq(result, "respawned", "should respawn when handle has no move methods")
    _assert_eq(destroyed[1], "robot_a", "should release the stale handle owner")
    _assert_eq(destroyed[2], "stale_handle", "should release the stale handle")
  end)

  it("move_respawns_when_handle_is_nil", function()
    local hr = { acquire_unit = function() return "respawned" end }
    _assert_eq(handle_ops.move(hr, "robot_a", nil, { x = 8 }), "respawned",
      "nil handle should go straight to respawn")
  end)

  it("move_rejects_callable_non_function_move_method", function()
    local invoked = false
    local callable = setmetatable({}, {
      __call = function()
        invoked = true
        return true
      end,
    })
    local handle = { set_position_smooth = callable }
    local hr = { acquire_unit = function() return "respawned" end }
    local result = handle_ops.move(hr, "robot_a", handle, { x = 9 })
    _assert_eq(result, "respawned",
      "a callable-but-non-function move method must be rejected, forcing a respawn")
    _assert_eq(invoked, false, "non-function move method must never be invoked")
  end)
end)
