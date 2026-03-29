local support = require("support.domain_support")
local runtime_constants = require("src.config.gameplay.runtime_constants")
local runtime_event_bridge = require("src.host.event_bridge")
local camera_helper = require("src.host.camera_helper")

local _assert_eq = support.assert_eq

local function _capture_events()
  local captured = {}
  return captured, {
    target = _G,
    key = "TriggerCustomEvent",
    value = function(event_name, payload)
      captured[#captured + 1] = { event_name = event_name, payload = payload }
    end,
  }
end

local function _new_helper()
  return camera_helper.new(nil, {
    runtime_event_bridge = runtime_event_bridge,
    runtime_constants = runtime_constants,
  })
end

local function _test_camera_helper_new_returns_object_with_target_nil()
  local helper = _new_helper()
  assert(type(helper) == "table", "new should return table")
  assert(helper.target_role_id == nil, "target_role_id should default nil")
end

local function _test_camera_helper_set_target_sets_target_role_id()
  local helper = _new_helper()
  helper.set_target(5)
  _assert_eq(helper.target_role_id, 5, "set_target should set target_role_id")
  _assert_eq(helper.get_target(), 5, "get_target should return target_role_id")
end

local function _test_camera_helper_get_target_returns_set_value()
  local helper = _new_helper()
  helper.set_target(9)
  _assert_eq(helper.get_target(), 9, "get_target should return value previously set")
end

local function _test_camera_helper_follow_emits_custom_event()
  local captured, event_patch = _capture_events()
  support.with_patches({
    event_patch,
  }, function()
    runtime_event_bridge._reset_for_tests()
    local helper = _new_helper()
    local ok = helper.follow(3)
    _assert_eq(ok, true, "follow should return true")
    _assert_eq(helper.target_role_id, 3, "follow should set target_role_id")
    _assert_eq(#captured, 1, "follow should emit exactly one event")
    _assert_eq(captured[1].event_name, runtime_constants.eca_event.camera.follow, "event name should be follow_camera")
  end, { skip_runtime_context_refresh = true })
end

return {
  name = "camera_helper",
  tests = {
    { name = "camera_helper_new_returns_object_with_target_nil", run = _test_camera_helper_new_returns_object_with_target_nil },
    { name = "camera_helper_set_target_sets_target_role_id", run = _test_camera_helper_set_target_sets_target_role_id },
    { name = "camera_helper_get_target_returns_set_value", run = _test_camera_helper_get_target_returns_set_value },
    { name = "camera_helper_follow_emits_custom_event", run = _test_camera_helper_follow_emits_custom_event },
  },
}
