local lu = require("luaunit")
local handle_ops = require("src.ui.render.anim.unit_overlay_handle")

TestUnitOverlayHandle = {}

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
  assert(ok, err)
  return table.concat(lines, "\n")
end

function TestUnitOverlayHandle:test_spawn_returns_nil_without_robot_id()
  local hr = { acquire_unit = function() return "never" end }
  local output = _capture_print(function()
    lu.assertEquals(handle_ops.spawn(hr, nil, { x = 1 }), nil, "nil robot_id should skip spawn")
  end)
  lu.assertEvalToTrue(output:find("[unit_overlay_handle]", 1, true) ~= nil,
    "nil robot_id must warn; got: " .. output)
  lu.assertEvalToTrue(output:find("nil robot_id", 1, true) ~= nil,
    "warn must name the nil robot_id path; got: " .. output)
end

function TestUnitOverlayHandle:test_spawn_ignores_pool_and_creates_unit_with_scale()
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
  lu.assertEquals(handle_ops.spawn(hr, "robot_a", pos), "fresh_handle", "should return create_unit_with_scale handle")
  lu.assertEquals(seen.robot_id, "robot_a", "should pass robot_id")
  lu.assertEquals(seen.pos, pos, "should pass position")
  lu.assertEquals(seen.rotation ~= nil, true, "should pass host rotation")
  lu.assertEquals(seen.scale ~= nil, true, "should pass host scale")
end

function TestUnitOverlayHandle:test_spawn_creates_unit_with_scale()
  local hr = {
    create_unit_with_scale = function(robot_id) return "fresh_" .. robot_id end,
  }
  lu.assertEquals(handle_ops.spawn(hr, "robot_b", { x = 3 }), "fresh_robot_b",
    "should create the unit with scale")
end

function TestUnitOverlayHandle:test_spawn_returns_nil_when_runtime_lacks_spawn_methods()
  local output = _capture_print(function()
    lu.assertEquals(handle_ops.spawn({}, "robot_c", { x = 4 }), nil,
      "no spawn capability should yield nil")
  end)
  lu.assertEvalToTrue(output:find("[unit_overlay_handle]", 1, true) ~= nil,
    "missing spawn capability must warn; got: " .. output)
  lu.assertEvalToTrue(output:find("no create_unit_with_scale", 1, true) ~= nil,
    "warn must name the missing capability; got: " .. output)
end

function TestUnitOverlayHandle:test_spawn_warns_when_create_returns_nil_handle()
  -- #339:create 静默 nil 必须被 spawn 层留痕兜住。
  local hr = { create_unit_with_scale = function() return nil end }
  local output = _capture_print(function()
    lu.assertEquals(handle_ops.spawn(hr, "robot_d", { x = 5 }), nil,
      "nil handle from acquire should propagate nil")
  end)
  lu.assertEvalToTrue(output:find("[unit_overlay_handle]", 1, true) ~= nil,
    "nil acquire handle must warn; got: " .. output)
  lu.assertEvalToTrue(output:find("spawn returned nil handle", 1, true) ~= nil,
    "warn must mention the nil handle; got: " .. output)
end

function TestUnitOverlayHandle:test_destroy_ignores_nil_handle()
  local called = false
  local hr = { release_unit = function() called = true end }
  handle_ops.destroy(hr, "robot_a", nil)
  lu.assertEquals(called, false, "nil handle should not release")
end

function TestUnitOverlayHandle:test_destroy_uses_destroy_unit_not_pool()
  -- #339:不走池化——即使 host 提供 release_unit,也直接 destroy_unit。
  local destroyed = nil
  local hr = {
    release_unit = function() error("must not use pool release_unit") end,
    destroy_unit = function(handle) destroyed = handle end,
  }
  handle_ops.destroy(hr, "robot_a", "h1")
  lu.assertEquals(destroyed, "h1", "should destroy the handle directly")
end

function TestUnitOverlayHandle:test_destroy_falls_back_to_destroy_unit()
  local destroyed = nil
  local hr = { destroy_unit = function(handle) destroyed = handle end }
  handle_ops.destroy(hr, "robot_a", "h2")
  lu.assertEquals(destroyed, "h2", "should destroy the handle")
end

function TestUnitOverlayHandle:test_destroy_falls_back_to_destroy_unit_with_children()
  local args = nil
  local hr = {
    destroy_unit_with_children = function(handle, recurse) args = { handle, recurse } end,
  }
  handle_ops.destroy(hr, "robot_a", "h3")
  lu.assertEquals(args[1], "h3", "should destroy the handle")
  lu.assertEquals(args[2], true, "should destroy children recursively")
end

function TestUnitOverlayHandle:test_move_uses_set_position_smooth_when_available()
  local moved = nil
  local handle = { set_position_smooth = function(pos) moved = pos end }
  local result = handle_ops.move({}, "robot_a", handle, { x = 5 })
  lu.assertEquals(result, handle, "should keep the same handle")
  lu.assertEquals(moved.x, 5, "should pass position to smooth move")
end

function TestUnitOverlayHandle:test_move_falls_back_to_set_position()
  local moved = nil
  local handle = { set_position = function(pos) moved = pos end }
  local result = handle_ops.move({}, "robot_a", handle, { x = 6 })
  lu.assertEquals(result, handle, "should keep the same handle")
  lu.assertEquals(moved.x, 6, "should pass position to plain move")
end

function TestUnitOverlayHandle:test_move_respawns_when_handle_cannot_move()
  local destroyed = nil
  local hr = {
    destroy_unit = function(handle) destroyed = handle end,
    create_unit_with_scale = function() return "respawned" end,
  }
  local result = handle_ops.move(hr, "robot_a", "stale_handle", { x = 7 })
  lu.assertEquals(result, "respawned", "should respawn when handle has no move methods")
  lu.assertEquals(destroyed, "stale_handle", "should destroy the stale handle")
end

function TestUnitOverlayHandle:test_move_respawns_when_handle_is_nil()
  local hr = { create_unit_with_scale = function() return "respawned" end }
  lu.assertEquals(handle_ops.move(hr, "robot_a", nil, { x = 8 }), "respawned",
    "nil handle should go straight to respawn")
end

function TestUnitOverlayHandle:test_move_rejects_callable_non_function_move_method()
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
  lu.assertEquals(result, "respawned",
    "a callable-but-non-function move method must be rejected, forcing a respawn")
  lu.assertEquals(invoked, false, "non-function move method must never be invoked")
end


return TestUnitOverlayHandle
