local P = require("spec.support.shared_support")
local _assert_eq = P.assert_eq
local units = require("src.ui.render.anim.units")
local timing = require("src.config.gameplay.timing")

describe("anim_units_roadblock_trigger", function()
  it("clears_overlay_immediately_without_scheduler", function()
    local cleared = false
    local state = {}
    local anim = { tile_index = 5 }
    local opts = {
      clear_overlay = function(s, kind, idx)
        cleared = true
        _assert_eq(s, state, "should pass state")
        _assert_eq(kind, "roadblock", "should pass roadblock kind")
        _assert_eq(idx, 5, "should pass tile_index")
      end,
    }
    units.play_roadblock_trigger(state, anim, 1.0, opts)
    _assert_eq(cleared, true, "should clear overlay immediately")
  end)

  it("schedules_overlay_clear_when_scheduler_provided", function()
    local scheduled_delay = nil
    local scheduled_fn = nil
    local state = {}
    local anim = { tile_index = 3 }
    local opts = {
      clear_overlay = function() end,
      schedule = function(delay, fn)
        scheduled_delay = delay
        scheduled_fn = fn
      end,
    }
    local hold = timing.roadblock_destroy_hold_seconds
    if hold > 0 then
      units.play_roadblock_trigger(state, anim, 1.0, opts)
      _assert_eq(scheduled_delay, hold, "should schedule with hold_delay")
      _assert_eq(type(scheduled_fn), "function", "should schedule a function")
    else
      units.play_roadblock_trigger(state, anim, 1.0, opts)
      _assert_eq(scheduled_delay, nil, "should not schedule when hold_delay is zero")
    end
  end)

  it("returns_minimum_delay_with_scheduler", function()
    local state = {}
    local anim = { tile_index = 1 }
    local opts = {
      clear_overlay = function() end,
      schedule = function() end,
    }
    local result = units.play_roadblock_trigger(state, anim, 0.5, opts)
    local hold = timing.roadblock_destroy_hold_seconds
    local expected = hold > 0.5 and hold or 0.5
    _assert_eq(result, expected, "should return max of hold_delay and duration")
  end)

  it("clamps_negative_duration_to_zero", function()
    local state = {}
    local anim = { tile_index = 1 }
    local opts = { clear_overlay = function() end }
    local result = units.play_roadblock_trigger(state, anim, -1.0, opts)
    _assert_eq(result, 0, "should clamp negative duration to zero")
  end)

  it("clamps_nil_duration_to_zero", function()
    local state = {}
    local anim = { tile_index = 1 }
    local opts = { clear_overlay = function() end }
    local result = units.play_roadblock_trigger(state, anim, nil, opts)
    _assert_eq(result, 0, "should treat nil duration as zero")
  end)
end)
