local support = require("test.support.shared_support")
local _assert_eq = support.assert_eq
local denial = require("src.turn.actions.item_slot_denial")

TestItemSlotDenial = {}

-- choice_offers_item 覆盖（杀掉 options 非 table 时 false→true 幸存者）

function TestItemSlotDenial:test_choice_offers_item_nil_options()
  _assert_eq(denial.choice_offers_item({}, "i1"), false,
    "choice without options field should return false")
end

function TestItemSlotDenial:test_choice_offers_item_non_table_options()
  _assert_eq(denial.choice_offers_item({ options = "not-a-table" }, "i1"), false,
    "non-table options should return false")
end

function TestItemSlotDenial:test_choice_offers_item_found()
  _assert_eq(denial.choice_offers_item({ options = { { id = "i1" } } }, "i1"), true,
    "matching option id should return true")
end

function TestItemSlotDenial:test_choice_offers_item_not_found()
  _assert_eq(denial.choice_offers_item({ options = { { id = "i2" } } }, "i1"), false,
    "non-matching option id should return false")
end

-- unavailable_reason 覆盖（杀掉 _invalid_phase 空字符串→nil + unknown→nil 幸存者）

function TestItemSlotDenial:test_unavailable_reason_empty_phase_returns_unknown()
  local result = denial.unavailable_reason({}, {}, { meta = { phase = "" } }, "i1")
  _assert_eq(result, "unknown", "empty phase should return unknown")
end

function TestItemSlotDenial:test_unavailable_reason_no_meta_returns_unknown()
  local result = denial.unavailable_reason({}, {}, {}, "i1")
  _assert_eq(result, "unknown", "choice without meta should return unknown")
end

return TestItemSlotDenial
