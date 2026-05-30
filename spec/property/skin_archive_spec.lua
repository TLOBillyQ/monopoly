---@diagnostic disable: need-check-nil

local property = require("spec.support.property")
local skin_panel = require("src.ui.coord.skin_panel")

-- Round-trip / read-back property for the skin purchase archive: for an arbitrary
-- persisted state (a subset of products owned, plus an optionally-equipped one),
-- opening a fresh panel must reconstruct ownership exactly and auto-equip the
-- archived skin — firing the equip callback so the host restores the model — but
-- only when that skin is actually owned. The example-based behaviour spec pins a
-- few representative cases; this exercises the owned-set seeding and the auto-equip
-- guards across random ownership/equipped combinations.

local PRODUCTS = { 5001, 5002, 5003, 5004, 5005 }

local function _catalog()
  local catalog = {}
  for index, product_id in ipairs(PRODUCTS) do
    catalog[index] = {
      product_id = product_id,
      name = "skin " .. tostring(product_id),
      unlock = "purchase",
      currency = "金豆",
      price = 100 + index,
    }
  end
  return catalog
end

-- Read-only archive port: serves the seeded owned list / equipped product back;
-- the write hooks are inert no-ops since this property only drives the read path.
local function _archive(owned_list, equipped)
  return {
    load_owned = function(_)
      return owned_list
    end,
    load_equipped = function(_)
      return equipped
    end,
    mark_owned = function() end,
    save_equipped = function() end,
  }
end

local function _gen(rng)
  local owned = {}
  for _, product_id in ipairs(PRODUCTS) do
    if rng:bool() then
      owned[#owned + 1] = product_id
    end
  end
  -- Cover all equipped branches: owned, in-catalog-but-unowned, and nil.
  local equipped = nil
  local roll = rng:int(1, 3)
  if roll == 1 and #owned > 0 then
    equipped = owned[rng:int(1, #owned)]
  elseif roll == 2 then
    equipped = PRODUCTS[rng:int(1, #PRODUCTS)]
  end
  return { owned = owned, equipped = equipped }
end

local function _owned_set(list)
  local set = {}
  for _, product_id in ipairs(list) do
    set[product_id] = true
  end
  return set
end

describe("skin archive read-back properties", function()
  after_each(function()
    skin_panel.reset_for_tests()
  end)

  it("open reconstructs ownership and auto-equips only an owned archived skin", function()
    property.for_all(_gen, function(case)
      skin_panel.reset_for_tests()
      skin_panel.configure_catalog_for_tests(_catalog())
      local equip_calls = {}
      skin_panel.configure_equip(function(_, skin)
        equip_calls[#equip_calls + 1] = skin.product_id
        return true
      end)
      skin_panel.configure_archive(_archive(case.owned, case.equipped))

      local panel = skin_panel.open({ ui = {} }, 1)
      local owned_map = panel.owned_by_role["1"] or {}
      local owned_set = _owned_set(case.owned)

      for _, product_id in ipairs(PRODUCTS) do
        assert((owned_map[product_id] == true) == (owned_set[product_id] == true),
          "ownership of " .. tostring(product_id) .. " must match the archive")
      end

      local should_restore = case.equipped ~= nil and owned_set[case.equipped] == true
      if should_restore then
        assert(panel.selected_by_role["1"] == case.equipped,
          "an owned archived equipped skin must be auto-equipped")
        assert(#equip_calls == 1 and equip_calls[1] == case.equipped,
          "auto-equip must fire the equip callback once with the archived skin (model restore)")
      else
        assert(panel.selected_by_role["1"] == nil,
          "no auto-equip when the archived equipped skin is nil or unowned")
        assert(#equip_calls == 0,
          "no equip callback fires when there is nothing to restore")
      end
    end)
  end)
end)
