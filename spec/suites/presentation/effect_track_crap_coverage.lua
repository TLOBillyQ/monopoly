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

local function _test_nil_input_returns_nil()
  _with_runtime_port_mocks(function()
    _assert_eq(effect_track.coalesce_queue(nil), nil, "nil queue returns nil")
  end)
end

local function _test_non_table_returns_input()
  _with_runtime_port_mocks(function()
    local input = "abc"
    _assert_eq(effect_track.coalesce_queue(input), input, "non-table queue returns original input")
  end)
end

local function _test_empty_table_returns_same_table()
  _with_runtime_port_mocks(function()
    local queue = {}
    local result = effect_track.coalesce_queue(queue)
    _assert_eq(result, queue, "empty queue returns same table")
  end)
end

local function _test_single_element_returns_same_table()
  _with_runtime_port_mocks(function()
    local queue = {
      { kind = "cash_receive", amount = 10 },
    }
    local result = effect_track.coalesce_queue(queue)
    _assert_eq(result, queue, "single entry queue returns same table")
  end)
end

local function _test_low_pressure_returns_queue_unchanged()
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

local function _test_high_pressure_merges_consecutive_cash_receive()
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

local function _test_high_pressure_preserves_non_sum_policy_kinds()
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

local function _test_high_pressure_mixed_queue_merges_only_consecutive_cash_receive()
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

local function _test_high_pressure_single_cash_receive_block_has_count_one()
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

return {
  name = "effect_track_crap_coverage",
  tests = {
    { name = "_test_nil_input_returns_nil", run = _test_nil_input_returns_nil },
    { name = "_test_non_table_returns_input", run = _test_non_table_returns_input },
    { name = "_test_empty_table_returns_same_table", run = _test_empty_table_returns_same_table },
    { name = "_test_single_element_returns_same_table", run = _test_single_element_returns_same_table },
    { name = "_test_low_pressure_returns_queue_unchanged", run = _test_low_pressure_returns_queue_unchanged },
    { name = "_test_high_pressure_merges_consecutive_cash_receive", run = _test_high_pressure_merges_consecutive_cash_receive },
    { name = "_test_high_pressure_preserves_non_sum_policy_kinds", run = _test_high_pressure_preserves_non_sum_policy_kinds },
    { name = "_test_high_pressure_mixed_queue_merges_only_consecutive_cash_receive", run = _test_high_pressure_mixed_queue_merges_only_consecutive_cash_receive },
    { name = "_test_high_pressure_single_cash_receive_block_has_count_one", run = _test_high_pressure_single_cash_receive_block_has_count_one },
  },
}
