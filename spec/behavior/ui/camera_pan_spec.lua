local runtime_ports = require("src.foundation.ports.runtime_ports")
local camera_sync = require("src.ui.ports.ui_sync")._camera

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _make_role(opts)
  opts = opts or {}
  local locked_positions = {}
  local reset_calls = 0
  return {
    set_camera_lock_position = function(pos)
      locked_positions[#locked_positions + 1] = pos
    end,
    set_camera_property = opts.set_camera_property or function() end,
    reset_camera = function()
      reset_calls = reset_calls + 1
      return true
    end,
    _locked_positions = function() return locked_positions end,
    _reset_calls = function() return reset_calls end,
  }
end

local function _make_state(opts)
  opts = opts or {}
  return {
    game = {
      turn = { current_player_index = 1 },
      players = { { id = opts.local_role_id or 1 } },
    },
  }
end

describe("camera_sync.pan_camera_to_position", function()
  after_each(function()
    runtime_ports.reset_for_tests()
  end)

  it("returns false when target_pos is nil", function()
    _assert_eq(camera_sync.pan_camera_to_position(_make_state(), nil), false,
      "should return false for nil target_pos")
  end)

  it("returns false when local role cannot be resolved", function()
    runtime_ports.configure({
      resolve_role = function() return nil end,
    })
    _assert_eq(camera_sync.pan_camera_to_position({}, { x = 1, y = 2 }), false,
      "should return false when no local role")
  end)

  it("clears camera target and locks to position on success", function()
    local role = _make_role()
    local camera_helper = { target_role_id = 42 }
    runtime_ports.configure({
      resolve_role = function() return role end,
      resolve_camera_helper = function() return camera_helper end,
    })
    local state = _make_state()
    local target = { x = 10, y = 20, z = 30 }

    local result = camera_sync.pan_camera_to_position(state, target)

    _assert_eq(result, true, "should return true on success")
    _assert_eq(camera_helper.target_role_id, nil, "should clear camera target_role_id")
    local locked = role._locked_positions()
    assert(#locked >= 1, "should lock camera to target position")
  end)

  it("works without camera helper", function()
    local role = _make_role()
    runtime_ports.configure({
      resolve_role = function() return role end,
      resolve_camera_helper = function() return nil end,
    })
    local state = _make_state()
    local target = { x = 5, y = 5, z = 5 }

    local result = camera_sync.pan_camera_to_position(state, target)

    _assert_eq(result, true, "should succeed even without camera helper")
    local locked = role._locked_positions()
    assert(#locked >= 1, "should still lock camera position")
  end)

  it("resets camera to self before locking", function()
    local role = _make_role()
    runtime_ports.configure({
      resolve_role = function() return role end,
      resolve_camera_helper = function() return nil end,
    })
    local state = _make_state()

    camera_sync.pan_camera_to_position(state, { x = 1, y = 1, z = 1 })

    assert(role._reset_calls() >= 1, "should call reset_camera")
  end)
end)
