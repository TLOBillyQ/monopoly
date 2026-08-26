-- event_kinds 常量完整性 pin:#293 复核——8 个常量被 nil 替换存活,根因是
-- 没有任何测试迭代过整张配置表。结构性断言(每个 kind 都是非空字符串)
-- 一次性击杀全部 nil 替换位点。
local lu = require("luaunit")

local event_kinds = require("src.config.gameplay.event_kinds")

local function _assert_eq(actual, expected)
  lu.assertEvalToTrue(actual == expected,
    "kind should keep its canonical name; expected " .. tostring(expected)
      .. " got " .. tostring(actual))
end

TestEventKindsPin = {}

function TestEventKindsPin:test_every_kind_is_a_non_empty_string()
  for name, value in pairs(event_kinds) do
    lu.assertEvalToTrue(type(value) == "string" and value ~= "",
      name .. " should map to a non-empty string kind, got " .. tostring(value))
  end
end

function TestEventKindsPin:test_known_kinds_keep_their_canonical_names()
  _assert_eq(event_kinds.tax_immune, "tax_immune")
  _assert_eq(event_kinds.bankruptcy_liquidation, "bankruptcy_liquidation")
  _assert_eq(event_kinds.item_used, "item_used")
  _assert_eq(event_kinds.tax_card, "tax_card")
  _assert_eq(event_kinds.deity_evicted, "deity_evicted")
  _assert_eq(event_kinds.deity_transferred, "deity_transferred")
  _assert_eq(event_kinds.deity_attached, "deity_attached")
  _assert_eq(event_kinds.equality_card, "equality_card")
end

return TestEventKindsPin
