local tick_timeout = require("src.turn.waits.timeout")
local timing = require("src.config.gameplay.timing")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

describe("domain tick timeout coverage", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("resolve_choice_timeout no choice returns base", function()
    local timeout = tick_timeout.resolve_choice_timeout_seconds(nil, nil, nil)
    local expected = timing.scope_timeouts.choice
    _assert_eq(timeout, expected, "no choice should return scope_timeouts.choice")
  end)

  it("resolve_choice_timeout market_buy doubles", function()
    local choice = { kind = "market_buy" }
    local timeout = tick_timeout.resolve_choice_timeout_seconds(nil, nil, choice)
    local expected = timing.scope_timeouts.market_buy
    _assert_eq(timeout, expected, "market_buy should use scope_timeouts.market_buy")
  end)

  it("resolve_choice_timeout non-market_buy returns base", function()
    local choice = { kind = "item_phase_choice" }
    local timeout = tick_timeout.resolve_choice_timeout_seconds(nil, nil, choice)
    local expected = timing.scope_timeouts.choice
    _assert_eq(timeout, expected, "non-market_buy choice should use scope_timeouts.choice")
  end)

  it("resolve_choice_timeout choice from game.turn", function()
    local choice = { kind = "market_buy" }
    local game = { turn = { pending_choice = choice } }
    local timeout = tick_timeout.resolve_choice_timeout_seconds(game, nil, nil)
    local expected = timing.scope_timeouts.market_buy
    _assert_eq(timeout, expected, "choice from game.turn should use scope_timeouts.market_buy")
  end)

  it("default_policy returns table", function()
    local policy = tick_timeout.default_policy()
    assert(type(policy) == "table", "default_policy should return a table")
    assert(type(policy.choice) == "table", "policy should have choice subtable")
    assert(type(policy.modal) == "table", "policy should have modal subtable")
  end)

  it("default_policy returns new table each call", function()
    local p1 = tick_timeout.default_policy()
    local p2 = tick_timeout.default_policy()
    assert(p1 ~= p2, "default_policy should return a fresh clone each time")
  end)

  it("step_modal_timeout zero timeout clears timer", function()
    local synced = nil
    local output_ports = {
      get_modal_elapsed = function() return 0 end,
      get_modal_ref = function() return nil end,
      sync_modal_timer = function(_, payload) synced = payload end,
    }
    local state = { gameplay_loop_ports = { output = output_ports } }
    tick_timeout.step_modal_timeout(state, 0.1, {
      get_timeout_seconds = function() return 0 end,
      is_active = function() return true end,
      get_ref = function() return "ref1" end,
      on_timeout = function() end,
    })
    assert(synced ~= nil, "sync_modal_timer should be called")
  end)

  it("step_modal_timeout inactive clears timer", function()
    local synced = nil
    local output_ports = {
      get_modal_elapsed = function() return 0 end,
      get_modal_ref = function() return nil end,
      sync_modal_timer = function(_, payload) synced = payload end,
    }
    local state = { gameplay_loop_ports = { output = output_ports } }
    tick_timeout.step_modal_timeout(state, 0.1, {
      get_timeout_seconds = function() return 5 end,
      is_active = function() return false end,
      get_ref = function() return "ref1" end,
      on_timeout = function() end,
    })
    assert(synced ~= nil, "sync_modal_timer should be called when inactive")
  end)

  it("step_modal_timeout active updates elapsed", function()
    local last_sync = nil
    local elapsed = 0
    local output_ports = {
      get_modal_elapsed = function() return elapsed end,
      get_modal_ref = function() return "ref1" end,
      sync_modal_timer = function(_, payload) last_sync = payload; if payload.elapsed_seconds then elapsed = payload.elapsed_seconds end end,
    }
    local state = { gameplay_loop_ports = { output = output_ports } }
    tick_timeout.step_modal_timeout(state, 0.5, {
      get_timeout_seconds = function() return 10 end,
      is_active = function() return true end,
      get_ref = function() return "ref1" end,
      on_timeout = function() error("should not timeout") end,
    })
    assert(last_sync ~= nil, "sync_modal_timer should be called")
    _assert_eq(last_sync.elapsed_seconds, 0.5, "elapsed should be updated")
  end)

  it("step_modal_timeout fires on timeout", function()
    local timed_out = false
    local elapsed_val = 9.0
    local output_ports = {
      get_modal_elapsed = function() return elapsed_val end,
      get_modal_ref = function() return "ref1" end,
      sync_modal_timer = function(_, payload) if payload.elapsed_seconds then elapsed_val = payload.elapsed_seconds end end,
    }
    local state = { gameplay_loop_ports = { output = output_ports } }
    tick_timeout.step_modal_timeout(state, 2.0, {
      get_timeout_seconds = function() return 10 end,
      is_active = function() return true end,
      get_ref = function() return "ref1" end,
      on_timeout = function() timed_out = true end,
    })
    _assert_eq(timed_out, true, "on_timeout should fire when elapsed >= timeout")
  end)

  it("step_modal_timeout new ref resets timer", function()
    local syncs = {}
    local output_ports = {
      get_modal_elapsed = function() return 5 end,
      get_modal_ref = function() return "old_ref" end,
      sync_modal_timer = function(_, payload) syncs[#syncs + 1] = payload end,
    }
    local state = { gameplay_loop_ports = { output = output_ports } }
    tick_timeout.step_modal_timeout(state, 0.1, {
      get_timeout_seconds = function() return 10 end,
      is_active = function() return true end,
      get_ref = function() return "new_ref" end,
      on_timeout = function() end,
    })
    -- First sync should reset elapsed to 0 (new ref), then update
    assert(#syncs >= 1, "should have sync calls")
    _assert_eq(syncs[1].ref, "new_ref", "first sync should be with new ref")
    _assert_eq(syncs[1].elapsed_seconds, 0, "new ref should reset elapsed to 0")
  end)
end)
