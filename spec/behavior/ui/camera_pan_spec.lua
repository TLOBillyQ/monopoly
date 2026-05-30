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

  it("does not record camera failure warnings on successful reset and lock", function()
    local role = _make_role()
    runtime_ports.configure({
      resolve_role = function() return role end,
      resolve_camera_helper = function() return nil end,
    })
    local state = _make_state()

    local result = camera_sync.pan_camera_to_position(state, { x = 1, y = 1, z = 1 })
    local log_once = state.debug_runtime and state.debug_runtime.log_once or {}

    _assert_eq(result, true, "should succeed")
    _assert_eq(log_once["camera_sync:reset_camera_failed"], nil, "successful reset should not warn")
    _assert_eq(log_once["camera_sync:set_camera_property_7"], nil, "successful property restore should not warn")
  end)
end)

describe("camera_sync.follow_camera", function()
  after_each(function()
    runtime_ports.reset_for_tests()
  end)

  it("returns false when no local role can be resolved", function()
    local followed = nil
    runtime_ports.configure({
      resolve_role = function() return nil end,
      resolve_camera_helper = function()
        return {
          follow = function(player_id)
            followed = player_id
          end,
        }
      end,
    })

    local result = camera_sync.follow_camera(_make_state(), 2)

    _assert_eq(result, false, "should fail without a local role")
    _assert_eq(followed, 2, "camera helper should still receive the target")
  end)

  it("returns false when current-player fallback has no players table", function()
    runtime_ports.configure({
      resolve_role = function()
        error("missing players table should not resolve a local role")
      end,
      resolve_camera_helper = function()
        return { follow = function() end }
      end,
    })
    local state = {
      game = {
        turn = { current_player_index = 1 },
      },
    }

    local result = camera_sync.follow_camera(state, 2)

    _assert_eq(result, false, "missing players table should not resolve local role")
  end)

  it("prefers live board unit position over role fallback", function()
    local local_role = _make_role()
    local fallback_pos = { x = 99, y = 99, z = 99 }
    local live_pos = { x = 3, y = 4, z = 5 }
    local state = _make_state()
    state.board_scene = {
      units_by_player_id = {
        [2] = {
          get_position = function()
            return live_pos
          end,
        },
      },
    }
    runtime_ports.configure({
      resolve_role = function(role_id)
        if role_id == 1 then
          return local_role
        end
        if role_id == 2 then
          return {
            get_ctrl_unit = function()
              return {
                get_position = function()
                  return fallback_pos
                end,
              }
            end,
          }
        end
        return nil
      end,
      resolve_camera_helper = function()
        return { follow = function() end }
      end,
    })

    local result = camera_sync.follow_camera(state, 2)
    local locked = local_role._locked_positions()

    _assert_eq(result, true, "should lock camera to followed player")
    _assert_eq(locked[1], live_pos, "should use live board unit position")
  end)
end)

describe("camera_sync.sync_camera_position", function()
  after_each(function()
    runtime_ports.reset_for_tests()
  end)

  it("does not lock when helper target is already the local role", function()
    local role = _make_role()
    role.get_ctrl_unit = function()
      return {
        get_position = function()
          return { x = 7, y = 8, z = 9 }
        end,
      }
    end
    runtime_ports.configure({
      resolve_role = function() return role end,
      resolve_camera_helper = function()
        return { target_role_id = 1 }
      end,
    })

    local result = camera_sync.sync_camera_position(_make_state())
    local locked = role._locked_positions()

    _assert_eq(result, false, "should not sync camera to self")
    _assert_eq(#locked, 0, "should not lock when target is local role")
  end)

  it("returns false when camera helper has no target", function()
    runtime_ports.configure({
      resolve_camera_helper = function() return {} end,
    })
    _assert_eq(camera_sync.sync_camera_position(_make_state()), false,
      "should return false when camera helper target is nil")
  end)

  it("returns false when followed target position cannot resolve", function()
    local role = _make_role()
    runtime_ports.configure({
      resolve_role = function(id) if id == 1 then return role end return nil end,
      resolve_camera_helper = function() return { target_role_id = 2 } end,
    })
    local result = camera_sync.sync_camera_position(_make_state())
    _assert_eq(result, false, "should return false when target position is nil")
    _assert_eq(#role._locked_positions(), 0, "should not lock without a target position")
  end)
end)

describe("camera_sync guard branches", function()
  after_each(function()
    runtime_ports.reset_for_tests()
  end)

  it("pan returns false when role lacks set_camera_lock_position", function()
    local role = { reset_camera = function() return true end, set_camera_property = function() end }
    runtime_ports.configure({
      resolve_role = function() return role end,
      resolve_camera_helper = function() return nil end,
    })
    _assert_eq(camera_sync.pan_camera_to_position(_make_state(), { x = 1, y = 2, z = 3 }), false,
      "should return false when role cannot lock camera position")
  end)

  it("self-follow returns false when role lacks reset_camera", function()
    local role = { set_camera_lock_position = function() end, set_camera_property = function() end }
    runtime_ports.configure({
      resolve_role = function() return role end,
      resolve_camera_helper = function() return { follow = function() end } end,
    })
    _assert_eq(camera_sync.follow_camera(_make_state(), 1), false,
      "self-follow should return false when role cannot reset camera")
  end)

  it("follow returns false when player_id is nil", function()
    _assert_eq(camera_sync.follow_camera(_make_state(), nil), false,
      "nil player_id should return false")
  end)

  it("follow returns false when followed player position cannot resolve", function()
    local local_role = _make_role()
    runtime_ports.configure({
      resolve_role = function(id) if id == 1 then return local_role end return nil end,
      resolve_camera_helper = function() return { follow = function() end } end,
    })
    _assert_eq(camera_sync.follow_camera(_make_state(), 2), false,
      "should return false when follow target position is nil")
  end)
end)

describe("camera_sync.release_target_pan", function()
  it("returns false for nil state", function()
    _assert_eq(camera_sync.release_target_pan(nil), false, "nil state should return false")
  end)

  it("clears the follow target and returns true", function()
    local state = { turn_runtime = { last_follow_player_id = 99 } }
    local result = camera_sync.release_target_pan(state)
    _assert_eq(result, true, "should return true on success")
    _assert_eq(state.turn_runtime.last_follow_player_id, nil, "should clear last_follow_player_id")
  end)
end)
