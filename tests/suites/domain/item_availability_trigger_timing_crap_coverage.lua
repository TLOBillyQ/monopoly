local support = require("support.domain_support")
local availability = require("src.rules.items.availability")

local _assert_eq = support.assert_eq

local function _test_trigger_timing_allowed_phase_and_timing_match()
  local result = availability.trigger_timing_allowed("pre_action", "pre_action", false)
  _assert_eq(result, true, "trigger_timing_allowed should return true when phase and timing both match")
end

local function _test_trigger_timing_allowed_phase_allows_turn_timing()
  local result = availability.trigger_timing_allowed("pre_action", "turn", false)
  _assert_eq(result, true, "trigger_timing_allowed should allow turn timing for pre_action phase")
end

local function _test_trigger_timing_allowed_phase_disallows_unmatched_timing()
  local result = availability.trigger_timing_allowed("pre_action", "post_action", false)
  _assert_eq(result, false, "trigger_timing_allowed should disallow post_action timing for pre_action phase")
end

local function _test_trigger_timing_allowed_unknown_phase_returns_false()
  local result = availability.trigger_timing_allowed("unknown_phase", "pre_action", false)
  _assert_eq(result, false, "trigger_timing_allowed should return false for unknown phase")
end

local function _test_trigger_timing_allowed_unknown_timing_returns_false()
  local result = availability.trigger_timing_allowed("pre_action", "unknown_timing", false)
  _assert_eq(result, false, "trigger_timing_allowed should return false for unknown timing")
end

local function _test_trigger_timing_allowed_missing_phase_with_allow_missing_false()
  local result = availability.trigger_timing_allowed(nil, "pre_action", false)
  _assert_eq(result, false, "trigger_timing_allowed should return false when phase is nil and allow_missing_phase is false")
end

local function _test_trigger_timing_allowed_missing_phase_with_allow_missing_true()
  local result = availability.trigger_timing_allowed(nil, "pre_action", true)
  _assert_eq(result, true, "trigger_timing_allowed should return true when phase is nil and allow_missing_phase is true")
end

local function _test_trigger_timing_allowed_missing_timing_returns_false()
  local result = availability.trigger_timing_allowed("pre_action", nil, false)
  _assert_eq(result, false, "trigger_timing_allowed should return false when timing is nil")
end

return {
  name = "item_availability_trigger_timing_crap_coverage",
  tests = {
    {
      name = "trigger_timing_allowed phase and timing match",
      run = _test_trigger_timing_allowed_phase_and_timing_match,
    },
    {
      name = "trigger_timing_allowed phase allows turn timing",
      run = _test_trigger_timing_allowed_phase_allows_turn_timing,
    },
    {
      name = "trigger_timing_allowed phase disallows unmatched timing",
      run = _test_trigger_timing_allowed_phase_disallows_unmatched_timing,
    },
    {
      name = "trigger_timing_allowed unknown phase returns false",
      run = _test_trigger_timing_allowed_unknown_phase_returns_false,
    },
    {
      name = "trigger_timing_allowed unknown timing returns false",
      run = _test_trigger_timing_allowed_unknown_timing_returns_false,
    },
    {
      name = "trigger_timing_allowed missing phase with allow_missing_false",
      run = _test_trigger_timing_allowed_missing_phase_with_allow_missing_false,
    },
    {
      name = "trigger_timing_allowed missing phase with allow_missing_true",
      run = _test_trigger_timing_allowed_missing_phase_with_allow_missing_true,
    },
    {
      name = "trigger_timing_allowed missing timing returns false",
      run = _test_trigger_timing_allowed_missing_timing_returns_false,
    },
  },
}
