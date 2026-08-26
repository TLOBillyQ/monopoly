local lu = require("luaunit")
local support = require("test.support.shared_support")
local camera_helper = require("src.host.camera")

local _assert_eq = support.assert_eq

local _config_reset = require("test.support.config_reset")

local function _new_helper()
  return camera_helper.new(nil, {})
end

TestCameraHelper = {}

function TestCameraHelper:setUp()
  _config_reset.reset_all()
end

function TestCameraHelper:test_camera_helper_new_returns_object_with_target_nil()
  local helper = _new_helper()
  lu.assertEvalToTrue(type(helper) == "table", "new should return table")
  lu.assertEvalToTrue(helper.target_role_id == nil, "target_role_id should default nil")
end

function TestCameraHelper:test_camera_helper_set_target_sets_target_role_id()
  local helper = _new_helper()
  helper.set_target(5)
  _assert_eq(helper.target_role_id, 5, "set_target should set target_role_id")
  _assert_eq(helper.get_target(), 5, "get_target should return target_role_id")
end

function TestCameraHelper:test_camera_helper_get_target_returns_set_value()
  local helper = _new_helper()
  helper.set_target(9)
  _assert_eq(helper.get_target(), 9, "get_target should return value previously set")
end

function TestCameraHelper:test_camera_helper_follow_sets_target_role_and_returns_true()
  local helper = _new_helper()
  local ok = helper.follow(3)
  _assert_eq(ok, true, "follow should return true")
  _assert_eq(helper.target_role_id, 3, "follow should set target_role_id")
end

function TestCameraHelper:test_camera_helper_follow_rejects_nil_role()
  -- #293:follow(nil) 的 false 分支未测,false→true 变异存活。
  local helper = _new_helper()
  local ok = helper.follow(nil)
  _assert_eq(ok, false, "follow(nil) should return false")
  _assert_eq(helper.target_role_id, nil, "follow(nil) should not change the target")
end


return TestCameraHelper
