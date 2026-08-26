-- Mutation-pinning specs for src/app/cosmetics/transaction_read_model.lua.
-- State shapes kept inline (no shared helpers); each test drives real module
-- behavior and asserts a value that DIFFERS between original and mutant.
--
-- 原生 LuaUnit 改写:两个无钩子 describe 合并为文件级 TestTransactionReadModelMutation
-- 单类(describe 无钩子 → 不拆类);describe 级 local catalog 原样留在 do 块内;
-- 语句位裸 assert → lu.assertEvalToTrue。用例数与改写前一一对应(4 例)。

local lu = require("luaunit")
local read_model = require("src.app.cosmetics.transaction_read_model")

TestTransactionReadModelMutation = {}

do
  -- panel=nil so page_index defaults to 1 and slot_index maps directly to the
  -- catalog index (((1)-1)*6 + slot). We pass an explicit catalog to avoid
  -- coupling to transaction_context.
  local catalog = {
    [3] = { product_id = "prod3", name = "skin3", unlock = "purchase", price = 100, currency = "gold" },
  }

  function TestTransactionReadModelMutation:test_returns_integer_slot_index_and_catalog_index_for_a_valid_slot_L86_to_integer_nil_or_and_L87_nil()
    local vm = read_model.slot_view_model(nil, nil, 3, catalog)
    -- L86 `to_integer(slot_index)` -> nil would yield `nil or 1` = 1.
    -- L86 `or` -> `and` would yield `3 and 1` = 1.
    lu.assertEvalToTrue(vm.slot_index == 3,
      "slot_index must echo the resolved integer 3; got " .. tostring(vm.slot_index))
    -- L87 `slot_index(panel, slot_index)` -> nil would yield catalog_index=nil.
    lu.assertEvalToTrue(vm.catalog_index == 3,
      "catalog_index must be computed slot index 3; got " .. tostring(vm.catalog_index))
  end

  function TestTransactionReadModelMutation:test_forwards_skin_name_and_unlock_when_a_skin_is_present_L91_or_and_L92_or_and()
    local vm = read_model.slot_view_model(nil, nil, 3, catalog)
    -- L91 `or` -> `and`: `skin and skin.name and nil` = nil.
    lu.assertEvalToTrue(vm.name == "skin3", "name must forward skin.name; got " .. tostring(vm.name))
    -- L92 `or` -> `and`: `skin and skin.unlock and nil` = nil.
    lu.assertEvalToTrue(vm.unlock == "purchase", "unlock must forward skin.unlock; got " .. tostring(vm.unlock))
    lu.assertEvalToTrue(vm.product_id == "prod3", "product_id sanity check; got " .. tostring(vm.product_id))
  end

  function TestTransactionReadModelMutation:test_defaults_slot_index_to_1_not_0_when_the_slot_is_not_an_integer_L86_literal_1_0()
    -- to_integer(nil) is nil, so the fallback literal is exercised.
    local vm = read_model.slot_view_model(nil, nil, nil, catalog)
    -- L86 `1` -> `0` would yield `nil or 0` = 0.
    lu.assertEvalToTrue(vm.slot_index == 1,
      "non-integer slot must default to 1; got " .. tostring(vm.slot_index))
  end
end

function TestTransactionReadModelMutation:test_builds_exactly_PAGE_SIZE_views_starting_at_index_1_L102_literal_1_0()
  local views = read_model.slot_view_models(nil, nil, {})
  -- L102 `for slot_index = 1, PAGE_SIZE` -> `0, PAGE_SIZE` would create views[0].
  lu.assertEvalToTrue(views[0] == nil, "loop must start at 1, so views[0] must be absent")
  lu.assertEvalToTrue(views[1] ~= nil, "views[1] must exist")
  lu.assertEvalToTrue(views[1].slot_index == 1, "first view's slot_index must be 1; got " .. tostring(views[1].slot_index))
  lu.assertEvalToTrue(views[6] ~= nil, "views[6] (PAGE_SIZE) must exist")
end

function TestTransactionReadModelMutation:test_resolves_role_id_through_panel_owner_fallback_L108_or_and()
  -- L108 `role_id or (panel and panel.role_id)` -> `role_id and (panel and panel.role_id)`:
  -- with role_id=nil the mutant yields nil and the slot degrades to "locked".
  local catalog = {
    [3] = { product_id = "prod3", name = "skin3", unlock = "purchase", price = 100, currency = "gold" },
  }
  local panel = {
    role_id = "r1",
    owned_by_role = { r1 = { prod3 = true } },
    selected_by_role = { r1 = "prod3" },
  }
  local vm = read_model.slot_view_model(panel, nil, 3, catalog)
  lu.assertEvalToTrue(vm.status == "equipped",
    "panel.role_id fallback must drive the status; got " .. tostring(vm.status))
end


return TestTransactionReadModelMutation
