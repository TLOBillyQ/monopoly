-- 原生 LuaUnit 迁移(自研 busted → LuaUnit):原文件为单 describe「domain tick
-- timeout coverage」+ describe 外的 3 个顶层 it(step_modal_timeout 守卫、
-- _capture_default_choice_opts 驱动的 2 个闭包用例),全部拍平进 TestTickTimeout
-- 类(setUp reset_all,describe 内 before_each 语义同);用例数与改写前一一对应
-- (11 + 3 = 14 例)。

local lu = require("luaunit")
local luax = require("test.support.luax")
local ChoiceTimeout = require("src.turn.waits.choice_timeout")
local modal_timeout = require("src.turn.waits.modal_timeout")
local timing = require("src.config.gameplay.timing")

local _config_reset = require("test.support.config_reset")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

TestTickTimeout = {}

function TestTickTimeout:setUp()
  _config_reset.reset_all()
end

function TestTickTimeout:test_resolve_choice_timeout_no_choice_returns_base()
  local timeout = ChoiceTimeout.resolve_choice_timeout_seconds(nil, nil, nil)
  local expected = timing.scope_timeouts.choice
  _assert_eq(timeout, expected, "no choice should return scope_timeouts.choice")
end

function TestTickTimeout:test_resolve_choice_timeout_market_buy_doubles()
  local choice = { kind = "market_buy" }
  local timeout = ChoiceTimeout.resolve_choice_timeout_seconds(nil, nil, choice)
  local expected = timing.scope_timeouts.market_buy
  _assert_eq(timeout, expected, "market_buy should use scope_timeouts.market_buy")
end

function TestTickTimeout:test_resolve_choice_timeout_non_market_buy_returns_base()
  local choice = { kind = "item_phase_passive" }
  local timeout = ChoiceTimeout.resolve_choice_timeout_seconds(nil, nil, choice)
  local expected = timing.scope_timeouts.choice
  _assert_eq(timeout, expected, "non-market_buy choice should use scope_timeouts.choice")
end

TestTickTimeout["test_resolve_choice_timeout choice from game.turn"] = function(self)
  local choice = { kind = "market_buy" }
  local game = { turn = { pending_choice = choice } }
  local timeout = ChoiceTimeout.resolve_choice_timeout_seconds(game, nil, nil)
  local expected = timing.scope_timeouts.market_buy
  _assert_eq(timeout, expected, "choice from game.turn should use scope_timeouts.market_buy")
end

-- #602:外壳的 default_policy 导出随壳删除(零生产调用);modal 族策略钉在
-- modal_timeout.default_policy,选择超时的默认装配改经公开 step_default 驱动
-- (见 test_timeout_closure 的 min-visible 钉)。
function TestTickTimeout:test_modal_default_policy_lives_on_modal_timeout()
  local policy = modal_timeout.default_policy()
  lu.assertEvalToTrue(type(policy) == "table", "default_policy should return a table")
  lu.assertEvalToTrue(type(policy.on_timeout) == "function",
    "modal default policy should carry on_timeout")
end

function TestTickTimeout:test_modal_default_policy_returns_new_table_each_call()
  local p1 = modal_timeout.default_policy()
  local p2 = modal_timeout.default_policy()
  lu.assertNotIs(p1, p2, "default_policy should return a fresh clone each time")
end

function TestTickTimeout:test_step_modal_timeout_zero_timeout_clears_timer()
  local synced = nil
  local output_ports = {
    get_modal_elapsed = function() return 0 end,
    get_modal_ref = function() return nil end,
    sync_modal_timer = function(_, payload) synced = payload end,
  }
  local state = { gameplay_loop_ports = { output = output_ports } }
  modal_timeout.step(state, 0.1, {
    get_timeout_seconds = function() return 0 end,
    is_active = function() return true end,
    get_ref = function() return "ref1" end,
    on_timeout = function() end,
  })
  lu.assertNotNil(synced, "sync_modal_timer should be called")
end

function TestTickTimeout:test_step_modal_timeout_inactive_clears_timer()
  local synced = nil
  local output_ports = {
    get_modal_elapsed = function() return 0 end,
    get_modal_ref = function() return nil end,
    sync_modal_timer = function(_, payload) synced = payload end,
  }
  local state = { gameplay_loop_ports = { output = output_ports } }
  modal_timeout.step(state, 0.1, {
    get_timeout_seconds = function() return 5 end,
    is_active = function() return false end,
    get_ref = function() return "ref1" end,
    on_timeout = function() end,
  })
  lu.assertNotNil(synced, "sync_modal_timer should be called when inactive")
end

function TestTickTimeout:test_step_modal_timeout_active_updates_elapsed()
  local last_sync = nil
  local elapsed = 0
  local output_ports = {
    get_modal_elapsed = function() return elapsed end,
    get_modal_ref = function() return "ref1" end,
    sync_modal_timer = function(_, payload) last_sync = payload; if payload.elapsed_seconds then elapsed = payload.elapsed_seconds end end,
  }
  local state = { gameplay_loop_ports = { output = output_ports } }
  modal_timeout.step(state, 0.5, {
    get_timeout_seconds = function() return 10 end,
    is_active = function() return true end,
    get_ref = function() return "ref1" end,
    on_timeout = function() error("should not timeout") end,
  })
  lu.assertNotNil(last_sync, "sync_modal_timer should be called")
  _assert_eq(last_sync.elapsed_seconds, 0.5, "elapsed should be updated")
end

function TestTickTimeout:test_step_modal_timeout_fires_on_timeout()
  local timed_out = false
  local elapsed_val = 9.0
  local output_ports = {
    get_modal_elapsed = function() return elapsed_val end,
    get_modal_ref = function() return "ref1" end,
    sync_modal_timer = function(_, payload) if payload.elapsed_seconds then elapsed_val = payload.elapsed_seconds end end,
  }
  local state = { gameplay_loop_ports = { output = output_ports } }
  modal_timeout.step(state, 2.0, {
    get_timeout_seconds = function() return 10 end,
    is_active = function() return true end,
    get_ref = function() return "ref1" end,
    on_timeout = function() timed_out = true end,
  })
  _assert_eq(timed_out, true, "on_timeout should fire when elapsed >= timeout")
end

function TestTickTimeout:test_step_modal_timeout_new_ref_resets_timer()
  local syncs = {}
  local output_ports = {
    get_modal_elapsed = function() return 5 end,
    get_modal_ref = function() return "old_ref" end,
    sync_modal_timer = function(_, payload) syncs[#syncs + 1] = payload end,
  }
  local state = { gameplay_loop_ports = { output = output_ports } }
  modal_timeout.step(state, 0.1, {
    get_timeout_seconds = function() return 10 end,
    is_active = function() return true end,
    get_ref = function() return "new_ref" end,
    on_timeout = function() end,
  })
  -- First sync should reset elapsed to 0 (new ref), then update
  lu.assertEvalToTrue(#syncs >= 1, "should have sync calls")
  _assert_eq(syncs[1].ref, "new_ref", "first sync should be with new ref")
  _assert_eq(syncs[1].elapsed_seconds, 0, "new ref should reset elapsed to 0")
end

function TestTickTimeout:test_step_modal_timeout_asserts_opts_presence_with_guard_messages()
  -- kills _assert_modal_opts' four message -> nil mutants. The default
  -- timeout (constants.action_timeout_seconds = 15) is positive, so the
  -- assert runs before is_active is consulted.
  local output_ports = {
    get_modal_elapsed = function() return 0 end,
    get_modal_ref = function() return nil end,
    sync_modal_timer = function() end,
  }
  local state = { gameplay_loop_ports = { output = output_ports } }
  luax.has_error(function()
    modal_timeout.step(state, 0.1, nil)
  end, "missing opts")
  luax.has_error(function()
    modal_timeout.step(state, 0.1, {})
  end, "missing opts.is_active")
  luax.has_error(function()
    modal_timeout.step(state, 0.1, { is_active = function() return true end })
  end, "missing opts.on_timeout")
  luax.has_error(function()
    modal_timeout.step(state, 0.1, {
      is_active = function() return true end,
      on_timeout = function() end,
    })
  end, "missing opts.get_ref")
end

return TestTickTimeout
