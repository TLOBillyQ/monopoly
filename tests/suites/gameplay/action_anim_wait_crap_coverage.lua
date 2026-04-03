local action_anim_wait = require("src.turn.waits.await.action_anim_wait")

local _coalesce_head = action_anim_wait._M_test._coalesce_head

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _test_empty_queue_noop()
  local queue = {}
  _coalesce_head(queue)
  _assert_eq(#queue, 0, "empty queue should remain empty")
end

local function _test_single_element_queue_noop()
  local queue = {
    { kind = "cash_receive", amount = 10 },
  }
  _coalesce_head(queue)
  _assert_eq(#queue, 1, "single element queue should not be modified")
  _assert_eq(queue[1].amount, 10, "single element amount should stay unchanged")
  _assert_eq(queue[1].coalesced_count, nil, "single element should not get coalesced_count")
end

local function _test_head_not_cash_receive_noop()
  local queue = {
    { kind = "roadblock" },
    { kind = "cash_receive", amount = 5 },
  }
  _coalesce_head(queue)
  _assert_eq(#queue, 2, "head not cash_receive should skip coalescing")
  _assert_eq(queue[1].kind, "roadblock", "head kind should remain unchanged")
  _assert_eq(queue[2].amount, 5, "second entry should remain unchanged")
end

local function _test_two_cash_receive_merge()
  local queue = {
    { kind = "cash_receive", amount = 10 },
    { kind = "cash_receive", amount = 20 },
  }
  _coalesce_head(queue)
  _assert_eq(#queue, 1, "two cash_receive entries should merge")
  _assert_eq(queue[1].amount, 30, "merged amount should sum")
  _assert_eq(queue[1].coalesced_count, 2, "merged coalesced_count should be 2")
end

local function _test_three_cash_receive_merge()
  local queue = {
    { kind = "cash_receive", amount = 5 },
    { kind = "cash_receive", amount = 3 },
    { kind = "cash_receive", amount = 7 },
  }
  _coalesce_head(queue)
  _assert_eq(#queue, 1, "three cash_receive entries should merge")
  _assert_eq(queue[1].amount, 15, "three-way merged amount should sum")
  _assert_eq(queue[1].coalesced_count, 3, "three-way coalesced_count should be 3")
end

local function _test_cash_receive_followed_by_different_kind_stops_merge()
  local queue = {
    { kind = "cash_receive", amount = 10 },
    { kind = "roadblock" },
    { kind = "cash_receive", amount = 5 },
  }
  _coalesce_head(queue)
  _assert_eq(#queue, 3, "non-cash second entry should prevent merge")
  _assert_eq(queue[1].amount, 10, "head amount should remain unchanged")
  _assert_eq(queue[1].coalesced_count, nil, "head should not get coalesced_count when no merge")
end

local function _test_nil_amount_treated_as_zero()
  local queue = {
    { kind = "cash_receive" },
    { kind = "cash_receive", amount = 5 },
  }
  _coalesce_head(queue)
  _assert_eq(#queue, 1, "entries should merge when both are cash_receive")
  _assert_eq(queue[1].amount, 5, "nil amount should be treated as zero")
  _assert_eq(queue[1].coalesced_count, 2, "coalesced_count should reflect merged entries")
end

local function _test_both_nil_amounts_merge_to_zero()
  local queue = {
    { kind = "cash_receive" },
    { kind = "cash_receive" },
  }
  _coalesce_head(queue)
  _assert_eq(#queue, 1, "entries should merge")
  _assert_eq(queue[1].amount, 0, "both nil amounts should merge to zero")
  _assert_eq(queue[1].coalesced_count, 2, "coalesced_count should be 2")
end

return {
  name = "action_anim_wait_crap_coverage",
  tests = {
    { name = "_test_empty_queue_noop", run = _test_empty_queue_noop },
    { name = "_test_single_element_queue_noop", run = _test_single_element_queue_noop },
    { name = "_test_head_not_cash_receive_noop", run = _test_head_not_cash_receive_noop },
    { name = "_test_two_cash_receive_merge", run = _test_two_cash_receive_merge },
    { name = "_test_three_cash_receive_merge", run = _test_three_cash_receive_merge },
    { name = "_test_cash_receive_followed_by_different_kind_stops_merge", run = _test_cash_receive_followed_by_different_kind_stops_merge },
    { name = "_test_nil_amount_treated_as_zero", run = _test_nil_amount_treated_as_zero },
    { name = "_test_both_nil_amounts_merge_to_zero", run = _test_both_nil_amounts_merge_to_zero },
  },
}
