-- Mutation-pinning specs for src/app/cosmetics/transaction_read_model.lua.
-- State shapes kept inline (no shared helpers); each test drives real module
-- behavior and asserts a value that DIFFERS between original and mutant.

local read_model = require("src.app.cosmetics.transaction_read_model")

describe("transaction_read_model.slot_view_model L86/L87/L91/L92 survivors", function()
  -- panel=nil so page_index defaults to 1 and slot_index maps directly to the
  -- catalog index (((1)-1)*6 + slot). We pass an explicit catalog to avoid
  -- coupling to transaction_context.
  local catalog = {
    [3] = { product_id = "prod3", name = "skin3", unlock = "purchase", price = 100, currency = "gold" },
  }

  it("returns integer slot_index and catalog_index for a valid slot (L86 to_integer->nil / or->and, L87 ->nil)", function()
    local vm = read_model.slot_view_model(nil, nil, 3, catalog)
    -- L86 `to_integer(slot_index)` -> nil would yield `nil or 1` = 1.
    -- L86 `or` -> `and` would yield `3 and 1` = 1.
    assert(vm.slot_index == 3,
      "slot_index must echo the resolved integer 3; got " .. tostring(vm.slot_index))
    -- L87 `slot_index(panel, slot_index)` -> nil would yield catalog_index=nil.
    assert(vm.catalog_index == 3,
      "catalog_index must be computed slot index 3; got " .. tostring(vm.catalog_index))
  end)

  it("forwards skin name and unlock when a skin is present (L91 or->and, L92 or->and)", function()
    local vm = read_model.slot_view_model(nil, nil, 3, catalog)
    -- L91 `or` -> `and`: `skin and skin.name and nil` = nil.
    assert(vm.name == "skin3", "name must forward skin.name; got " .. tostring(vm.name))
    -- L92 `or` -> `and`: `skin and skin.unlock and nil` = nil.
    assert(vm.unlock == "purchase", "unlock must forward skin.unlock; got " .. tostring(vm.unlock))
    assert(vm.product_id == "prod3", "product_id sanity check; got " .. tostring(vm.product_id))
  end)

  it("defaults slot_index to 1 (not 0) when the slot is not an integer (L86 literal 1->0)", function()
    -- to_integer(nil) is nil, so the fallback literal is exercised.
    local vm = read_model.slot_view_model(nil, nil, nil, catalog)
    -- L86 `1` -> `0` would yield `nil or 0` = 0.
    assert(vm.slot_index == 1,
      "non-integer slot must default to 1; got " .. tostring(vm.slot_index))
  end)
end)

describe("transaction_read_model.slot_view_models L102 loop-start survivor", function()
  it("builds exactly PAGE_SIZE views starting at index 1 (L102 literal 1->0)", function()
    local views = read_model.slot_view_models(nil, nil, {})
    -- L102 `for slot_index = 1, PAGE_SIZE` -> `0, PAGE_SIZE` would create views[0].
    assert(views[0] == nil, "loop must start at 1, so views[0] must be absent")
    assert(views[1] ~= nil, "views[1] must exist")
    assert(views[1].slot_index == 1, "first view's slot_index must be 1; got " .. tostring(views[1].slot_index))
    assert(views[6] ~= nil, "views[6] (PAGE_SIZE) must exist")
  end)
end)
