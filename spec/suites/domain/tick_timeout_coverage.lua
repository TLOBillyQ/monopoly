local tick_timeout = require("src.turn.waits.timeout")
local constants = require("src.config.content.constants")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

-- resolve_choice_timeout_seconds

local function test_resolve_choice_timeout_no_choice_returns_base()
  local timeout = tick_timeout.resolve_choice_timeout_seconds(nil, nil, nil)
  local expected = constants.action_timeout_seconds or 0
  _assert_eq(timeout, expected, "no choice should return base timeout")
end

local function test_resolve_choice_timeout_market_buy_doubles()
  local choice = { kind = "market_buy" }
  local timeout = tick_timeout.resolve_choice_timeout_seconds(nil, nil, choice)
  local expected = (constants.action_timeout_seconds or 0) * 2
  _assert_eq(timeout, expected, "market_buy should double timeout")
end

local function test_resolve_choice_timeout_non_market_buy_returns_base()
  local choice = { kind = "item_phase_choice" }
  local timeout = tick_timeout.resolve_choice_timeout_seconds(nil, nil, choice)
  local expected = constants.action_timeout_seconds or 0
  _assert_eq(timeout, expected, "non-market_buy choice should return base timeout")
end

local function test_resolve_choice_timeout_choice_from_game_turn()
  local choice = { kind = "market_buy" }
  local game = { turn = { pending_choice = choice } }
  local timeout = tick_timeout.resolve_choice_timeout_seconds(game, nil, nil)
  local expected = (constants.action_timeout_seconds or 0) * 2
  _assert_eq(timeout, expected, "choice from game.turn should be used")
end

-- default_policy returns clone

local function test_default_policy_returns_table()
  local policy = tick_timeout.default_policy()
  assert(type(policy) == "table", "default_policy should return a table")
  assert(type(policy.choice) == "table", "policy should have choice subtable")
  assert(type(policy.modal) == "table", "policy should have modal subtable")
end

local function test_default_policy_returns_new_table_each_call()
  local p1 = tick_timeout.default_policy()
  local p2 = tick_timeout.default_policy()
  assert(p1 ~= p2, "default_policy should return a fresh clone each time")
end

-- step_modal_timeout: timeout <= 0 clears timer

local function test_step_modal_timeout_zero_timeout_clears_timer()
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
end

-- step_modal_timeout: not active clears timer

local function test_step_modal_timeout_inactive_clears_timer()
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
end

-- step_modal_timeout: active, elapsed < timeout → updates elapsed

local function test_step_modal_timeout_active_updates_elapsed()
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
end

-- step_modal_timeout: timeout reached fires on_timeout

local function test_step_modal_timeout_fires_on_timeout()
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
end

-- step_modal_timeout: new ref resets timer

local function test_step_modal_timeout_new_ref_resets_timer()
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
end

return {
  name = "domain tick timeout coverage",
  tests = {
    { name = "resolve_choice_timeout no choice returns base", run = test_resolve_choice_timeout_no_choice_returns_base },
    { name = "resolve_choice_timeout market_buy doubles", run = test_resolve_choice_timeout_market_buy_doubles },
    { name = "resolve_choice_timeout non-market_buy returns base", run = test_resolve_choice_timeout_non_market_buy_returns_base },
    { name = "resolve_choice_timeout choice from game.turn", run = test_resolve_choice_timeout_choice_from_game_turn },
    { name = "default_policy returns table", run = test_default_policy_returns_table },
    { name = "default_policy returns new table each call", run = test_default_policy_returns_new_table_each_call },
    { name = "step_modal_timeout zero timeout clears timer", run = test_step_modal_timeout_zero_timeout_clears_timer },
    { name = "step_modal_timeout inactive clears timer", run = test_step_modal_timeout_inactive_clears_timer },
    { name = "step_modal_timeout active updates elapsed", run = test_step_modal_timeout_active_updates_elapsed },
    { name = "step_modal_timeout fires on timeout", run = test_step_modal_timeout_fires_on_timeout },
    { name = "step_modal_timeout new ref resets timer", run = test_step_modal_timeout_new_ref_resets_timer },
  },
}
