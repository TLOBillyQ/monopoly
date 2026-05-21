local support = require("spec.support.shared_support")
local _with_patches = support.with_patches
local _build_role_with_events = support.build_role_with_events
local _has_event = support.has_event
local skin_panel = require("src.ui.coord.skin_panel")
local skin_panel_view = require("src.ui.render.skin_panel")
local skin_nodes = require("src.ui.schema.skin")
local runtime_ports = require("src.foundation.ports.runtime_ports")

local function _make_state()
  return { ui = {} }
end

local function _make_catalog(n)
  local t = {}
  for i = 1, n do
    t[i] = { product_id = "skin_" .. i, name = "皮肤" .. i }
  end
  return t
end

local function _make_rich_catalog()
  return {
    { product_id = 5001, name = "小猪佩奇", unlock = "purchase", currency = "金豆", price = 198 },
    { product_id = 5002, name = "海绵宝宝", unlock = "purchase", currency = "金豆", price = 198 },
    { product_id = 5003, name = "奶龙", unlock = "gift", gift_name = "谢礼" },
  }
end

local function _make_render_state(panel_overrides)
  local calls = {}
  local panel = {
    role_id = 1,
    page_index = 1,
    owned_by_role = {},
    selected_by_role = {},
  }
  if panel_overrides then
    for k, v in pairs(panel_overrides) do
      panel[k] = v
    end
  end
  local state = {
    ui = {
      skin_panel = panel,
      set_button = function(_, name, text)
        calls[#calls + 1] = { "set_button", name, text }
      end,
      set_visible = function(_, name, visible)
        calls[#calls + 1] = { "set_visible", name, visible }
      end,
      set_touch_enabled = function(_, name, enabled)
        calls[#calls + 1] = { "set_touch_enabled", name, enabled }
      end,
    },
  }
  return state, calls
end

local function _find_call(calls, method, name)
  for i = #calls, 1, -1 do
    local c = calls[i]
    if c[1] == method and c[2] == name then
      return c[3]
    end
  end
  return nil
end

describe("skin_panel", function()
  before_each(function()
    skin_panel.reset_for_tests()
  end)

  describe("open/close", function()
    it("marks panel open after open()", function()
      local s = _make_state()
      local panel = skin_panel.open(s, 1)
      assert(panel.open == true, "panel should be open")
    end)

    it("opens the skin canvas for the active role", function()
      local events = {}
      local role = _build_role_with_events(1, events)
      local s = _make_state()

      _with_patches({
        { target = runtime_ports, key = "resolve_role", value = function(role_id)
          if role_id == 1 then
            return role
          end
          return nil
        end },
      }, function()
        skin_panel.open(s, 1)
      end)

      assert(_has_event(events, "显示皮肤商店"), "opening skin panel should show skin canvas")
    end)

    it("stores role_id on open", function()
      local s = _make_state()
      local panel = skin_panel.open(s, 2)
      assert(panel.role_id == 2, "role_id should be stored")
    end)

    it("marks panel closed after close()", function()
      local s = _make_state()
      skin_panel.open(s, 1)
      local panel = skin_panel.close(s)
      assert(panel.open == false, "panel should be closed")
    end)

    it("closes the skin canvas for the active role", function()
      local events = {}
      local role = _build_role_with_events(1, events)
      local s = _make_state()

      _with_patches({
        { target = runtime_ports, key = "resolve_role", value = function(role_id)
          if role_id == 1 then
            return role
          end
          return nil
        end },
      }, function()
        skin_panel.open(s, 1)
        skin_panel.handle_action(s, "close", 1)
      end)

      assert(_has_event(events, "隐藏皮肤商店"), "closing skin panel should hide skin canvas")
    end)
  end)

  describe("catalog injection", function()
    it("configure_catalog_for_tests replaces active catalog", function()
      local cat = _make_catalog(3)
      skin_panel.configure_catalog_for_tests(cat)
      assert(#skin_panel.catalog == 3, "catalog size should be 3")
    end)

    it("reset_for_tests restores default catalog", function()
      skin_panel.configure_catalog_for_tests(_make_catalog(2))
      skin_panel.reset_for_tests()
      assert(#skin_panel.catalog == 6, "default catalog has 6 skins")
    end)

    it("page shows correct slot count with injected 3-skin catalog", function()
      skin_panel.configure_catalog_for_tests(_make_catalog(3))
      local s = _make_state()
      skin_panel.open(s, 1)
      local panel = s.ui.skin_panel
      local count = 0
      for i = 1, 6 do
        local idx = (panel.page_index - 1) * 6 + i
        if skin_panel.catalog[idx] then count = count + 1 end
      end
      assert(count == 3, "3-skin catalog should show 3 slots, got " .. tostring(count))
    end)

    it("page shows correct slot count with injected 6-skin catalog", function()
      skin_panel.configure_catalog_for_tests(_make_catalog(6))
      local s = _make_state()
      skin_panel.open(s, 1)
      local panel = s.ui.skin_panel
      local count = 0
      for i = 1, 6 do
        local idx = (panel.page_index - 1) * 6 + i
        if skin_panel.catalog[idx] then count = count + 1 end
      end
      assert(count == 6, "6-skin catalog should show 6 slots, got " .. tostring(count))
    end)
  end)

  describe("unlock and equip", function()
    it("unlock marks skin as owned for role", function()
      skin_panel.configure_catalog_for_tests(_make_catalog(3))
      local s = _make_state()
      skin_panel.open(s, 1)
      skin_panel.unlock(s, 1, "buy", 1)
      local panel = s.ui.skin_panel
      assert(panel.owned_by_role["1"]["skin_1"] == true, "slot 1 skin should be owned by role 1")
    end)

    it("equip succeeds when skin is owned", function()
      skin_panel.configure_catalog_for_tests(_make_catalog(3))
      local s = _make_state()
      skin_panel.open(s, 1)
      skin_panel.unlock(s, 1, "buy", 1)
      skin_panel.equip(s, 1, 1)
      local panel = s.ui.skin_panel
      assert(panel.selected_by_role["1"] == "skin_1", "skin_1 should be selected after equip")
    end)

    it("equip fails when skin is not owned", function()
      skin_panel.configure_catalog_for_tests(_make_catalog(3))
      local s = _make_state()
      skin_panel.open(s, 1)
      skin_panel.equip(s, 1, 1)
      local panel = s.ui.skin_panel
      assert(panel.selected_by_role["1"] == nil, "equip should fail for unowned skin")
    end)

    it("equip at slot 3 selects skin_3", function()
      skin_panel.configure_catalog_for_tests(_make_catalog(3))
      local s = _make_state()
      skin_panel.open(s, 1)
      skin_panel.unlock(s, 1, "buy", 3)
      skin_panel.equip(s, 1, 3)
      local panel = s.ui.skin_panel
      assert(panel.selected_by_role["1"] == "skin_3", "slot 3 should equip skin_3")
    end)

    it("gift unlock marks skin as owned", function()
      skin_panel.configure_catalog_for_tests(_make_catalog(5))
      local s = _make_state()
      skin_panel.open(s, 1)
      skin_panel.unlock(s, 1, "gift", 2)
      local panel = s.ui.skin_panel
      assert(panel.owned_by_role["1"]["skin_2"] == true, "gift unlock should own skin_2")
    end)

    it("unequip clears selected skin for role", function()
      skin_panel.configure_catalog_for_tests(_make_catalog(5))
      local s = _make_state()
      skin_panel.open(s, 1)
      skin_panel.unlock(s, 1, "buy", 1)
      skin_panel.equip(s, 1, 1)
      assert(s.ui.skin_panel.selected_by_role["1"] == "skin_1")
      skin_panel.handle_action(s, "unequip", 1)
      assert(s.ui.skin_panel.selected_by_role["1"] == nil, "unequip should clear selection")
    end)
  end)

  describe("pagination", function()
    it("next action advances page_index when multiple pages exist", function()
      skin_panel.configure_catalog_for_tests(_make_catalog(12))
      local s = _make_state()
      skin_panel.open(s, 1)
      skin_panel.handle_action(s, "next", 1)
      assert(s.ui.skin_panel.page_index == 2, "next should advance to page 2")
    end)

    it("next action clamps to max page on single-page catalog", function()
      skin_panel.configure_catalog_for_tests(_make_catalog(6))
      local s = _make_state()
      skin_panel.open(s, 1)
      skin_panel.handle_action(s, "next", 1)
      skin_panel.handle_action(s, "next", 1)
      assert(s.ui.skin_panel.page_index == 1, "single-page catalog should clamp to page 1")
    end)

    it("prev action goes to previous page", function()
      skin_panel.configure_catalog_for_tests(_make_catalog(12))
      local s = _make_state()
      skin_panel.open(s, 1)
      skin_panel.handle_action(s, "next", 1)
      assert(s.ui.skin_panel.page_index == 2)
      skin_panel.handle_action(s, "prev", 1)
      assert(s.ui.skin_panel.page_index == 1, "prev should return to page 1")
    end)

    it("prev action does not go below page 1", function()
      skin_panel.configure_catalog_for_tests(_make_catalog(12))
      local s = _make_state()
      skin_panel.open(s, 1)
      skin_panel.handle_action(s, "prev", 1)
      assert(s.ui.skin_panel.page_index == 1, "prev on page 1 should stay at 1")
    end)
  end)

  describe("handle_action", function()
    it("buy action directly unlocks skin", function()
      skin_panel.configure_catalog_for_tests(_make_catalog(3))
      local s = _make_state()
      skin_panel.open(s, 1)
      skin_panel.handle_action(s, { type = "buy", slot_index = 2 }, 1)
      local panel = s.ui.skin_panel
      assert(panel.owned_by_role["1"]["skin_2"] == true, "buy action should own skin_2")
    end)

    it("close action closes panel", function()
      local s = _make_state()
      skin_panel.open(s, 1)
      skin_panel.handle_action(s, "close", 1)
      assert(s.ui.skin_panel.open == false, "close action should close panel")
    end)

    it("gift action unlocks skin via handle_action", function()
      skin_panel.configure_catalog_for_tests(_make_catalog(3))
      local s = _make_state()
      skin_panel.open(s, 1)
      skin_panel.handle_action(s, { type = "gift", slot_index = 1 }, 1)
      assert(s.ui.skin_panel.owned_by_role["1"]["skin_1"] == true, "gift action should own skin")
    end)

    it("equip action equips owned skin via handle_action", function()
      skin_panel.configure_catalog_for_tests(_make_catalog(3))
      local s = _make_state()
      skin_panel.open(s, 1)
      skin_panel.unlock(s, 1, "buy", 2)
      skin_panel.handle_action(s, { type = "equip", slot_index = 2 }, 1)
      assert(s.ui.skin_panel.selected_by_role["1"] == "skin_2", "equip action should select skin")
    end)

    it("integer action equips owned skin as slot index", function()
      skin_panel.configure_catalog_for_tests(_make_catalog(3))
      local s = _make_state()
      skin_panel.open(s, 1)
      skin_panel.unlock(s, 1, "buy", 1)
      skin_panel.handle_action(s, 1, 1)
      assert(s.ui.skin_panel.selected_by_role["1"] == "skin_1", "integer action should equip slot")
    end)
  end)

  describe("button rendering", function()
    it("locked purchase skin shows price text on button", function()
      local catalog = _make_rich_catalog()
      local state, calls = _make_render_state()
      skin_panel_view.refresh_slots(state, catalog)
      local text = _find_call(calls, "set_button", skin_nodes.action_buttons[1])
      assert(text == "198 金豆", "locked purchase button should show price, got: " .. tostring(text))
    end)

    it("locked gift skin shows gift_name on button", function()
      local catalog = _make_rich_catalog()
      local state, calls = _make_render_state()
      skin_panel_view.refresh_slots(state, catalog)
      local text = _find_call(calls, "set_button", skin_nodes.action_buttons[3])
      assert(text == "谢礼", "locked gift button should show gift_name, got: " .. tostring(text))
    end)

    it("locked purchase skin button is touch-enabled for buying", function()
      local catalog = _make_rich_catalog()
      local state, calls = _make_render_state()
      skin_panel_view.refresh_slots(state, catalog)
      local enabled = _find_call(calls, "set_touch_enabled", skin_nodes.action_buttons[1])
      assert(enabled == true, "locked purchase button should be touch-enabled")
    end)

    it("locked gift skin button is not touch-enabled", function()
      local catalog = _make_rich_catalog()
      local state, calls = _make_render_state()
      skin_panel_view.refresh_slots(state, catalog)
      local enabled = _find_call(calls, "set_touch_enabled", skin_nodes.action_buttons[3])
      assert(enabled == false, "locked gift button should be touch-disabled")
    end)

    it("owned unequipped skin shows 穿上 on button", function()
      local catalog = _make_rich_catalog()
      local state, calls = _make_render_state({
        owned_by_role = { ["1"] = { [5001] = true } },
      })
      skin_panel_view.refresh_slots(state, catalog)
      local text = _find_call(calls, "set_button", skin_nodes.action_buttons[1])
      assert(text == "穿上", "owned button should show 穿上, got: " .. tostring(text))
    end)

    it("owned unequipped skin button is touch-enabled", function()
      local catalog = _make_rich_catalog()
      local state, calls = _make_render_state({
        owned_by_role = { ["1"] = { [5001] = true } },
      })
      skin_panel_view.refresh_slots(state, catalog)
      local enabled = _find_call(calls, "set_touch_enabled", skin_nodes.action_buttons[1])
      assert(enabled == true, "owned button should be touch-enabled")
    end)

    it("equipped skin shows 已穿戴 on button", function()
      local catalog = _make_rich_catalog()
      local state, calls = _make_render_state({
        owned_by_role = { ["1"] = { [5001] = true } },
        selected_by_role = { ["1"] = 5001 },
      })
      skin_panel_view.refresh_slots(state, catalog)
      local text = _find_call(calls, "set_button", skin_nodes.action_buttons[1])
      assert(text == "已穿戴", "equipped button should show 已穿戴, got: " .. tostring(text))
    end)

    it("equipped skin button is not touch-enabled", function()
      local catalog = _make_rich_catalog()
      local state, calls = _make_render_state({
        owned_by_role = { ["1"] = { [5001] = true } },
        selected_by_role = { ["1"] = 5001 },
      })
      skin_panel_view.refresh_slots(state, catalog)
      local enabled = _find_call(calls, "set_touch_enabled", skin_nodes.action_buttons[1])
      assert(enabled == false, "equipped button should be touch-disabled")
    end)

    it("outline visible only for equipped skin slot", function()
      local catalog = _make_rich_catalog()
      local state, calls = _make_render_state({
        owned_by_role = { ["1"] = { [5002] = true } },
        selected_by_role = { ["1"] = 5002 },
      })
      skin_panel_view.refresh_slots(state, catalog)
      local outline1 = _find_call(calls, "set_visible", skin_nodes.card_outlines[1])
      local outline2 = _find_call(calls, "set_visible", skin_nodes.card_outlines[2])
      local outline3 = _find_call(calls, "set_visible", skin_nodes.card_outlines[3])
      assert(outline1 == false, "non-equipped outline should be hidden")
      assert(outline2 == true, "equipped outline should be visible")
      assert(outline3 == false, "non-equipped outline should be hidden")
    end)

    it("no outline visible when nothing equipped", function()
      local catalog = _make_rich_catalog()
      local state, calls = _make_render_state()
      skin_panel_view.refresh_slots(state, catalog)
      for slot = 1, 3 do
        local vis = _find_call(calls, "set_visible", skin_nodes.card_outlines[slot])
        assert(vis == false, "outline " .. slot .. " should be hidden when nothing equipped")
      end
    end)

    it("sets card texture when image ref exists", function()
      local catalog = _make_rich_catalog()
      local state, _ = _make_render_state()
      state.ui_refs = { images = { ["5001"] = "tex_pig" } }
      local textures = {}
      local runtime = {
        query_node = function(name) return { name = name } end,
        set_node_texture_keep_size = function(node, key)
          textures[node.name] = key
        end,
      }
      skin_panel_view.refresh_slots(state, catalog, { runtime = runtime })
      assert(textures[skin_nodes.card_images[1]] == "tex_pig",
        "should set texture for skin with image ref")
      assert(textures[skin_nodes.card_images[2]] == nil,
        "should not set texture for skin without image ref")
    end)

    it("price icon visible for purchase skin, hidden for gift skin", function()
      local catalog = _make_rich_catalog()
      local state, calls = _make_render_state()
      skin_panel_view.refresh_slots(state, catalog)
      local purchase_icon = _find_call(calls, "set_visible", skin_nodes.price_icons[1])
      local gift_icon = _find_call(calls, "set_visible", skin_nodes.price_icons[3])
      assert(purchase_icon == true, "purchase skin should show price icon")
      assert(gift_icon == false, "gift skin should hide price icon")
    end)

    it("shows all 6 card images for a full first page", function()
      local catalog = _make_catalog(6)
      local state, calls = _make_render_state()
      skin_panel_view.refresh_slots(state, catalog)
      for slot = 1, 6 do
        local vis = _find_call(calls, "set_visible", skin_nodes.card_images[slot])
        assert(vis == true, "slot " .. slot .. " card image should be visible")
      end
    end)

    it("hides trailing empty card slots when catalog smaller than page size", function()
      local catalog = _make_catalog(3)
      local state, calls = _make_render_state()
      skin_panel_view.refresh_slots(state, catalog)
      for slot = 1, 3 do
        local vis = _find_call(calls, "set_visible", skin_nodes.card_images[slot])
        assert(vis == true, "slot " .. slot .. " card image should be visible")
      end
      for slot = 4, 6 do
        local vis = _find_call(calls, "set_visible", skin_nodes.card_images[slot])
        assert(vis == false, "slot " .. slot .. " card image should be hidden (no skin)")
      end
    end)

    it("page 2 renders offset card slots from full catalog", function()
      local catalog = _make_catalog(12)
      local state, _ = _make_render_state({ page_index = 2 })
      state.ui_refs = { images = {} }
      for i = 1, 12 do
        state.ui_refs.images["skin_" .. i] = "tex_" .. i
      end
      local textures = {}
      local runtime = {
        query_node = function(name) return { name = name } end,
        set_node_texture_keep_size = function(node, key)
          textures[node.name] = key
        end,
      }
      skin_panel_view.refresh_slots(state, catalog, { runtime = runtime })
      assert(textures[skin_nodes.card_images[1]] == "tex_7",
        "page 2 slot 1 should render skin_7 texture, got " .. tostring(textures[skin_nodes.card_images[1]]))
      assert(textures[skin_nodes.card_images[6]] == "tex_12",
        "page 2 slot 6 should render skin_12 texture, got " .. tostring(textures[skin_nodes.card_images[6]]))
    end)

    it("page 2 hides trailing empty slots when last page partially fills", function()
      local catalog = _make_catalog(8)
      local state, calls = _make_render_state({ page_index = 2 })
      skin_panel_view.refresh_slots(state, catalog)
      for slot = 1, 2 do
        local vis = _find_call(calls, "set_visible", skin_nodes.card_images[slot])
        assert(vis == true, "page 2 slot " .. slot .. " card image should be visible")
      end
      for slot = 3, 6 do
        local vis = _find_call(calls, "set_visible", skin_nodes.card_images[slot])
        assert(vis == false, "page 2 slot " .. slot .. " card image should be hidden")
      end
    end)
  end)

  describe("purchase flow", function()
    it("equip on locked purchase skin calls purchase handler", function()
      local catalog = _make_rich_catalog()
      skin_panel.configure_catalog_for_tests(catalog)
      local purchase_calls = {}
      skin_panel.configure_purchase(function(role_id, skin)
        purchase_calls[#purchase_calls + 1] = { role_id = role_id, product_id = skin.product_id }
        return true
      end)
      local s = _make_state()
      skin_panel.open(s, 1)
      skin_panel.equip(s, 1, 1)
      assert(#purchase_calls == 1, "should call purchase handler once, got " .. #purchase_calls)
      assert(purchase_calls[1].product_id == 5001, "should pass correct product_id")
      assert(purchase_calls[1].role_id == 1, "should pass correct role_id")
    end)

    it("equip on locked gift skin does not call purchase handler", function()
      local catalog = _make_rich_catalog()
      skin_panel.configure_catalog_for_tests(catalog)
      local purchase_calls = {}
      skin_panel.configure_purchase(function(role_id, skin)
        purchase_calls[#purchase_calls + 1] = { role_id = role_id, product_id = skin.product_id }
        return true
      end)
      local s = _make_state()
      skin_panel.open(s, 1)
      skin_panel.equip(s, 1, 3)
      assert(#purchase_calls == 0, "gift skin should not trigger purchase")
    end)

    it("purchase success unlocks and selects skin", function()
      local catalog = _make_rich_catalog()
      skin_panel.configure_catalog_for_tests(catalog)
      local captured_on_success = nil
      skin_panel.configure_purchase(function(_, _, on_success)
        captured_on_success = on_success
        return true
      end)
      local s = _make_state()
      skin_panel.open(s, 1)
      skin_panel.equip(s, 1, 1)
      assert(captured_on_success ~= nil, "should provide on_success callback")
      captured_on_success()
      local panel = s.ui.skin_panel
      assert(panel.owned_by_role["1"][5001] == true, "skin should be owned after purchase success")
      assert(panel.selected_by_role["1"] == 5001, "skin should be selected after purchase success")
    end)

    it("equip on owned skin still equips normally without purchase handler", function()
      local catalog = _make_rich_catalog()
      skin_panel.configure_catalog_for_tests(catalog)
      local purchase_calls = {}
      skin_panel.configure_purchase(function(role_id, skin)
        purchase_calls[#purchase_calls + 1] = { role_id = role_id, product_id = skin.product_id }
        return true
      end)
      local s = _make_state()
      skin_panel.open(s, 1)
      skin_panel.unlock(s, 1, "buy", 1)
      skin_panel.equip(s, 1, 1)
      assert(#purchase_calls == 0, "owned skin should not trigger purchase")
      assert(s.ui.skin_panel.selected_by_role["1"] == 5001, "should equip normally")
    end)

    it("reset_for_tests clears purchase handler", function()
      skin_panel.configure_purchase(function() return true end)
      skin_panel.reset_for_tests()
      local catalog = _make_rich_catalog()
      skin_panel.configure_catalog_for_tests(catalog)
      local s = _make_state()
      skin_panel.open(s, 1)
      skin_panel.equip(s, 1, 1)
      assert(s.ui.skin_panel.selected_by_role["1"] == nil, "no purchase handler means no equip on locked skin")
    end)
  end)

  describe("equip callback outcomes", function()
    it("callback returning true sets last_equip_ok to true", function()
      skin_panel.configure_catalog_for_tests(_make_catalog(3))
      skin_panel.configure_equip(function() return true end)
      local s = _make_state()
      skin_panel.open(s, 1)
      skin_panel.unlock(s, 1, "buy", 1)
      skin_panel.equip(s, 1, 1)
      assert(s.ui.skin_panel.last_equip_ok_by_role["1"] == true, "callback returning true should set last_equip_ok to true")
    end)

    it("callback returning false sets last_equip_ok to false", function()
      skin_panel.configure_catalog_for_tests(_make_catalog(3))
      skin_panel.configure_equip(function() return false end)
      local s = _make_state()
      skin_panel.open(s, 1)
      skin_panel.unlock(s, 1, "buy", 1)
      skin_panel.equip(s, 1, 1)
      assert(s.ui.skin_panel.last_equip_ok_by_role["1"] == false, "callback returning false should set last_equip_ok to false")
    end)

    it("callback returning nil sets last_equip_ok to false", function()
      skin_panel.configure_catalog_for_tests(_make_catalog(3))
      skin_panel.configure_equip(function() return nil end)
      local s = _make_state()
      skin_panel.open(s, 1)
      skin_panel.unlock(s, 1, "buy", 1)
      skin_panel.equip(s, 1, 1)
      assert(s.ui.skin_panel.last_equip_ok_by_role["1"] == false, "callback returning nil should set last_equip_ok to false")
    end)

    it("callback that errors sets last_equip_ok to false", function()
      skin_panel.configure_catalog_for_tests(_make_catalog(3))
      skin_panel.configure_equip(function() error("boom") end)
      local s = _make_state()
      skin_panel.open(s, 1)
      skin_panel.unlock(s, 1, "buy", 1)
      skin_panel.equip(s, 1, 1)
      assert(s.ui.skin_panel.last_equip_ok_by_role["1"] == false, "erroring callback should set last_equip_ok to false")
    end)

    it("no callback configured sets last_equip_ok to false", function()
      skin_panel.configure_catalog_for_tests(_make_catalog(3))
      local s = _make_state()
      skin_panel.open(s, 1)
      skin_panel.unlock(s, 1, "buy", 1)
      skin_panel.equip(s, 1, 1)
      assert(s.ui.skin_panel.last_equip_ok_by_role["1"] == false, "no callback should set last_equip_ok to false")
    end)
  end)

  describe("equip branches", function()
    -- Each branch in skin_panel.equip lands here once for explicit
    -- branch-coverage attribution; some paths are also exercised in
    -- other describes (purchase flow, equip callback outcomes).

    it("branch 1: out-of-range slot returns panel without changing selection", function()
      skin_panel.configure_catalog_for_tests(_make_catalog(3))
      local s = _make_state()
      skin_panel.open(s, 1)
      local before_selected = s.ui.skin_panel.selected_by_role["1"]
      local panel = skin_panel.equip(s, 1, 5)
      assert(panel == s.ui.skin_panel, "equip should still return the panel state")
      assert(s.ui.skin_panel.selected_by_role["1"] == before_selected,
        "out-of-range equip must not touch selection (was " .. tostring(before_selected) .. ")")
      assert(s.ui.skin_panel.last_equip_ok_by_role == nil,
        "out-of-range equip must short-circuit before last_equip_ok bookkeeping")
    end)

    it("branch 1b: slot beyond PAGE_SIZE returns panel without changing selection", function()
      skin_panel.configure_catalog_for_tests(_make_catalog(3))
      local s = _make_state()
      skin_panel.open(s, 1)
      local panel = skin_panel.equip(s, 1, 99)
      assert(panel == s.ui.skin_panel, "equip on slot 99 should still return the panel state")
      assert(s.ui.skin_panel.selected_by_role["1"] == nil,
        "slot-99 equip must not touch selection")
    end)

    it("branch 2: not-owned purchase skin without callback leaves selection nil", function()
      skin_panel.configure_catalog_for_tests(_make_rich_catalog())
      -- skin slot 1 (5001) is unlock=purchase, no purchase_callback configured
      local s = _make_state()
      skin_panel.open(s, 1)
      skin_panel.equip(s, 1, 1)
      assert(s.ui.skin_panel.selected_by_role["1"] == nil,
        "without purchase callback, not-owned purchase skin equip leaves selection nil")
      assert(s.ui.skin_panel.owned_by_role["1"] == nil or
        s.ui.skin_panel.owned_by_role["1"][5001] ~= true,
        "without purchase callback, skin should not become owned")
    end)

    it("branch 3: not-owned non-purchase (gift) skin notifies and returns", function()
      skin_panel.configure_catalog_for_tests(_make_rich_catalog())
      -- skin slot 3 (5003) is unlock=gift
      local s = _make_state()
      skin_panel.open(s, 1)
      skin_panel.equip(s, 1, 3)
      assert(s.ui.skin_panel.selected_by_role["1"] == nil,
        "equip on not-owned gift skin must not select it")
      assert(s.ui.skin_panel.owned_by_role["1"] == nil or
        s.ui.skin_panel.owned_by_role["1"][5003] ~= true,
        "equip on not-owned gift skin must not mark it owned")
    end)

    it("branch 4: owned skin success sets selection and last_equip_ok", function()
      skin_panel.configure_catalog_for_tests(_make_rich_catalog())
      skin_panel.configure_equip(function() return true end)
      local s = _make_state()
      skin_panel.open(s, 1)
      skin_panel.unlock(s, 1, "buy", 2)
      skin_panel.equip(s, 1, 2)
      assert(s.ui.skin_panel.selected_by_role["1"] == 5002,
        "owned equip success must set selected_by_role to product_id")
      assert(s.ui.skin_panel.last_equip_ok_by_role["1"] == true,
        "owned equip success must record callback outcome in last_equip_ok_by_role")
    end)

    it("equip with role_id=nil falls back to panel.role_id", function()
      skin_panel.configure_catalog_for_tests(_make_catalog(3))
      local s = _make_state()
      skin_panel.open(s, 7)  -- panel.role_id = 7
      skin_panel.unlock(s, 7, "buy", 1)
      skin_panel.equip(s, nil, 1)  -- role_id=nil → should use panel.role_id (7)
      assert(s.ui.skin_panel.selected_by_role["7"] == "skin_1",
        "equip with role_id=nil should use panel.role_id (7) for the key")
    end)

    it("unlock with nil skin (slot out of range) is no-op", function()
      skin_panel.configure_catalog_for_tests(_make_catalog(3))
      local s = _make_state()
      skin_panel.open(s, 1)
      skin_panel.unlock(s, 1, "buy", 99)
      assert(s.ui.skin_panel.owned_by_role["1"] == nil,
        "unlock on out-of-range slot must not initialize owned_by_role bucket")
    end)
  end)

  describe("equip refreshes button state", function()
    it("coord equip calls refresh_slots to update buttons", function()
      local catalog = _make_rich_catalog()
      skin_panel.configure_catalog_for_tests(catalog)
      local refresh_count = 0
      local orig_refresh = skin_panel_view.refresh_slots
      skin_panel_view.refresh_slots = function(...)
        refresh_count = refresh_count + 1
        return orig_refresh(...)
      end

      local s = _make_state()
      skin_panel.open(s, 1)
      local before_equip = refresh_count
      skin_panel.unlock(s, 1, "buy", 1)
      skin_panel.equip(s, 1, 1)
      assert(refresh_count > before_equip, "equip should trigger refresh_slots")

      skin_panel_view.refresh_slots = orig_refresh
    end)
  end)
end)
