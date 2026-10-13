require("test.bootstrap").install_package_paths()
local luassert = assert
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

describe("TestWeightedDraw", function()
it("test_returns_empty_for_empty_array", function()
  local picked = weighted_draw.pick({}, 1, _weight_of, true)
  luassert.is.equal(0, #picked, "empty array must yield empty result")
end)

it("test_returns_empty_when_count_is_0", function()
  local picked = weighted_draw.pick({ { id = "a", weight = 10 } }, 0, _weight_of, true)
  luassert.is.equal(0, #picked, "count<=0 must yield empty result")
end)

it("test_returns_empty_when_total_weight_is_zero", function()
  local picked = weighted_draw.pick(
    { { id = "a", weight = 0 }, { id = "b", weight = 0 } }, 1, _weight_of, true)
  luassert.is.equal(0, #picked, "all-zero weights must yield empty result")
end)

it("test_clamps_negative_weights_to_zero", function()
  -- First element has negative weight (clamped to 0); rng=1 must skip it and land on b.
  local array = { { id = "a", weight = -5 }, { id = "b", weight = 10 } }
  with_rng(function() return 1 end, function()
    local picked = weighted_draw.pick(array, 1, _weight_of, true)
    luassert.is.equal("b", picked[1].id, "negative-weight bucket must be unreachable; got " ..
      tostring(picked[1] and picked[1].id))
  end)
end)

-- total_weight <= 0 是唯一的「抽不出东西」判定,它的下边界必须钉死:
-- 阈值往上挪一格,总权重恰为 1 的池子就会被误判成空池。
it("test_draws_from_a_pool_whose_total_weight_is_exactly_one", function()
  local array = { { id = "a", weight = 1 } }
  with_rng(function() return 1 end, function()
    local picked = weighted_draw.pick(array, 1, _weight_of, true)
    luassert.is.equal(1, #picked, "total weight 1 is a drawable pool; got " .. #picked)
    luassert.is.equal("a", picked[1].id, "the only bucket must be picked")
  end)
end)

it("test_draws_from_a_single_element_pool", function()
  local array = { { id = "a", weight = 10 } }
  with_rng(function() return 1 end, function()
    local picked = weighted_draw.pick(array, 1, _weight_of, true)
    luassert.is.equal(1, #picked, "a one-element pool is drawable; got " .. #picked)
    luassert.is.equal("a", picked[1].id, "the only bucket must be picked")
  end)
end)

it("test_repeatable_single_pick_honours_rng_lower_bound_first_bucket", function()
  local array = { { id = "a", weight = 3 }, { id = "b", weight = 7 } }
  with_rng(function() return 1 end, function()
    local picked = weighted_draw.pick(array, 1, _weight_of, true)
    luassert.is.equal("a", picked[1].id, "rng=1 must hit first bucket")
  end)
end)

it("test_repeatable_single_pick_honours_rng_upper_bound_last_bucket", function()
  local array = { { id = "a", weight = 3 }, { id = "b", weight = 7 } }
  with_rng(function(_, max) return max end, function()
    local picked = weighted_draw.pick(array, 1, _weight_of, true)
    luassert.is.equal("b", picked[1].id, "rng=total_weight must hit last bucket")
  end)
end)

it("test_repeatable_can_draw_the_same_element_multiple_times", function()
  local array = { { id = "a", weight = 1 }, { id = "b", weight = 1 } }
  with_rng(function() return 1 end, function()
    local picked = weighted_draw.pick(array, 3, _weight_of, true)
    luassert.is.equal(3, #picked, "repeatable must return `count` picks; got " .. #picked)
    luassert.truthy(picked[1].id == "a" and picked[2].id == "a" and picked[3].id == "a",
      "rng=1 must repeatedly pick the first bucket")
  end)
end)

it("test_unique_draw_returns_distinct_elements", function()
  local array = { { id = "a", weight = 5 }, { id = "b", weight = 5 }, { id = "c", weight = 5 } }
  with_rng(function() return 1 end, function()
    local picked = weighted_draw.pick(array, 2, _weight_of, false)
    luassert.is.equal(2, #picked, "unique draw of 2 must return 2 elements; got " .. #picked)
    luassert.is_not.equal(picked[2].id, picked[1].id, "unique draw must not repeat an element")
  end)
end)

it("test_unique_draw_caps_at_array_length_when_count_exceeds_it", function()
  local array = { { id = "a", weight = 5 }, { id = "b", weight = 5 } }
  with_rng(function() return 1 end, function()
    local picked = weighted_draw.pick(array, 9, _weight_of, false)
    luassert.is.equal(2, #picked, "unique draw must cap at array length; got " .. #picked)
    local ids = _ids(picked)
    table.sort(ids)
    luassert.truthy(ids[1] == "a" and ids[2] == "b", "unique draw must exhaust all elements")
  end)
end)

-- 无放回的剩余权重下边界:每桶权重 1 时,取到最后一桶前 remaining_total 恰为 1。
-- 早停阈值往上挪一格,最后一桶就永远抽不到。
it("test_unique_draw_still_takes_the_last_bucket_when_remaining_weight_is_exactly_one", function()
  local array = { { id = "a", weight = 1 }, { id = "b", weight = 1 } }
  with_rng(function() return 1 end, function()
    local picked = weighted_draw.pick(array, 2, _weight_of, false)
    luassert.is.equal(2, #picked, "remaining weight 1 must not stop the draw; got " .. #picked)
    local ids = _ids(picked)
    table.sort(ids)
    luassert.truthy(ids[1] == "a" and ids[2] == "b", "both weight-1 buckets must be drawn")
  end)
end)

it("test_unique_draw_stops_early_when_remaining_weight_is_exhausted", function()
  -- Two weighted elements and one zero-weight; count=3 forces a third iteration
  -- where remaining_total is already 0, exercising the early break.
  local array = { { id = "a", weight = 5 }, { id = "b", weight = 5 }, { id = "c", weight = 0 } }
  with_rng(function() return 1 end, function()
    local picked = weighted_draw.pick(array, 3, _weight_of, false)
    luassert.is.equal(2, #picked, "zero-weight element must not be drawn; got " .. #picked)
    for _, e in ipairs(picked) do
      luassert.is_not.equal("c", e.id, "zero-weight element must never be picked")
    end
  end)
end)



it("test_draw_index_uses_min_one_rng_range", function()
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
  luassert.truthy(captured_min == 1,
    "rng range should start at 1; got " .. tostring(captured_min))
end)

end)
