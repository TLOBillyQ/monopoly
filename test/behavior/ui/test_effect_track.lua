local lu = require("luaunit")
local support = require("test.support.shared_support")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local effect_track = require("src.ui.render.support.effect_track")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _spawn_active_tokens(count)
  for i = 1, count do
    effect_track.spawn(i, "cash_receive", 0.1, nil)
  end
end

local function _with_runtime_port_mocks(fn)
  runtime_ports.reset_for_tests()
  effect_track.reset()
  runtime_ports.configure({
    schedule = function() end,
    wall_now_seconds = function() return 0 end,
  })

  local ok, err = pcall(fn)

  runtime_ports.reset_for_tests()
  effect_track.reset()

  if not ok then
    error(err, 2)
  end
end

local function _with_schedule_capture(fn)
  runtime_ports.reset_for_tests()
  effect_track.reset()
  local scheduled = {}
  runtime_ports.configure({
    schedule = function(delay, fn_sched)
      scheduled[#scheduled + 1] = { delay = delay, fn = fn_sched }
    end,
    wall_now_seconds = function() return 0 end,
  })

  local ok, err = pcall(function()
    fn(scheduled)
  end)

  runtime_ports.reset_for_tests()
  effect_track.reset()

  if not ok then
    error(err, 2)
  end
end

TestEffectTrack = {}

function TestEffectTrack:tearDown()
  support.restore_runtime_services()
end

-- ===== coalesce_queue 现有测试 =====

function TestEffectTrack:test__test_nil_input_returns_nil()
  _with_runtime_port_mocks(function()
    _assert_eq(effect_track.coalesce_queue(nil), nil, "nil queue returns nil")
  end)
end

function TestEffectTrack:test__test_non_table_returns_input()
  _with_runtime_port_mocks(function()
    local input = "abc"
    _assert_eq(effect_track.coalesce_queue(input), input, "non-table queue returns original input")
  end)
end

function TestEffectTrack:test__test_empty_table_returns_same_table()
  _with_runtime_port_mocks(function()
    local queue = {}
    local result = effect_track.coalesce_queue(queue)
    _assert_eq(result, queue, "empty queue returns same table")
  end)
end

function TestEffectTrack:test__test_single_element_returns_same_table()
  _with_runtime_port_mocks(function()
    local queue = {
      { kind = "cash_receive", amount = 10 },
    }
    local result = effect_track.coalesce_queue(queue)
    _assert_eq(result, queue, "single entry queue returns same table")
  end)
end

function TestEffectTrack:test__test_low_pressure_returns_queue_unchanged()
  _with_runtime_port_mocks(function()
    _spawn_active_tokens(1)
    local queue = {
      { kind = "cash_receive", amount = 10 },
      { kind = "cash_receive", amount = 20 },
    }
    local result = effect_track.coalesce_queue(queue)
    _assert_eq(result, queue, "low pressure should bypass coalescing")
  end)
end

function TestEffectTrack:test__test_high_pressure_merges_consecutive_cash_receive()
  _with_runtime_port_mocks(function()
    _spawn_active_tokens(5)
    local queue = {
      { kind = "cash_receive", amount = 10 },
      { kind = "cash_receive", amount = 20 },
    }
    local result = effect_track.coalesce_queue(queue)
    _assert_eq(#result, 1, "two consecutive cash_receive entries should merge")
    _assert_eq(result[1].kind, "cash_receive", "merged kind should be cash_receive")
    _assert_eq(result[1].amount, 30, "merged amount should sum")
    _assert_eq(result[1].coalesced_count, 2, "merged coalesced_count should be 2")
  end)
end

function TestEffectTrack:test__test_high_pressure_preserves_non_sum_policy_kinds()
  _with_runtime_port_mocks(function()
    _spawn_active_tokens(5)
    local first = { kind = "roadblock_trigger" }
    local second = { kind = "roadblock_trigger" }
    local queue = { first, second }
    local result = effect_track.coalesce_queue(queue)
    _assert_eq(#result, 2, "non-sum policy kinds should remain separate")
    _assert_eq(result[1], first, "first non-sum entry should be preserved")
    _assert_eq(result[2], second, "second non-sum entry should be preserved")
  end)
end

function TestEffectTrack:test__test_high_pressure_mixed_queue_merges_only_consecutive_cash_receive()
  _with_runtime_port_mocks(function()
    _spawn_active_tokens(5)
    local marker = { kind = "roadblock_trigger" }
    local queue = {
      { kind = "cash_receive", amount = 5 },
      { kind = "cash_receive", amount = 3 },
      marker,
      { kind = "cash_receive", amount = 7 },
    }
    local result = effect_track.coalesce_queue(queue)
    _assert_eq(#result, 3, "mixed queue should collapse only adjacent sum-policy entries")
    _assert_eq(result[1].kind, "cash_receive", "first result should stay cash_receive")
    _assert_eq(result[1].amount, 8, "first cash_receive block should sum")
    _assert_eq(result[1].coalesced_count, 2, "first cash_receive block count should be 2")
    _assert_eq(result[2], marker, "middle non-sum entry should be preserved")
    _assert_eq(result[3].kind, "cash_receive", "tail cash_receive should remain")
    _assert_eq(result[3].amount, 7, "tail cash_receive amount should stay unchanged")
    _assert_eq(result[3].coalesced_count, 1, "single-entry cash_receive block should have count 1")
  end)
end

function TestEffectTrack:test__test_high_pressure_merges_cash_receive_without_amount()
  _with_runtime_port_mocks(function()
    _spawn_active_tokens(5)
    local queue = {
      { kind = "cash_receive", tag = "first" },
      { kind = "cash_receive", tag = "second" },
    }
    local result = effect_track.coalesce_queue(queue)
    _assert_eq(#result, 1, "amount-less cash_receive entries still collapse into one")
    _assert_eq(result[1].amount, nil, "no amount is invented for entries that carry none")
    _assert_eq(result[1].tag, "first", "the merged entry keeps the head entry's fields")
    _assert_eq(result[1].coalesced_count, 2, "the merged entry counts both sources")
  end)
end

function TestEffectTrack:test__test_high_pressure_keeps_amount_when_only_the_head_carries_one()
  _with_runtime_port_mocks(function()
    _spawn_active_tokens(5)
    local queue = {
      { kind = "cash_receive", amount = 10 },
      { kind = "cash_receive" },
    }
    local result = effect_track.coalesce_queue(queue)
    _assert_eq(#result, 1, "the run still collapses")
    _assert_eq(result[1].amount, 10, "an amount-less follower adds nothing to the sum")
    _assert_eq(result[1].coalesced_count, 2, "the amount-less follower is still counted")
  end)
end

function TestEffectTrack:test__test_high_pressure_single_cash_receive_block_has_count_one()
  _with_runtime_port_mocks(function()
    _spawn_active_tokens(5)
    local marker = { kind = "roadblock_trigger" }
    local queue = {
      { kind = "cash_receive", amount = 10 },
      marker,
    }
    local result = effect_track.coalesce_queue(queue)
    _assert_eq(#result, 2, "queue length should stay 2")
    _assert_eq(result[1].kind, "cash_receive", "first entry should be cash_receive")
    _assert_eq(result[1].amount, 10, "single cash_receive amount should stay unchanged")
    _assert_eq(result[1].coalesced_count, 1, "single cash_receive block should be marked as count 1")
    _assert_eq(result[2], marker, "second entry should remain roadblock marker")
  end)
end

function TestEffectTrack:test_await_all_polls_until_effects_drain_then_invokes_the_callback()
  local callbacks = {}
  local scheduled = {}
  runtime_ports.reset_for_tests()
  effect_track.reset()
  runtime_ports.configure({
    schedule = function(delay, fn)
      scheduled[#scheduled + 1] = { delay = delay, fn = fn }
    end,
    wall_now_seconds = function() return 0 end,
  })

  local ok, err = pcall(function()
    effect_track.spawn("cue1", "kind", 0.1)
    local idle = effect_track.await_all(function()
      callbacks[#callbacks + 1] = "done"
    end)

    _assert_eq(idle, false, "await_all should report pending effects")
    _assert_eq(#callbacks, 0, "callback should wait while effects are active")
    lu.assertEvalToTrue(#scheduled >= 2, "spawn and await should schedule callbacks")

    scheduled[1].fn()
    scheduled[#scheduled].fn()
  end)

  runtime_ports.reset_for_tests()
  effect_track.reset()
  if not ok then
    error(err)
  end

  _assert_eq(callbacks[1], "done", "await callback should run after effects drain")
end

function TestEffectTrack:test_cancel_nil_or_completed_returns_false()
  _with_runtime_port_mocks(function()
    _assert_eq(effect_track.cancel(nil), false, "nil token returns false")
    local token = effect_track.spawn(1, "cash_receive", 0.1, nil)
    token.completed = true
    _assert_eq(effect_track.cancel(token), false, "completed token returns false")
  end)
end

function TestEffectTrack:test_cancel_active_token_returns_true_once()
  _with_runtime_port_mocks(function()
    local token = effect_track.spawn(1, "cash_receive", 0.1, nil)
    _assert_eq(effect_track.cancel(token), true, "active token cancelled")
    _assert_eq(effect_track.cancel(token), false, "second cancel returns false")
    _assert_eq(effect_track.is_idle(), true, "cancelled token should not remain active")
  end)
end

-- ===== 补测：spawn 默认值与 token 字段 =====

function TestEffectTrack:test_spawn_default_duration_is_zero()
  _with_runtime_port_mocks(function()
    local token = effect_track.spawn("id1", "cash_receive", nil, nil)
    _assert_eq(token.duration, 0, "nil duration should default to 0")
    _assert_eq(token.id, "id1", "token should carry id")
    _assert_eq(token.kind, "cash_receive", "token should carry kind")
  end)
end

function TestEffectTrack:test_spawn_assigns_incrementing_token_ids()
  _with_runtime_port_mocks(function()
    local t1 = effect_track.spawn("a", "cash_receive", 0.1, nil)
    local t2 = effect_track.spawn("b", "cash_receive", 0.1, nil)
    _assert_eq(t1.token_id, 1, "first token should have id 1")
    _assert_eq(t2.token_id, 2, "second token should have id 2")
  end)
end

function TestEffectTrack:test_spawn_token_has_spawned_at_field()
  _with_runtime_port_mocks(function()
    local token = effect_track.spawn("x", "cash_receive", 0.1, nil)
    _assert_eq(token.spawned_at, 0, "spawned_at should come from wall_now_seconds mock")
  end)
end

function TestEffectTrack:test_spawn_schedules_timeout_with_effective_timeout()
  _with_schedule_capture(function(scheduled)
    effect_track.spawn("t1", "kind", nil, nil)
    lu.assertEvalToTrue(#scheduled >= 1, "spawn should schedule timeout callback")
    local timeout_delay = scheduled[1].delay
    -- effective_timeout = (nil or 0) + 10 = 10
    _assert_eq(timeout_delay, 10.0, "nil duration should give default timeout seconds")
  end)
end

function TestEffectTrack:test_spawn_with_explicit_duration_schedules_correct_timeout()
  _with_schedule_capture(function(scheduled)
    effect_track.spawn("t1", "kind", 5.0, nil)
    local timeout_delay = scheduled[1].delay
    _assert_eq(timeout_delay, 15.0, "explicit duration + timeout_seconds")
  end)
end

function TestEffectTrack:test_reset_clears_state()
  _with_runtime_port_mocks(function()
    _spawn_active_tokens(3)
    _assert_eq(effect_track.is_idle(), false, "should have active tokens before reset")
    effect_track.reset()
    _assert_eq(effect_track.is_idle(), true, "reset should clear all tokens")
    -- next spawn should get token_id = 1
    local t = effect_track.spawn("new", "cash_receive", 0.1, nil)
    _assert_eq(t.token_id, 1, "reset should restart token_id counter")
  end)
end

-- ===== 补测：_complete 路径（通过 timeout 回调触发） =====

function TestEffectTrack:test_on_complete_invoked_when_timeout_fires()
  local completed = {}
  _with_schedule_capture(function(scheduled)
    effect_track.spawn("cue", "kind", 0.1, function(token)
      completed[#completed + 1] = token.id
    end)
    _assert_eq(#completed, 0, "on_complete should not fire before timeout")

    -- 执行 timeout 回调 = 调用 _complete
    scheduled[1].fn()
    _assert_eq(#completed, 1, "on_complete should fire after timeout")
    _assert_eq(completed[1], "cue", "on_complete should receive the correct token")
  end)
end

function TestEffectTrack:test_cancel_returns_false_after_timeout_completes_token()
  _with_schedule_capture(function(scheduled)
    local token = effect_track.spawn("cue", "kind", 0.1, nil)
    _assert_eq(effect_track.cancel(token), true, "cancel before timeout should succeed")

    -- 第二个 token：先让 timeout 触发再尝试 cancel
    local token2 = effect_track.spawn("cue2", "kind", 0.1, nil)
    scheduled[#scheduled].fn() -- 这里的回调完成 token2（因为 spawn 会 schedule）
    _assert_eq(effect_track.is_idle(), true, "token2 should be completed by timeout")
    _assert_eq(effect_track.cancel(token2), false, "cancel after timeout completion should return false")
  end)
end

function TestEffectTrack:test_is_idle_returns_true_after_timeout()
  _with_schedule_capture(function(scheduled)
    _assert_eq(effect_track.is_idle(), true, "should be idle initially")
    effect_track.spawn("cue", "kind", 0.1, nil)
    _assert_eq(effect_track.is_idle(), false, "should not be idle while token active")
    scheduled[1].fn()
    _assert_eq(effect_track.is_idle(), true, "should be idle after timeout cleans up")
  end)
end

-- ===== 补测：await_all 空闲路径 =====

function TestEffectTrack:test_await_all_when_idle_returns_true_and_invokes_callback_immediately()
  _with_runtime_port_mocks(function()
    local called = false
    local result = effect_track.await_all(function()
      called = true
    end)
    _assert_eq(result, true, "await_all when idle should return true")
    lu.assertEvalToTrue(called, "callback should be invoked immediately when idle")
  end)
end

function TestEffectTrack:test_await_all_when_idle_without_callback_returns_true()
  _with_runtime_port_mocks(function()
    local result = effect_track.await_all(nil)
    _assert_eq(result, true, "await_all when idle without callback should return true")
  end)
end

-- ===== 补测：scaled_duration 与 _pressure 边界 =====

function TestEffectTrack:test_scaled_duration_zero_pressure_returns_full_base()
  _with_runtime_port_mocks(function()
    -- 0 active tokens → pressure 0 → scale 1.0
    local result = effect_track.scaled_duration(2.0)
    _assert_eq(result, 2.0, "zero pressure should use 1.0 scale")
  end)
end

function TestEffectTrack:test_scaled_duration_single_token_pressure_returns_full_base()
  _with_runtime_port_mocks(function()
    _spawn_active_tokens(1) -- count=1 → pressure 0
    local result = effect_track.scaled_duration(2.0)
    _assert_eq(result, 2.0, "single token pressure 0 should use 1.0 scale")
  end)
end

function TestEffectTrack:test_scaled_duration_low_pressure_returns_half_base()
  _with_runtime_port_mocks(function()
    _spawn_active_tokens(2) -- count=2 ≤ 3 → pressure 0.3 → scale 0.5
    local result = effect_track.scaled_duration(2.0)
    _assert_eq(result, 1.0, "pressure 0.3 should halve base duration")
  end)
end

function TestEffectTrack:test_scaled_duration_medium_pressure_returns_quarter_base()
  _with_runtime_port_mocks(function()
    _spawn_active_tokens(4) -- count=4 ≤ 6 → pressure 0.6 → scale 0.25
    local result = effect_track.scaled_duration(4.0)
    _assert_eq(result, 1.0, "pressure 0.6 should quarter base duration")
  end)
end

function TestEffectTrack:test_scaled_duration_high_pressure_returns_min_scale_base()
  _with_runtime_port_mocks(function()
    _spawn_active_tokens(7) -- count=7 > 6 → pressure 0.9 → scale 0.15
    local result = effect_track.scaled_duration(10.0)
    _assert_eq(result, 1.5, "pressure 0.9 should use 0.15 scale")
  end)
end

function TestEffectTrack:test_scaled_duration_hits_exact_threshold()
  _with_runtime_port_mocks(function()
    _spawn_active_tokens(3) -- count=3 ≤ 3 → pressure 0.3 → scale 0.5
    local result = effect_track.scaled_duration(3.0)
    _assert_eq(result, 1.5, "exact boundary count 3 should give pressure 0.3")
  end)
end

function TestEffectTrack:test_scaled_duration_count_six_boundary()
  _with_runtime_port_mocks(function()
    _spawn_active_tokens(6) -- count=6 ≤ 6 → pressure 0.6 → scale 0.25
    local result = effect_track.scaled_duration(8.0)
    _assert_eq(result, 2.0, "exact boundary count 6 should give pressure 0.6")
  end)
end

-- ===== 补测：_can_coalesce 边界 =====

function TestEffectTrack:test_single_element_queue_not_coalesced_even_under_high_pressure()
  _with_runtime_port_mocks(function()
    _spawn_active_tokens(5) -- high pressure
    local queue = {
      { kind = "cash_receive", amount = 10 },
    }
    local result = effect_track.coalesce_queue(queue)
    _assert_eq(result, queue, "single-element queue should not be coalesced")
  end)
end

function TestEffectTrack:test_coalesce_queue_pressure_exactly_at_threshold_still_coalesces()
  _with_runtime_port_mocks(function()
    _spawn_active_tokens(4) -- count=4 ≤ 6 → pressure 0.6, not < 0.6 → coalesce
    local queue = {
      { kind = "cash_receive", amount = 10 },
      { kind = "cash_receive", amount = 20 },
    }
    local result = effect_track.coalesce_queue(queue)
    _assert_eq(#result, 1, "pressure 0.6 should coalesce (0.6 is not < 0.6)")
  end)
end

return TestEffectTrack
