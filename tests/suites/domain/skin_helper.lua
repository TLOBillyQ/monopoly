local support = require("support.domain_support")
local runtime_constants = require("src.config.gameplay.runtime_constants")
local runtime_event_bridge = require("src.host.event_bridge")
local skin_helper = require("src.host.skin_helper")

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

local function _make_deps(overrides)
  overrides = overrides or {}
  return {
    number_utils = overrides.number_utils or require("src.core.utils.number_utils"),
    runtime_constants = overrides.runtime_constants or runtime_constants,
    runtime_event_bridge = overrides.runtime_event_bridge or runtime_event_bridge,
    logger = overrides.logger or require("src.core.utils.logger"),
  }
end

local function _new_helper(overrides)
  return skin_helper.new(_make_deps(overrides))
end

local function _test_skin_helper_emit_change_skin_validates_role_id()
  local helper = _new_helper()
  _assert_eq(helper.emit_change_skin(nil, 10), false, "emit_change_skin should return false for nil role_id")
  _assert_eq(helper.emit_change_skin("bad", 10), false, "emit_change_skin should return false for invalid role_id")
end

local function _test_skin_helper_emit_change_skin_validates_skin_id()
  local helper = _new_helper()
  _assert_eq(helper.emit_change_skin(3, nil), false, "emit_change_skin should return false for nil skin_id")
  _assert_eq(helper.emit_change_skin(3, -1), false, "emit_change_skin should return false for non-positive skin_id")
end

local function _test_skin_helper_emit_change_skin_sets_fields_and_emits_event()
  local captured, event_patch = _capture_events()
  support.with_patches({
    event_patch,
  }, function()
    runtime_event_bridge._reset_for_tests()
    local helper = _new_helper()
    local ok = helper.emit_change_skin("7", "13")
    _assert_eq(ok, true, "emit_change_skin should return true for valid ids")
    _assert_eq(helper.target_role_id, 7, "emit_change_skin should set target_role_id")
    _assert_eq(helper.skin_id, 13, "emit_change_skin should set skin_id")
    _assert_eq(#captured, 1, "emit_change_skin should emit exactly one event")
    _assert_eq(captured[1].event_name, runtime_constants.eca_event.skin.change, "event name should be change_skin")
  end, { skip_runtime_context_refresh = true })
end

local function _test_skin_helper_emit_change_skin_returns_false_on_invalid()
  local helper = _new_helper()
  _assert_eq(helper.emit_change_skin(2, 0), false, "emit_change_skin should return false for skin_id 0")
end

local function _test_skin_helper_set_model_visible_calls_unit_method()
  local unit = {
    calls = {},
    set_model_visible = function(self, visible)
      self.calls[#self.calls + 1] = visible
    end,
  }
  local helper = _new_helper()
  local ok = helper.set_model_visible(unit, true)
  _assert_eq(ok, true, "set_model_visible should return true when unit method succeeds")
  _assert_eq(#unit.calls, 1, "set_model_visible should call unit method once")
  _assert_eq(unit.calls[1], true, "set_model_visible should pass visible to unit method")
end

local function _test_skin_helper_set_model_visible_handles_pcall_failure()
  local unit = {
    set_model_visible = function()
      error("boom")
    end,
  }
  local helper = _new_helper()
  local ok = helper.set_model_visible(unit, false)
  _assert_eq(ok, false, "set_model_visible should return false when unit method throws")
  _assert_eq(helper.set_model_visible(nil, true), false, "set_model_visible should return false for nil unit")
end

return {
  name = "skin_helper",
  tests = {
    { name = "skin_helper_emit_change_skin_validates_role_id", run = _test_skin_helper_emit_change_skin_validates_role_id },
    { name = "skin_helper_emit_change_skin_validates_skin_id", run = _test_skin_helper_emit_change_skin_validates_skin_id },
    {
      name = "skin_helper_emit_change_skin_sets_fields_and_emits_event",
      run = _test_skin_helper_emit_change_skin_sets_fields_and_emits_event,
    },
    { name = "skin_helper_emit_change_skin_returns_false_on_invalid", run = _test_skin_helper_emit_change_skin_returns_false_on_invalid },
    { name = "skin_helper_set_model_visible_calls_unit_method", run = _test_skin_helper_set_model_visible_calls_unit_method },
    {
      name = "skin_helper_set_model_visible_handles_pcall_failure",
      run = _test_skin_helper_set_model_visible_handles_pcall_failure,
    },
  },
}
