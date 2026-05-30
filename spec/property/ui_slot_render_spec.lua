local property = require("spec.support.property")
local item_atlas_nodes = require("src.ui.schema.item_atlas")
local item_atlas_view = require("src.ui.render.item_atlas")
local skin_nodes = require("src.ui.schema.skin")
local skin_panel_view = require("src.ui.render.skin_panel")

local function _find_call(calls, method, name)
  for i = #calls, 1, -1 do
    local call = calls[i]
    if call[1] == method and call[2] == name then
      return call[3]
    end
  end
  return nil
end

local function _make_render_state(panel)
  local calls = {}
  local state = {
    ui = {
      skin_panel = panel,
      set_button = function(_, name, text)
        calls[#calls + 1] = { "set_button", name, text }
      end,
      set_touch_enabled = function(_, name, enabled)
        calls[#calls + 1] = { "set_touch_enabled", name, enabled }
      end,
      set_visible = function(_, name, visible)
        calls[#calls + 1] = { "set_visible", name, visible }
      end,
    },
  }
  return state, calls
end

local function _make_item_catalog(size)
  local catalog = {}
  for i = 1, size do
    catalog[i] = { id = "item_" .. tostring(i), name = "item " .. tostring(i) }
  end
  return catalog
end

local function _make_skin_catalog(size)
  local catalog = {}
  for i = 1, size do
    catalog[i] = {
      product_id = i,
      name = "skin " .. tostring(i),
      unlock = i % 2 == 0 and "gift" or "purchase",
      gift_name = "gift " .. tostring(i),
      currency = "gold",
      price = 100 + i,
    }
  end
  return catalog
end

local function _page_limit(size, page_size)
  local page_count = math.max(1, math.ceil(size / page_size))
  return page_count + 1
end

describe("ui slot render properties", function()
  it("item atlas card visibility and touch follow catalog slots", function()
    property.check_int_range(0, 17, function(size)
      local catalog = _make_item_catalog(size)
      for page_index = 1, _page_limit(size, #item_atlas_nodes.card_images) do
        local state, calls = _make_render_state()
        item_atlas_view.refresh_page(state, catalog, page_index)

        local offset = (page_index - 1) * #item_atlas_nodes.card_images
        for slot, node_name in ipairs(item_atlas_nodes.card_images) do
          local has_item = catalog[offset + slot] ~= nil
          assert(_find_call(calls, "set_visible", node_name) == has_item,
            "item atlas slot " .. tostring(slot) .. " visibility should match catalog presence")
          assert(_find_call(calls, "set_touch_enabled", node_name) == has_item,
            "item atlas slot " .. tostring(slot) .. " touch should match catalog presence")
        end
      end
    end)
  end)

  it("skin panel empty slots clear visible and touch state", function()
    property.check_int_range(0, 13, function(size)
      local catalog = _make_skin_catalog(size)
      for page_index = 1, _page_limit(size, #skin_nodes.card_images) do
        local panel = {
          page_index = page_index,
          role_id = 1,
          owned_by_role = { ["1"] = {} },
          selected_by_role = { ["1"] = nil },
        }
        local state, calls = _make_render_state(panel)
        skin_panel_view.refresh_slots(state, catalog)

        local offset = (page_index - 1) * #skin_nodes.card_images
        for slot, node_name in ipairs(skin_nodes.card_images) do
          local has_skin = catalog[offset + slot] ~= nil
          assert(_find_call(calls, "set_visible", node_name) == has_skin,
            "skin slot " .. tostring(slot) .. " visibility should match catalog presence")
          assert(_find_call(calls, "set_touch_enabled", node_name) == has_skin,
            "skin slot " .. tostring(slot) .. " touch should match catalog presence")
          assert(_find_call(calls, "set_visible", skin_nodes.card_outlines[slot]) == has_skin,
            "skin slot " .. tostring(slot) .. " outline container visibility should match catalog presence")
          assert(_find_call(calls, "set_touch_enabled", skin_nodes.card_outlines[slot]) == false,
            "skin slot " .. tostring(slot) .. " outline container touch should stay disabled")
          if not has_skin then
            assert(_find_call(calls, "set_button", skin_nodes.action_buttons[slot]) == "",
              "empty skin slot " .. tostring(slot) .. " should clear button text")
            assert(_find_call(calls, "set_touch_enabled", skin_nodes.action_buttons[slot]) == false,
              "empty skin slot " .. tostring(slot) .. " action button touch should be disabled")
            assert(_find_call(calls, "set_visible", skin_nodes.price_icons[slot]) == false,
              "empty skin slot " .. tostring(slot) .. " should hide price icon")
          end
        end
      end
    end)
  end)

  -- The price icon is shown only for a present purchase skin that still carries a
  -- price/currency AND that the role does not yet own; owning it (whether equipped
  -- or not) hides the icon, and non-purchase skins never show it. Random ownership
  -- and equip configurations exercise the owned/equipped/unowned mix per slot.
  it("price icon shows only for unowned priced purchase skins", function()
    local SLOTS = #skin_nodes.card_images
    property.for_all(function(rng)
      local size = rng:int(1, SLOTS)
      local owned = {}
      local owned_ids = {}
      for product_id = 1, size do
        if rng:bool() then
          owned[product_id] = true
          owned_ids[#owned_ids + 1] = product_id
        end
      end
      local equipped = nil
      if #owned_ids > 0 and rng:bool() then
        equipped = owned_ids[rng:int(1, #owned_ids)]
      end
      return { size = size, owned = owned, equipped = equipped }
    end, function(case)
      local catalog = _make_skin_catalog(case.size)
      local panel = {
        page_index = 1,
        role_id = 1,
        owned_by_role = { ["1"] = case.owned },
        selected_by_role = { ["1"] = case.equipped },
      }
      local state, calls = _make_render_state(panel)
      skin_panel_view.refresh_slots(state, catalog)

      for slot = 1, case.size do
        local skin = catalog[slot]
        local is_owned = case.owned[skin.product_id] == true
        local is_priced_purchase = skin.unlock == "purchase"
          and skin.price ~= nil and skin.currency ~= nil
        local expected_visible = is_priced_purchase and not is_owned
        assert(_find_call(calls, "set_visible", skin_nodes.price_icons[slot]) == expected_visible,
          "slot " .. tostring(slot) .. " price icon visibility must be (priced purchase AND not owned)")
      end
    end)
  end)
end)
