local P = require("spec.support.shared_support")
local _assert_eq = P.assert_eq
local overlay_runtime = require("src.ui.render.anim.overlay_runtime")

local function _new_host_spy(overrides)
  local calls = {}
  local hr = {
    create_unit_group = function(group_id, pos)
      calls[#calls + 1] = { "create_unit_group", group_id, pos }
      return "group_handle"
    end,
    create_unit_with_scale = function(unit_id, pos)
      calls[#calls + 1] = { "create_unit_with_scale", unit_id, pos }
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

describe("overlay_runtime.spawn_transient", function()
  it("spawns_group_and_destroys_immediately_without_duration", function()
    local hr, calls = _new_host_spy()
    overlay_runtime.spawn_transient("group_a", nil, { x = 1 }, 0, { host_runtime = hr })
    _assert_eq(calls[1][1], "create_unit_group", "should spawn the unit group")
    _assert_eq(calls[2][1], "destroy_unit_with_children", "group entry should destroy with children")
    _assert_eq(calls[2][2], "group_handle", "should destroy the spawned handle")
    _assert_eq(calls[2][3], true, "should destroy children recursively")
  end)

  it("schedules_group_destroy_for_positive_duration", function()
    local hr, calls = _new_host_spy()
    overlay_runtime.spawn_transient("group_a", nil, { x = 1 }, 1.5, { host_runtime = hr })
    _assert_eq(calls[2][1], "schedule", "positive duration should defer destroy")
    _assert_eq(calls[2][2], 1.5, "should schedule with the requested duration")
    calls[2][3]()
    _assert_eq(calls[3][1], "destroy_unit_with_children", "deferred destroy should run on fire")
  end)

  it("skips_destroy_when_group_spawn_fails", function()
    local hr, calls = _new_host_spy({ create_unit_group = function() return nil end })
    overlay_runtime.spawn_transient("group_a", nil, { x = 1 }, 0, { host_runtime = hr })
    _assert_eq(#calls, 0, "failed group spawn should not destroy or schedule")
  end)

  it("spawns_unit_and_destroys_immediately_without_duration", function()
    local hr, calls = _new_host_spy()
    overlay_runtime.spawn_transient(nil, "unit_a", { x = 2 }, nil, { host_runtime = hr })
    _assert_eq(calls[1][1], "create_unit_with_scale", "should spawn the unit")
    _assert_eq(calls[2][1], "destroy_unit", "unit entry should destroy plainly")
    _assert_eq(calls[2][2], "unit_handle", "should destroy the spawned handle")
  end)

  it("skips_destroy_when_unit_spawn_fails", function()
    local hr, calls = _new_host_spy({
      acquire_unit = function() return nil end,
    })
    overlay_runtime.spawn_transient(nil, "unit_a", { x = 2 }, 0, { host_runtime = hr })
    _assert_eq(#calls, 0, "failed unit spawn should not destroy or schedule")
  end)

  it("releases_pooled_unit_back_to_the_pool", function()
    local released = nil
    local hr, calls = _new_host_spy({
      acquire_unit = function(unit_id)
        return "pooled_" .. unit_id
      end,
      release_unit = function(unit_id, handle)
        released = { unit_id, handle }
      end,
    })
    overlay_runtime.spawn_transient(nil, "unit_a", { x = 2 }, 0, { host_runtime = hr })
    _assert_eq(released ~= nil, true, "pooled transient unit should be released, not destroyed")
    _assert_eq(released[1], "unit_a", "release should carry the unit id")
    _assert_eq(released[2], "pooled_unit_a", "release should return the acquired handle")
    _assert_eq(#calls, 0, "no destroy call should reach the host for a pooled unit")
  end)

  it("does_nothing_without_group_or_unit_id", function()
    local hr, calls = _new_host_spy()
    overlay_runtime.spawn_transient(nil, nil, { x = 3 }, 0, { host_runtime = hr })
    _assert_eq(#calls, 0, "missing ids should be a no-op")
  end)
end)
