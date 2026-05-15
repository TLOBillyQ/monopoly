local support = require("spec.support.runtime_support")
local with_patches = support.with_patches
local game_runtime_bootstrap = require("src.app.gameplay_start")
local gameplay_loop = require("src.turn.loop")
local presentation_ports = require("src.ui.ports")

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

describe("runtime_bootstrap", function()
  it("runtime_bootstrap_uses_wall_clock_diff_after_first_tick", function()
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
  end)

  it("runtime_bootstrap_primes_first_turn_before_set_game", function()
    local capture = { tick_callback = nil, dt_values = {}, primed_game = nil, set_game_received = nil }
    local clock = {
      wall_now_seconds = function()
        return 0
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
    local primed_game = {
      logger = { info = function() end },
      turn = {
        turn_count = 0,
        phase = "start",
        pending_choice = nil,
      },
      advance_turn = function(self)
        self.turn.turn_count = 1
        self.turn.phase = "wait_action"
        capture.primed_game = self
      end,
    }

    with_patches({
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
          return primed_game
        end,
      },
      {
        target = gameplay_loop,
        key = "set_game",
        value = function(_, game)
          capture.set_game_received = game
        end,
      },
      {
        target = gameplay_loop,
        key = "tick",
        value = function(_, _, dt)
          capture.dt_values[#capture.dt_values + 1] = dt
        end,
      },
    }, function()
      local state = {}
      local game_ref = { nil }
      local started = game_runtime_bootstrap.start(state, game_ref)
      assert(started == primed_game, "start should return the created game")
    end)

    assert(capture.primed_game == primed_game, "runtime bootstrap should prime the first turn on startup")
    assert(capture.set_game_received == primed_game, "set_game should receive the primed game instance")
    assert(primed_game.turn.turn_count == 1, "primed startup game should increment first turn count")
    assert(primed_game.turn.phase == "wait_action", "primed startup game should reach wait_action before rendering")
  end)

  it("runtime_bootstrap_falls_back_when_wall_clock_unavailable", function()
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
  end)

  it("runtime_bootstrap_uses_raw_diff_when_wall_diff_returns_zero", function()
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
  end)

  it("runtime_bootstrap_accepts_reversed_wall_diff", function()
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
  end)

  it("runtime_bootstrap_ignores_coarse_wall_clock", function()
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
  end)

  it("runtime_bootstrap_preserves_fractional_wall_clock_diff_across_many_ticks", function()
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
  end)
end)
