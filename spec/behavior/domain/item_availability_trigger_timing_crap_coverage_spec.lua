local support = require("support.domain_support")
local availability = require("src.rules.items.availability")

local _assert_eq = support.assert_eq

describe("item_availability_trigger_timing_crap_coverage", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("trigger_timing_allowed phase and timing match", function()
    local result = availability.trigger_timing_allowed("pre_action", "pre_action", false)
    _assert_eq(result, true, "trigger_timing_allowed should return true when phase and timing both match")
  end)

  it("trigger_timing_allowed phase allows turn timing", function()
    local result = availability.trigger_timing_allowed("pre_action", "turn", false)
    _assert_eq(result, true, "trigger_timing_allowed should allow turn timing for pre_action phase")
  end)

  it("trigger_timing_allowed phase disallows unmatched timing", function()
    local result = availability.trigger_timing_allowed("pre_action", "post_action", false)
    _assert_eq(result, false, "trigger_timing_allowed should disallow post_action timing for pre_action phase")
  end)

  it("trigger_timing_allowed unknown phase returns false", function()
    local result = availability.trigger_timing_allowed("unknown_phase", "pre_action", false)
    _assert_eq(result, false, "trigger_timing_allowed should return false for unknown phase")
  end)

  it("trigger_timing_allowed unknown timing returns false", function()
    local result = availability.trigger_timing_allowed("pre_action", "unknown_timing", false)
    _assert_eq(result, false, "trigger_timing_allowed should return false for unknown timing")
  end)

  it("trigger_timing_allowed missing phase with allow_missing_false", function()
    local result = availability.trigger_timing_allowed(nil, "pre_action", false)
    _assert_eq(result, false, "trigger_timing_allowed should return false when phase is nil and allow_missing_phase is false")
  end)

  it("trigger_timing_allowed missing phase with allow_missing_true", function()
    local result = availability.trigger_timing_allowed(nil, "pre_action", true)
    _assert_eq(result, true, "trigger_timing_allowed should return true when phase is nil and allow_missing_phase is true")
  end)

  it("trigger_timing_allowed missing timing returns false", function()
    local result = availability.trigger_timing_allowed("pre_action", nil, false)
    _assert_eq(result, false, "trigger_timing_allowed should return false when timing is nil")
  end)
end)
