local lu = require("luaunit")
local memo = require("src.foundation.memo")

TestMemo = {}

-- ===== 惰性求值 =====

function TestMemo:test_compute_does_not_run_until_first_get()
  local calls = 0
  local cell = memo.new(function(snapshot)
    calls = calls + 1
    return snapshot
  end)
  lu.assertNotNil(cell)
  lu.assertEquals(calls, 0, "compute should not run at construction")
end

-- ===== 输入快照未变不重算 =====

function TestMemo:test_unchanged_snapshot_returns_cached_value_without_recompute()
  local calls = 0
  local cell = memo.new(function(snapshot)
    calls = calls + 1
    return snapshot.a
  end)
  local first = cell:get({ a = 1 })
  local second = cell:get({ a = 1 })
  lu.assertEquals(first, 1)
  lu.assertEquals(second, 1)
  lu.assertEquals(calls, 1, "equal snapshot should not recompute")
end

function TestMemo:test_same_table_identity_hit_counts_as_unchanged()
  local calls = 0
  local cell = memo.new(function(snapshot)
    calls = calls + 1
    return snapshot.a
  end)
  local input = { a = 1 }
  cell:get(input)
  cell:get(input)
  lu.assertEquals(calls, 1, "same table with same content should not recompute")
end

-- ===== 输入变化重算 =====

function TestMemo:test_changed_snapshot_recomputes()
  local calls = 0
  local cell = memo.new(function(snapshot)
    calls = calls + 1
    return snapshot.a
  end)
  lu.assertEquals(cell:get({ a = 1 }), 1)
  lu.assertEquals(cell:get({ a = 2 }), 2)
  lu.assertEquals(calls, 2, "changed snapshot should recompute")
end

function TestMemo:test_field_removal_counts_as_change()
  local calls = 0
  local cell = memo.new(function(snapshot)
    calls = calls + 1
    return snapshot.a
  end)
  cell:get({ a = 1 })
  local value = cell:get({})
  lu.assertNil(value, "removed field should produce recomputed value")
  lu.assertEquals(calls, 2)
end

-- ===== 快照冻结：防御调用方复用并原地改写的输入表 =====

function TestMemo:test_caller_mutated_input_table_does_not_corrupt_stored_snapshot()
  local calls = 0
  local cell = memo.new(function(snapshot)
    calls = calls + 1
    return snapshot.a
  end)
  local input = { a = 1 }
  lu.assertEquals(cell:get(input), 1)
  input.a = 2
  lu.assertEquals(cell:get(input), 2, "mutated input should be seen as change")
  input.a = 1
  lu.assertEquals(cell:get(input), 1, "snapshot should be frozen, not aliasing caller table")
  lu.assertEquals(calls, 3)
end

-- ===== take_snapshot 投影 =====

function TestMemo:test_take_snapshot_projects_inputs_and_ignores_noise()
  local calls = 0
  local cell = memo.new(function(snapshot)
    calls = calls + 1
    return snapshot.flag
  end, function(input)
    return { flag = input.flag }
  end)
  lu.assertEquals(cell:get({ flag = true, noise = 1 }), true)
  cell:get({ flag = true, noise = 2 })
  lu.assertEquals(calls, 1, "change outside projection should not recompute")
  lu.assertEquals(cell:get({ flag = false, noise = 2 }), false)
  lu.assertEquals(calls, 2, "change inside projection should recompute")
end

function TestMemo:test_compute_receives_snapshot_not_raw_input()
  local received = nil
  local cell = memo.new(function(snapshot)
    received = snapshot
    return snapshot.projected
  end, function(input)
    return { projected = input.raw }
  end)
  lu.assertEquals(cell:get({ raw = "x" }), "x")
  lu.assertEquals(received.projected, "x", "compute should receive the projected snapshot")
  lu.assertNil(received.raw, "compute should not see raw input fields")
end

-- ===== 标量输入 =====

function TestMemo:test_scalar_snapshot_compared_by_value()
  local calls = 0
  local cell = memo.new(function(snapshot)
    calls = calls + 1
    return snapshot
  end)
  lu.assertEquals(cell:get("x"), "x")
  lu.assertEquals(cell:get("x"), "x")
  lu.assertEquals(calls, 1)
  lu.assertEquals(cell:get("y"), "y")
  lu.assertEquals(calls, 2)
end

-- ===== 派生链：下游派生显式消费上游值，不自动级联 =====

function TestMemo:test_derived_chain_composes_explicitly_without_cascade()
  local upstream_calls = 0
  local is_alive = memo.new(function(snapshot)
    upstream_calls = upstream_calls + 1
    return snapshot.hp > 0
  end, function(snapshot)
    return { hp = snapshot.hp }
  end)
  local is_animating = memo.new(function(snapshot)
    return is_alive:get(snapshot) and not snapshot.frozen
  end)
  lu.assertEquals(is_animating:get({ hp = 10, frozen = false }), true)
  lu.assertEquals(is_animating:get({ hp = 10, frozen = true }), false)
  lu.assertEquals(upstream_calls, 1, "upstream memo should cache across downstream recomputes")
end

-- ===== 单元间独立 =====

function TestMemo:test_cells_do_not_share_state()
  local cell_a = memo.new(function(snapshot)
    return snapshot
  end)
  local cell_b = memo.new(function(snapshot)
    return snapshot
  end)
  lu.assertEquals(cell_a:get(1), 1)
  lu.assertEquals(cell_b:get(2), 2)
  lu.assertEquals(cell_a:get(1), 1, "cell A cache should be unaffected by cell B")
end

-- ===== 构造校验 =====

function TestMemo:test_new_rejects_non_function_compute()
  lu.assertError(memo.new, "not a function")
end

function TestMemo:test_new_rejects_non_function_take_snapshot()
  lu.assertError(memo.new, function()
    return true
  end, "not a function")
end

-- mutate 车道契约：内建 runner 只跑 spec return 的表，单类文件直接 return。
return TestMemo
