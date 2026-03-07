local support = require("TestSupport")
local with_patches = support.with_patches
local game_runtime_bootstrap = require("src.app.bootstrap.game_runtime_bootstrap")
local gameplay_loop = require("src.game.flow.turn.gameplay_loop")
local presentation_ports = require("src.presentation.adapter.presentation_ports")

local function _assert_close(actual, expected, epsilon, msg)
  local delta = math.abs((actual or 0) - (expected or 0))
  assert(delta <= epsilon, (msg or "value mismatch") .. " expected=" .. tostring(expected) .. " actual=" .. tostring(actual))
end

local function _common_start_patches(capture, clock)
  return {
    { target = package.loaded, key = "vendor.third_party.Utils", value = true },
    {
      key = "SetFrameOut",
      value = function(_, cb)
        capture.tick_callback = cb
        return {}
      end,
    },
    {
      target = presentation_ports,
      key = "build",
      value = function()
        return {
          clock = clock,
        }
      end,
    },
    {
      target = gameplay_loop,
      key = "new_game",
      value = function()
        return {
          logger = { info = function() end },
        }
      end,
    },
    {
      target = gameplay_loop,
      key = "set_game",
      value = function() end,
    },
    {
      target = gameplay_loop,
      key = "tick",
      value = function(_, _, dt)
        capture.dt_values[#capture.dt_values + 1] = dt
      end,
    },
  }
end

local function _test_runtime_bootstrap_uses_wall_clock_diff_after_first_tick()
  local capture = { tick_callback = nil, dt_values = {} }
  local now_values = { 100, 100.05 }
  local now_index = 0
  local clock = {
    wall_now_seconds = function()
      now_index = now_index + 1
      return now_values[now_index] or now_values[#now_values]
    end,
    wall_diff_seconds = function(current, previous)
      return current - previous
    end,
    cpu_now_seconds = function()
      return 0
    end,
    cpu_diff_seconds = function(current, previous)
      return current - previous
    end,
  }

  with_patches(_common_start_patches(capture, clock), function()
    local state = {}
    local game_ref = { nil }
    game_runtime_bootstrap.start(state, game_ref)
    assert(type(capture.tick_callback) == "function", "tick callback should be registered")
    capture.tick_callback()
    capture.tick_callback()
  end)

  assert(#capture.dt_values == 2, "tick callback should produce two dt samples")
  _assert_close(capture.dt_values[1], 1.0 / 30.0, 0.0001, "first tick should fallback to fixed delta")
  _assert_close(capture.dt_values[2], 0.05, 0.0001, "second tick should use wall clock diff delta")
end

local function _test_runtime_bootstrap_falls_back_when_wall_clock_unavailable()
  local capture = { tick_callback = nil, dt_values = {} }
  local clock = {
    wall_now_seconds = function()
      return nil
    end,
    wall_diff_seconds = function()
      return nil
    end,
    cpu_now_seconds = function()
      return 0
    end,
    cpu_diff_seconds = function(current, previous)
      return current - previous
    end,
  }

  with_patches(_common_start_patches(capture, clock), function()
    local state = {}
    local game_ref = { nil }
    game_runtime_bootstrap.start(state, game_ref)
    assert(type(capture.tick_callback) == "function", "tick callback should be registered")
    capture.tick_callback()
  end)

  assert(#capture.dt_values == 1, "tick callback should produce one dt sample")
  _assert_close(capture.dt_values[1], 1.0 / 30.0, 0.0001, "invalid wall clock should fallback to fixed delta")
end

local function _test_runtime_bootstrap_uses_raw_diff_when_wall_diff_returns_zero()
  local capture = { tick_callback = nil, dt_values = {} }
  local now_values = { 10.00, 10.08 }
  local now_index = 0
  local clock = {
    wall_now_seconds = function()
      now_index = now_index + 1
      return now_values[now_index] or now_values[#now_values]
    end,
    wall_diff_seconds = function()
      return 0
    end,
    cpu_now_seconds = function()
      return 0
    end,
    cpu_diff_seconds = function(current, previous)
      return current - previous
    end,
  }

  with_patches(_common_start_patches(capture, clock), function()
    local state = {}
    local game_ref = { nil }
    game_runtime_bootstrap.start(state, game_ref)
    capture.tick_callback()
    capture.tick_callback()
  end)

  assert(#capture.dt_values == 2, "tick callback should produce two dt samples")
  _assert_close(capture.dt_values[1], 1.0 / 30.0, 0.0001, "first tick should fallback to fixed delta")
  _assert_close(capture.dt_values[2], 0.08, 0.0001, "second tick should fallback to raw timestamp diff")
end

local function _test_runtime_bootstrap_accepts_reversed_wall_diff()
  local capture = { tick_callback = nil, dt_values = {} }
  local now_values = { 20.00, 20.06 }
  local now_index = 0
  local clock = {
    wall_now_seconds = function()
      now_index = now_index + 1
      return now_values[now_index] or now_values[#now_values]
    end,
    wall_diff_seconds = function(a, b)
      return b - a
    end,
    cpu_now_seconds = function()
      return 0
    end,
    cpu_diff_seconds = function(current, previous)
      return current - previous
    end,
  }

  with_patches(_common_start_patches(capture, clock), function()
    local state = {}
    local game_ref = { nil }
    game_runtime_bootstrap.start(state, game_ref)
    capture.tick_callback()
    capture.tick_callback()
  end)

  assert(#capture.dt_values == 2, "tick callback should produce two dt samples")
  _assert_close(capture.dt_values[1], 1.0 / 30.0, 0.0001, "first tick should fallback to fixed delta")
  _assert_close(capture.dt_values[2], 0.06, 0.0001, "second tick should accept reversed diff source")
end

local function _test_runtime_bootstrap_ignores_coarse_wall_clock()
  local capture = { tick_callback = nil, dt_values = {} }
  local now_values = { 123456, 123457, 123458 }
  local now_index = 0
  local clock = {
    wall_now_seconds = function()
      now_index = now_index + 1
      return now_values[now_index] or now_values[#now_values]
    end,
    wall_diff_seconds = function(current, previous)
      return current - previous
    end,
    cpu_now_seconds = function()
      return 0
    end,
    cpu_diff_seconds = function(current, previous)
      return current - previous
    end,
  }

  with_patches(_common_start_patches(capture, clock), function()
    local state = {}
    local game_ref = { nil }
    game_runtime_bootstrap.start(state, game_ref)
    capture.tick_callback()
    capture.tick_callback()
    capture.tick_callback()
  end)

  assert(#capture.dt_values == 3, "tick callback should produce three dt samples")
  _assert_close(capture.dt_values[1], 1.0 / 30.0, 0.0001, "first tick should fallback to fixed delta")
  _assert_close(capture.dt_values[2], 1.0 / 30.0, 0.0001, "coarse wall clock should keep fixed delta")
  _assert_close(capture.dt_values[3], 1.0 / 30.0, 0.0001, "coarse wall clock should keep fixed delta")
end

local function _test_runtime_bootstrap_preserves_fractional_wall_clock_diff_across_many_ticks()
  local capture = { tick_callback = nil, dt_values = {} }
  local now_values = { 200.00, 200.03, 200.06, 200.09 }
  local now_index = 0
  local clock = {
    wall_now_seconds = function()
      now_index = now_index + 1
      return now_values[now_index] or now_values[#now_values]
    end,
    wall_diff_seconds = function(current, previous)
      return current - previous
    end,
    cpu_now_seconds = function()
      return 0
    end,
    cpu_diff_seconds = function(current, previous)
      return current - previous
    end,
  }

  with_patches(_common_start_patches(capture, clock), function()
    local state = {}
    local game_ref = { nil }
    game_runtime_bootstrap.start(state, game_ref)
    capture.tick_callback()
    capture.tick_callback()
    capture.tick_callback()
    capture.tick_callback()
  end)

  assert(#capture.dt_values == 4, "tick callback should preserve each fractional dt sample")
  _assert_close(capture.dt_values[1], 1.0 / 30.0, 0.0001, "first tick should fallback to fixed delta")
  _assert_close(capture.dt_values[2], 0.03, 0.0001, "second tick should keep fractional wall diff")
  _assert_close(capture.dt_values[3], 0.03, 0.0001, "third tick should keep fractional wall diff")
  _assert_close(capture.dt_values[4], 0.03, 0.0001, "fourth tick should keep fractional wall diff")
end

return {
  name = "runtime_bootstrap",
  tests = {
    {
      name = "runtime_bootstrap_uses_wall_clock_diff_after_first_tick",
      run = _test_runtime_bootstrap_uses_wall_clock_diff_after_first_tick,
    },
    {
      name = "runtime_bootstrap_falls_back_when_wall_clock_unavailable",
      run = _test_runtime_bootstrap_falls_back_when_wall_clock_unavailable,
    },
    {
      name = "runtime_bootstrap_uses_raw_diff_when_wall_diff_returns_zero",
      run = _test_runtime_bootstrap_uses_raw_diff_when_wall_diff_returns_zero,
    },
    {
      name = "runtime_bootstrap_accepts_reversed_wall_diff",
      run = _test_runtime_bootstrap_accepts_reversed_wall_diff,
    },
    {
      name = "runtime_bootstrap_ignores_coarse_wall_clock",
      run = _test_runtime_bootstrap_ignores_coarse_wall_clock,
    },
    {
      name = "runtime_bootstrap_preserves_fractional_wall_clock_diff_across_many_ticks",
      run = _test_runtime_bootstrap_preserves_fractional_wall_clock_diff_across_many_ticks,
    },
  },
}
