local property = require("spec.support.property")
local skin_panel = require("src.ui.coord.skin_panel")
local skin_nodes = require("src.ui.schema.skin")

local PAGE = skin_nodes.page_size

-- Build a catalog of `n` skins with distinct product ids so an equipped product
-- can match at most one slot, and a panel state placed on `page_index` for
-- `role`. `equipped_index` is a global catalog index (or nil for nothing
-- equipped); the panel records its product id under the role key, exactly as
-- _apply_equip / _unequip would.
local function _build_case(rng)
  local n = rng:int(PAGE + 1, PAGE * 4)
  local catalog = {}
  for i = 1, n do
    catalog[i] = { product_id = "p" .. i, name = "皮肤" .. i }
  end
  local pages = math.ceil(n / PAGE)
  local page_index = rng:int(1, pages)
  local role = rng:int(1, 9999)
  local equipped_index = rng:bool() and rng:int(1, n) or nil
  return {
    catalog = catalog,
    n = n,
    page_index = page_index,
    role = role,
    equipped_index = equipped_index,
  }
end

local function _state_for(case, equipped_product)
  return {
    ui = {
      skin_panel = {
        open = true,
        page_index = case.page_index,
        role_id = case.role,
        owned_by_role = {},
        selected_by_role = { [tostring(case.role)] = equipped_product },
      },
    },
  }
end

describe("skin_panel.is_slot_equipped query properties", function()
  after_each(function()
    skin_panel.reset_for_tests()
  end)

  it("reports equipped exactly for the slot showing the equipped product, across any page", function()
    property.for_all(_build_case, function(case)
      skin_panel.reset_for_tests()
      skin_panel.configure_catalog_for_tests(case.catalog)
      local equipped_product = case.equipped_index and case.catalog[case.equipped_index].product_id or nil
      local state = _state_for(case, equipped_product)

      local true_count = 0
      for slot = 1, PAGE do
        local global_index = (case.page_index - 1) * PAGE + slot
        local skin = case.catalog[global_index]
        local expected = skin ~= nil and equipped_product ~= nil and skin.product_id == equipped_product
        local actual = skin_panel.is_slot_equipped(state, slot)
        assert(actual == expected,
          "slot " .. slot .. " (global " .. global_index .. ") equipped expected="
          .. tostring(expected) .. " actual=" .. tostring(actual))
        if actual then
          true_count = true_count + 1
        end
      end

      -- Exclusivity: distinct product ids mean at most one slot per page is equipped.
      assert(true_count <= 1, "at most one slot per page may report equipped")
      local equipped_on_page = case.equipped_index ~= nil
        and math.ceil(case.equipped_index / PAGE) == case.page_index
      assert(true_count == (equipped_on_page and 1 or 0),
        "exactly the equipped slot on the current page must report equipped")
    end)
  end)

  it("equipping then clearing any in-catalog slot toggles that slot's equipped state", function()
    property.for_all(_build_case, function(case, rng)
      skin_panel.reset_for_tests()
      skin_panel.configure_catalog_for_tests(case.catalog)

      -- Pick a slot on the current page that actually maps to a catalog skin.
      local max_slot_on_page = math.min(PAGE, case.n - (case.page_index - 1) * PAGE)
      if max_slot_on_page < 1 then
        return
      end
      local slot = rng:int(1, max_slot_on_page)
      local skin = case.catalog[(case.page_index - 1) * PAGE + slot]

      local equipped_state = _state_for(case, skin.product_id)
      assert(skin_panel.is_slot_equipped(equipped_state, slot) == true,
        "a slot whose product is selected must report equipped")

      local cleared_state = _state_for(case, nil)
      assert(skin_panel.is_slot_equipped(cleared_state, slot) == false,
        "clearing the selection must make every slot report not equipped")
    end)
  end)

  it("reports not equipped for every slot when the panel has no owner role", function()
    property.for_all(_build_case, function(case)
      skin_panel.reset_for_tests()
      skin_panel.configure_catalog_for_tests(case.catalog)
      local equipped_product = case.equipped_index and case.catalog[case.equipped_index].product_id or nil
      local state = _state_for(case, equipped_product)
      state.ui.skin_panel.role_id = nil

      for slot = 1, PAGE do
        assert(skin_panel.is_slot_equipped(state, slot) == false,
          "no owner role must short-circuit to not equipped for slot " .. slot)
      end
    end)
  end)
end)
