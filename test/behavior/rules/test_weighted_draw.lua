local lu = require("luaunit")
local weighted_draw = require("src.rules.items.weighted_draw")
local runtime_ports = require("src.foundation.ports.runtime_ports")

-- Run `body` with the rng port stubbed to `rng_impl(min, max)`, restoring after.
local function with_rng(rng_impl, body)
  local saved = runtime_ports.rng_next_int
  runtime_ports.rng_next_int = rng_impl
  local ok, err = pcall(body)
  runtime_ports.rng_next_int = saved
  if not ok then
    error(err)
  end
end

local function _ids(list)
  local out = {}
  for i, e in ipairs(list) do
    out[i] = e.id
  end
  return out
end

local function _weight_of(e)
  return e.weight
end

TestWeightedDraw = {}

function TestWeightedDraw:test_returns_empty_for_empty_array()
  local picked = weighted_draw.pick({}, 1, _weight_of, true)
  lu.assertEquals(#picked, 0, "empty array must yield empty result")
end

function TestWeightedDraw:test_returns_empty_when_count_is_0()
  local picked = weighted_draw.pick({ { id = "a", weight = 10 } }, 0, _weight_of, true)
  lu.assertEquals(#picked, 0, "count<=0 must yield empty result")
end

function TestWeightedDraw:test_returns_empty_when_total_weight_is_zero()
  local picked = weighted_draw.pick(
    { { id = "a", weight = 0 }, { id = "b", weight = 0 } }, 1, _weight_of, true)
  lu.assertEquals(#picked, 0, "all-zero weights must yield empty result")
end

function TestWeightedDraw:test_clamps_negative_weights_to_zero()
  -- First element has negative weight (clamped to 0); rng=1 must skip it and land on b.
  local array = { { id = "a", weight = -5 }, { id = "b", weight = 10 } }
  with_rng(function() return 1 end, function()
    local picked = weighted_draw.pick(array, 1, _weight_of, true)
    lu.assertEquals(picked[1].id, "b", "negative-weight bucket must be unreachable; got " ..
      tostring(picked[1] and picked[1].id))
  end)
end

-- total_weight <= 0 是唯一的「抽不出东西」判定,它的下边界必须钉死:
-- 阈值往上挪一格,总权重恰为 1 的池子就会被误判成空池。
function TestWeightedDraw:test_draws_from_a_pool_whose_total_weight_is_exactly_one()
  local array = { { id = "a", weight = 1 } }
  with_rng(function() return 1 end, function()
    local picked = weighted_draw.pick(array, 1, _weight_of, true)
    lu.assertEquals(#picked, 1, "total weight 1 is a drawable pool; got " .. #picked)
    lu.assertEquals(picked[1].id, "a", "the only bucket must be picked")
  end)
end

function TestWeightedDraw:test_draws_from_a_single_element_pool()
  local array = { { id = "a", weight = 10 } }
  with_rng(function() return 1 end, function()
    local picked = weighted_draw.pick(array, 1, _weight_of, true)
    lu.assertEquals(#picked, 1, "a one-element pool is drawable; got " .. #picked)
    lu.assertEquals(picked[1].id, "a", "the only bucket must be picked")
  end)
end

function TestWeightedDraw:test_repeatable_single_pick_honours_rng_lower_bound_first_bucket()
  local array = { { id = "a", weight = 3 }, { id = "b", weight = 7 } }
  with_rng(function() return 1 end, function()
    local picked = weighted_draw.pick(array, 1, _weight_of, true)
    lu.assertEquals(picked[1].id, "a", "rng=1 must hit first bucket")
  end)
end

function TestWeightedDraw:test_repeatable_single_pick_honours_rng_upper_bound_last_bucket()
  local array = { { id = "a", weight = 3 }, { id = "b", weight = 7 } }
  with_rng(function(_, max) return max end, function()
    local picked = weighted_draw.pick(array, 1, _weight_of, true)
    lu.assertEquals(picked[1].id, "b", "rng=total_weight must hit last bucket")
  end)
end

function TestWeightedDraw:test_repeatable_can_draw_the_same_element_multiple_times()
  local array = { { id = "a", weight = 1 }, { id = "b", weight = 1 } }
  with_rng(function() return 1 end, function()
    local picked = weighted_draw.pick(array, 3, _weight_of, true)
    lu.assertEquals(#picked, 3, "repeatable must return `count` picks; got " .. #picked)
    lu.assertEvalToTrue(picked[1].id == "a" and picked[2].id == "a" and picked[3].id == "a",
      "rng=1 must repeatedly pick the first bucket")
  end)
end

function TestWeightedDraw:test_unique_draw_returns_distinct_elements()
  local array = { { id = "a", weight = 5 }, { id = "b", weight = 5 }, { id = "c", weight = 5 } }
  with_rng(function() return 1 end, function()
    local picked = weighted_draw.pick(array, 2, _weight_of, false)
    lu.assertEquals(#picked, 2, "unique draw of 2 must return 2 elements; got " .. #picked)
    lu.assertNotEquals(picked[1].id, picked[2].id, "unique draw must not repeat an element")
  end)
end

function TestWeightedDraw:test_unique_draw_caps_at_array_length_when_count_exceeds_it()
  local array = { { id = "a", weight = 5 }, { id = "b", weight = 5 } }
  with_rng(function() return 1 end, function()
    local picked = weighted_draw.pick(array, 9, _weight_of, false)
    lu.assertEquals(#picked, 2, "unique draw must cap at array length; got " .. #picked)
    local ids = _ids(picked)
    table.sort(ids)
    lu.assertEvalToTrue(ids[1] == "a" and ids[2] == "b", "unique draw must exhaust all elements")
  end)
end

-- 无放回的剩余权重下边界:每桶权重 1 时,取到最后一桶前 remaining_total 恰为 1。
-- 早停阈值往上挪一格,最后一桶就永远抽不到。
function TestWeightedDraw:test_unique_draw_still_takes_the_last_bucket_when_remaining_weight_is_exactly_one()
  local array = { { id = "a", weight = 1 }, { id = "b", weight = 1 } }
  with_rng(function() return 1 end, function()
    local picked = weighted_draw.pick(array, 2, _weight_of, false)
    lu.assertEquals(#picked, 2, "remaining weight 1 must not stop the draw; got " .. #picked)
    local ids = _ids(picked)
    table.sort(ids)
    lu.assertEvalToTrue(ids[1] == "a" and ids[2] == "b", "both weight-1 buckets must be drawn")
  end)
end

function TestWeightedDraw:test_unique_draw_stops_early_when_remaining_weight_is_exhausted()
  -- Two weighted elements and one zero-weight; count=3 forces a third iteration
  -- where remaining_total is already 0, exercising the early break.
  local array = { { id = "a", weight = 5 }, { id = "b", weight = 5 }, { id = "c", weight = 0 } }
  with_rng(function() return 1 end, function()
    local picked = weighted_draw.pick(array, 3, _weight_of, false)
    lu.assertEquals(#picked, 2, "zero-weight element must not be drawn; got " .. #picked)
    for _, e in ipairs(picked) do
      lu.assertNotEquals(e.id, "c", "zero-weight element must never be picked")
    end
  end)
end



function TestWeightedDraw:test_draw_index_uses_min_one_rng_range()
  -- #293:_draw_index 的 rng 下界 `1`(→0 变异)未测。
  local captured_min = nil
  local saved_rng = runtime_ports.rng_next_int
  runtime_ports.rng_next_int = function(min, max)
    captured_min = min
    return min
  end
  weighted_draw.pick({ { id = "a", weight = 1 }, { id = "b", weight = 1 } }, 1,
    function(item) return item.weight end, true)
  runtime_ports.rng_next_int = saved_rng
  lu.assertEvalToTrue(captured_min == 1,
    "rng range should start at 1; got " .. tostring(captured_min))
end

return TestWeightedDraw
