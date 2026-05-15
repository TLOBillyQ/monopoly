local support = require("spec.support.rules_support")
local camera_helper = require("src.host.camera")

local _assert_eq = support.assert_eq

local function _new_helper()
  return camera_helper.new(nil, {})
end

describe("camera_helper", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("camera_helper_new_returns_object_with_target_nil", function()
    local helper = _new_helper()
    assert(type(helper) == "table", "new should return table")
    assert(helper.target_role_id == nil, "target_role_id should default nil")
  end)

  it("camera_helper_set_target_sets_target_role_id", function()
    local helper = _new_helper()
    helper.set_target(5)
    _assert_eq(helper.target_role_id, 5, "set_target should set target_role_id")
    _assert_eq(helper.get_target(), 5, "get_target should return target_role_id")
  end)

  it("camera_helper_get_target_returns_set_value", function()
    local helper = _new_helper()
    helper.set_target(9)
    _assert_eq(helper.get_target(), 9, "get_target should return value previously set")
  end)

  it("camera_helper_follow_sets_target_role_and_returns_true", function()
    local helper = _new_helper()
    local ok = helper.follow(3)
    _assert_eq(ok, true, "follow should return true")
    _assert_eq(helper.target_role_id, 3, "follow should set target_role_id")
  end)
end)
