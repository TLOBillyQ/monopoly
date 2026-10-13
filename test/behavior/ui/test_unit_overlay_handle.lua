-- luacheck: ignore 143
require("test.bootstrap").install_package_paths()
local luassert = assert
local handle_ops = require("src.ui.render.anim.unit_overlay_handle")

describe("TestUnitOverlayHandle", function()

  -- #339 留痕:spawn 的 nil 路径必须打 warn(ADR 0046「跳过必留痕」),
  -- 行为保持——仍返回 nil。
  local function _capture_print(fn)
    local lines = {}
    local original = _G.print
    _G.print = function(...)
      local parts = {}
      for index = 1, select("#", ...) do
        parts[#parts + 1] = tostring(select(index, ...))
      end
      lines[#lines + 1] = table.concat(parts, " ")
    end
    local ok, err = pcall(fn)
    _G.print = original
    luassert.truthy(ok, err)
    return table.concat(lines, "\n")
  end

  it("test_spawn_returns_nil_without_robot_id", function()
    local hr = { acquire_unit = function() return "never" end }
    local output = _capture_print(function()
      luassert.is.same(nil, handle_ops.spawn(hr, nil, { x = 1 }), "nil robot_id should skip spawn")
    end)
    luassert.truthy(output:find("[unit_overlay_handle]", 1, true) ~= nil, "nil robot_id must warn; got: " .. output)
    luassert.truthy(output:find("nil robot_id", 1, true) ~= nil, "warn must name the nil robot_id path; got: " .. output)
  end)

  it("test_spawn_ignores_pool_and_creates_unit_with_scale", function()
    -- #339:不走池化——即使 host 提供 acquire_unit,也直接 create_unit_with_scale。
    local seen = nil
    local hr = {
      acquire_unit = function() error("must not use pool acquire_unit") end,
      create_unit_with_scale = function(robot_id, pos, rotation, scale)
        seen = { robot_id = robot_id, pos = pos, rotation = rotation, scale = scale }
        return "fresh_handle"
      end,
    }
    local pos = { x = 2 }
    luassert.is.same("fresh_handle", handle_ops.spawn(hr, "robot_a", pos), "should return create_unit_with_scale handle")
    luassert.is.same("robot_a", seen.robot_id, "should pass robot_id")
    luassert.is.same(pos, seen.pos, "should pass position")
    luassert.is.same(true, seen.rotation ~= nil, "should pass host rotation")
    luassert.is.same(true, seen.scale ~= nil, "should pass host scale")
  end)

  it("test_spawn_creates_unit_with_scale", function()
    local hr = {
      create_unit_with_scale = function(robot_id) return "fresh_" .. robot_id end,
    }
    luassert.is.same("fresh_robot_b", handle_ops.spawn(hr, "robot_b", { x = 3 }), "should create the unit with scale")
  end)

  it("test_spawn_returns_nil_when_runtime_lacks_spawn_methods", function()
    local output = _capture_print(function()
      luassert.is.same(nil, handle_ops.spawn({}, "robot_c", { x = 4 }), "no spawn capability should yield nil")
    end)
    luassert.truthy(output:find("[unit_overlay_handle]", 1, true) ~= nil, "missing spawn capability must warn; got: " .. output)
    luassert.truthy(output:find("no create_unit_with_scale", 1, true) ~= nil, "warn must name the missing capability; got: " .. output)
  end)

  it("test_spawn_warns_when_create_returns_nil_handle", function()
    -- #339:create 静默 nil 必须被 spawn 层留痕兜住。
    local hr = { create_unit_with_scale = function() return nil end }
    local output = _capture_print(function()
      luassert.is.same(nil, handle_ops.spawn(hr, "robot_d", { x = 5 }), "nil handle from acquire should propagate nil")
    end)
    luassert.truthy(output:find("[unit_overlay_handle]", 1, true) ~= nil, "nil acquire handle must warn; got: " .. output)
    luassert.truthy(output:find("spawn returned nil handle", 1, true) ~= nil, "warn must mention the nil handle; got: " .. output)
  end)

  it("test_destroy_ignores_nil_handle", function()
    local called = false
    local hr = { release_unit = function() called = true end }
    handle_ops.destroy(hr, "robot_a", nil)
    luassert.is.same(false, called, "nil handle should not release")
  end)

  it("test_destroy_uses_destroy_unit_not_pool", function()
    -- #339:不走池化——即使 host 提供 release_unit,也直接 destroy_unit。
    local destroyed = nil
    local hr = {
      release_unit = function() error("must not use pool release_unit") end,
      destroy_unit = function(handle) destroyed = handle end,
    }
    handle_ops.destroy(hr, "robot_a", "h1")
    luassert.is.same("h1", destroyed, "should destroy the handle directly")
  end)

  it("test_destroy_falls_back_to_destroy_unit", function()
    local destroyed = nil
    local hr = { destroy_unit = function(handle) destroyed = handle end }
    handle_ops.destroy(hr, "robot_a", "h2")
    luassert.is.same("h2", destroyed, "should destroy the handle")
  end)

  it("test_destroy_falls_back_to_destroy_unit_with_children", function()
    local args = nil
    local hr = {
      destroy_unit_with_children = function(handle, recurse) args = { handle, recurse } end,
    }
    handle_ops.destroy(hr, "robot_a", "h3")
    luassert.is.same("h3", args[1], "should destroy the handle")
    luassert.is.same(true, args[2], "should destroy children recursively")
  end)

  it("test_move_uses_set_position_smooth_when_available", function()
    local moved = nil
    local handle = { set_position_smooth = function(pos) moved = pos end }
    local result = handle_ops.move({}, "robot_a", handle, { x = 5 })
    luassert.is.same(handle, result, "should keep the same handle")
    luassert.is.same(5, moved.x, "should pass position to smooth move")
  end)

  it("test_move_falls_back_to_set_position", function()
    local moved = nil
    local handle = { set_position = function(pos) moved = pos end }
    local result = handle_ops.move({}, "robot_a", handle, { x = 6 })
    luassert.is.same(handle, result, "should keep the same handle")
    luassert.is.same(6, moved.x, "should pass position to plain move")
  end)

  it("test_move_respawns_when_handle_cannot_move", function()
    local destroyed = nil
    local hr = {
      destroy_unit = function(handle) destroyed = handle end,
      create_unit_with_scale = function() return "respawned" end,
    }
    local result = handle_ops.move(hr, "robot_a", "stale_handle", { x = 7 })
    luassert.is.same("respawned", result, "should respawn when handle has no move methods")
    luassert.is.same("stale_handle", destroyed, "should destroy the stale handle")
  end)

  it("test_move_respawns_when_handle_is_nil", function()
    local hr = { create_unit_with_scale = function() return "respawned" end }
    luassert.is.same("respawned", handle_ops.move(hr, "robot_a", nil, { x = 8 }), "nil handle should go straight to respawn")
  end)

  it("test_move_rejects_callable_non_function_move_method", function()
    local invoked = false
    local callable = setmetatable({}, {
      __call = function()
        invoked = true
        return true
      end,
    })
    local handle = { set_position_smooth = callable }
    local hr = { create_unit_with_scale = function() return "respawned" end }
    local result = handle_ops.move(hr, "robot_a", handle, { x = 9 })
    luassert.is.same("respawned", result, "a callable-but-non-function move method must be rejected, forcing a respawn")
    luassert.is.same(false, invoked, "non-function move method must never be invoked")
  end)


end)
