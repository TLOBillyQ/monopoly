-- item_slots_options(#340):build(choice) 无效 choice 分支必须清空模块级缓存,
-- 否则上一条 choice 的可选项永久残留 → 外框 visible 永挂(真机 2026-08-04 实证)。
local lu = require("luaunit")
local item_options = require("src.ui.coord.item_slots_options")

local function _ids(set)
  local ids = {}
  for k in pairs(set) do
    ids[#ids + 1] = k
  end
  table.sort(ids)
  return table.concat(ids, ",")
end

TestItemSlotsOptions = {}

function TestItemSlotsOptions:test_build_nil_returns_empty_set()
  lu.assertEvalToTrue(_ids(item_options.build(nil)) == "",
    "build(nil) must yield an empty option id set")
end

function TestItemSlotsOptions:test_build_choice_without_options_returns_empty_set()
  lu.assertEvalToTrue(_ids(item_options.build({ id = "c1" })) == "",
    "a choice without an options table must yield an empty set")
  lu.assertEvalToTrue(_ids(item_options.build({ id = "c2", options = "not a table" })) == "",
    "a choice with non-table options must yield an empty set")
end

function TestItemSlotsOptions:test_build_nil_after_filled_choice_clears_stale_ids()
  -- 回归主断言(#340):choice 清空(回合推进)后 build(nil) 不得残留上一条的可选项。
  item_options.build({
    id = "c1",
    options = { { id = "item_a" }, { id = "item_b" } },
  })
  lu.assertEvalToTrue(_ids(item_options.build(nil)) == "",
    "build(nil) after a filled choice must not leak the previous option ids")
end

function TestItemSlotsOptions:test_build_same_options_ref_rebuilds_after_invalid_choice()
  -- 无效 choice 分支把 _cached_option_choice_ref 置 nil,同一 options 表引用再次
  -- 传入时必须重新填充,不得被「引用相同」短路跳过重建。
  local options = { { id = "item_a" }, { id = "item_b" } }
  item_options.build({ id = "c1", options = options })
  item_options.build(nil)
  local set = item_options.build({ id = "c2", options = options })
  lu.assertEvalToTrue(_ids(set) == "item_a,item_b",
    "the same options ref must be rebuilt after an invalid choice cleared the cache")
end

return TestItemSlotsOptions
