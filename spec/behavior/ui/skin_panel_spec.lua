local support = require("spec.support.shared_support")
local _with_patches = support.with_patches
local _build_role_with_events = support.build_role_with_events
local _has_event = support.has_event
local skin_panel = require("src.ui.coord.skin_panel")
local skin_panel_view = require("src.ui.render.skin_panel")
local skin_nodes = require("src.ui.schema.skin")
local default_skins = require("src.config.content.skins")
local logger = require("src.foundation.log")
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

-- In-memory stand-in for the host skin archive port. Records mark/save calls so
-- tests can assert what was persisted, and serves load_* back for seeding.
local function _make_fake_archive()
  local store = { owned = {}, equipped = {}, mark_calls = {}, save_calls = {} }
  return {
    store = store,
    mark_owned = function(role, product_id)
      store.mark_calls[#store.mark_calls + 1] = { role = role, product_id = product_id }
      store.owned[tostring(role)] = store.owned[tostring(role)] or {}
      store.owned[tostring(role)][product_id] = true
    end,
    load_owned = function(role)
      local out = {}
      for product_id in pairs(store.owned[tostring(role)] or {}) do
        out[#out + 1] = product_id
      end
      return out
    end,
    save_equipped = function(role, product_id)
      store.save_calls[#store.save_calls + 1] = { role = role, product_id = product_id }
      store.equipped[tostring(role)] = product_id
    end,
    load_equipped = function(role)
      return store.equipped[tostring(role)]
    end,
  }
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

    it("routes owner refresh through presentation_runtime.with_client_role when role resolves", function()
      local role = { id = 1 }
      local role_passed = nil
      local fn_called = false
      local s = _make_state()
      s.presentation_runtime = {
        runtime = {
          with_client_role = function(r, fn)
            role_passed = r
            fn_called = true
            return fn()
          end,
        },
      }

      _with_patches({
        { target = runtime_ports, key = "resolve_role", value = function(role_id)
          if role_id == 1 then return role end
          return nil
        end },
      }, function()
        skin_panel.open(s, 1)
      end)

      assert(role_passed == role,
        "owner refresh should run under the resolved role via with_client_role")
      assert(fn_called,
        "refresh function should be invoked inside with_client_role")
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

    it("is_slot_equipped returns false for an empty slot", function()
      skin_panel.configure_catalog_for_tests(_make_catalog(1))
      local s = _make_state()
      skin_panel.open(s, 1)
      assert.equals(false, skin_panel.is_slot_equipped(s, 2))
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

    it("unequip invokes the restore callback with the role id", function()
      skin_panel.configure_catalog_for_tests(_make_catalog(5))
      local received = "unset"
      skin_panel.configure_unequip(function(role_id) received = role_id end)
      local s = _make_state()
      skin_panel.open(s, 2)
      skin_panel.unlock(s, 2, "buy", 1)
      skin_panel.equip(s, 2, 1)
      skin_panel.handle_action(s, "unequip", 2)
      assert(received == 2,
        "unequip should pass the role id to the restore callback, got " .. tostring(received))
    end)

    it("unequip without a restore callback still clears the selection", function()
      skin_panel.configure_catalog_for_tests(_make_catalog(5))
      local s = _make_state()
      skin_panel.open(s, 1)
      skin_panel.unlock(s, 1, "buy", 1)
      skin_panel.equip(s, 1, 1)
      skin_panel.handle_action(s, "unequip", 1)
      assert(s.ui.skin_panel.selected_by_role["1"] == nil,
        "unequip must clear selection even when no restore callback is configured")
    end)

    it("unequip warns and still clears selection when the restore callback throws", function()
      skin_panel.configure_catalog_for_tests(_make_catalog(5))
      skin_panel.configure_unequip(function() error("boom") end)
      local s = _make_state()
      skin_panel.open(s, 1)
      skin_panel.unlock(s, 1, "buy", 1)
      skin_panel.equip(s, 1, 1)
      local warned = false
      _with_patches({
        { target = logger, key = "warn", value = function(message)
          if tostring(message):match("unequip callback failed") then
            warned = true
          end
        end },
      }, function()
        skin_panel.handle_action(s, "unequip", 1)
      end)
      assert(warned, "a throwing restore callback must hit the warn failure path")
      assert(s.ui.skin_panel.selected_by_role["1"] == nil,
        "a throwing restore callback must not block selection clearing")
    end)

    it("unequip clears the explicitly passed role, not the panel's open role", function()
      skin_panel.configure_catalog_for_tests(_make_catalog(5))
      local s = _make_state()
      skin_panel.open(s, 1) -- panel.role_id stays 1
      skin_panel.unlock(s, 2, "buy", 1)
      skin_panel.equip(s, 2, 1)
      assert(s.ui.skin_panel.selected_by_role["2"] == "skin_1", "role 2 should be equipped")
      skin_panel.handle_action(s, "unequip", 2)
      assert(s.ui.skin_panel.selected_by_role["2"] == nil,
        "unequip must act on the passed role id (role_id or panel.role_id), not panel.role_id")
    end)
  end)

  describe("archive persistence", function()
    it("purchase unlock marks ownership and persists the auto-equipped skin", function()
      skin_panel.configure_catalog_for_tests(_make_rich_catalog())
      local archive = _make_fake_archive()
      skin_panel.configure_archive(archive)
      skin_panel.configure_purchase(function(_, _, on_success) on_success() end)
      local s = _make_state()
      skin_panel.open(s, 1)
      skin_panel.equip(s, 1, 1) -- slot 1 is a locked purchase skin -> initiates purchase
      assert(archive.store.owned["1"][5001] == true, "purchase should persist ownership")
      assert(archive.store.equipped["1"] == 5001, "purchase auto-equip should persist equipped product")
    end)

    it("does not persist gift-unlocked ownership", function()
      skin_panel.configure_catalog_for_tests(_make_rich_catalog())
      local archive = _make_fake_archive()
      skin_panel.configure_archive(archive)
      local s = _make_state()
      skin_panel.open(s, 1)
      skin_panel.unlock(s, 1, "gift", 3)
      assert(archive.store.owned["1"] == nil or archive.store.owned["1"][5003] == nil,
        "gift unlock must not write to the archive")
    end)

    it("unequip clears the persisted equipped product", function()
      skin_panel.configure_catalog_for_tests(_make_rich_catalog())
      local archive = _make_fake_archive()
      skin_panel.configure_archive(archive)
      local s = _make_state()
      skin_panel.open(s, 1)
      skin_panel.unlock(s, 1, "purchase", 1)
      skin_panel.equip(s, 1, 1)
      assert(archive.store.equipped["1"] == 5001, "equip should persist equipped product")
      skin_panel.handle_action(s, "unequip", 1)
      assert(archive.store.equipped["1"] == nil, "unequip should clear the persisted equipped product")
    end)

    it("open seeds ownership from the archive on a fresh state", function()
      skin_panel.configure_catalog_for_tests(_make_rich_catalog())
      local archive = _make_fake_archive()
      archive.store.owned["1"] = { [5001] = true }
      skin_panel.configure_archive(archive)
      local s = _make_state()
      skin_panel.open(s, 1)
      assert(s.ui.skin_panel.owned_by_role["1"][5001] == true,
        "open should seed ownership from the archive")
    end)

    it("open auto-equips the persisted skin, fires the equip callback, and stays open", function()
      skin_panel.configure_catalog_for_tests(_make_rich_catalog())
      local archive = _make_fake_archive()
      archive.store.owned["1"] = { [5001] = true }
      archive.store.equipped["1"] = 5001
      local equipped_product
      skin_panel.configure_equip(function(_, skin)
        equipped_product = skin and skin.product_id
        return true
      end)
      skin_panel.configure_archive(archive)
      local s = _make_state()
      skin_panel.open(s, 1)
      assert(s.ui.skin_panel.selected_by_role["1"] == 5001, "open should auto-equip the persisted skin")
      assert(equipped_product == 5001, "auto-equip should fire the equip callback with the product id")
      assert(s.ui.skin_panel.open == true, "panel must stay open after seeding auto-equip")
    end)

    it("no archive configured leaves persistence paths inert", function()
      skin_panel.configure_catalog_for_tests(_make_rich_catalog())
      local s = _make_state()
      skin_panel.open(s, 1)
      skin_panel.unlock(s, 1, "purchase", 1)
      skin_panel.equip(s, 1, 1)
      skin_panel.handle_action(s, "unequip", 1)
      assert(s.ui.skin_panel.selected_by_role["1"] == nil,
        "without an archive the equip/unequip flow behaves as before")
    end)

    -- configure_archive only asserts nil-or-table, so a partial port (a table
    -- missing some methods) is a contract-allowed input. Seeding must degrade
    -- gracefully rather than call a nil method.
    it("open skips ownership seeding when the archive lacks load_owned", function()
      skin_panel.configure_catalog_for_tests(_make_rich_catalog())
      skin_panel.configure_archive({}) -- partial port: no load_owned
      local s = _make_state()
      skin_panel.open(s, 1) -- must not call a nil load_owned
      local owned = s.ui.skin_panel.owned_by_role["1"]
      assert(owned == nil or next(owned) == nil,
        "a missing load_owned must leave ownership unseeded, not error")
    end)

    it("open skips equipped restore when the archive lacks load_equipped", function()
      skin_panel.configure_catalog_for_tests(_make_rich_catalog())
      skin_panel.configure_archive({
        load_owned = function() return { 5001 } end,
        -- no load_equipped
      })
      local s = _make_state()
      skin_panel.open(s, 1) -- must not call a nil load_equipped
      assert(s.ui.skin_panel.owned_by_role["1"][5001] == true,
        "ownership is still seeded when only load_equipped is absent")
      assert(s.ui.skin_panel.selected_by_role["1"] == nil,
        "a missing load_equipped must skip equipped restore, not error")
    end)

    it("open does not auto-equip a persisted skin the player does not own", function()
      skin_panel.configure_catalog_for_tests(_make_rich_catalog())
      skin_panel.configure_archive({
        load_owned = function() return {} end, -- owns nothing
        load_equipped = function() return 5001 end, -- archive claims 5001 equipped
      })
      local s = _make_state()
      skin_panel.open(s, 1)
      assert(s.ui.skin_panel.selected_by_role["1"] == nil,
        "must not auto-equip a persisted skin that is not owned")
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
      assert(text == "198", "locked purchase button should show price only, got: " .. tostring(text))
    end)

    it("locked gift skin shows gift_name on button", function()
      local catalog = _make_rich_catalog()
      local state, calls = _make_render_state()
      skin_panel_view.refresh_slots(state, catalog)
      local text = _find_call(calls, "set_button", skin_nodes.action_buttons[3])
      assert(text == "谢礼", "locked gift button should show gift_name, got: " .. tostring(text))
    end)

    it("locked gift skin without gift_name falls back to price text", function()
      local catalog = {
        { product_id = 1, name = "gift_without_name", unlock = "gift", currency = "金豆", price = 100 },
      }
      local state, calls = _make_render_state()
      skin_panel_view.refresh_slots(state, catalog)
      local text = _find_call(calls, "set_button", skin_nodes.action_buttons[1])
      assert(text == "100", "gift skin without gift_name should fall back to price text only")
    end)

    it("locked skin without display text clears stale button text", function()
      local catalog = {
        { product_id = 1, name = "missing_price", unlock = "purchase" },
      }
      local state, calls = _make_render_state()
      skin_panel_view.refresh_slots(state, catalog)
      local text = _find_call(calls, "set_button", skin_nodes.action_buttons[1])
      assert(text == "", "locked skin without display text should clear stale button text")
    end)

    it("locked purchase skin button is touch-enabled for buying", function()
      local catalog = _make_rich_catalog()
      local state, calls = _make_render_state()
      skin_panel_view.refresh_slots(state, catalog)
      local enabled = _find_call(calls, "set_touch_enabled", skin_nodes.action_buttons[1])
      assert(enabled == true, "locked purchase button should be touch-enabled")
    end)

    it("default locked skin slots 5 and 6 render as 198 jindou purchases", function()
      local state, calls = _make_render_state()
      skin_panel_view.refresh_slots(state, default_skins)
      for _, slot in ipairs({ 5, 6 }) do
        local text = _find_call(calls, "set_button", skin_nodes.action_buttons[slot])
        local enabled = _find_call(calls, "set_touch_enabled", skin_nodes.action_buttons[slot])
        local price_visible = _find_call(calls, "set_visible", skin_nodes.price_icons[slot])
        assert(text == "198", "default slot " .. tostring(slot) .. " should show price 198")
        assert(enabled == true, "default slot " .. tostring(slot) .. " should be touch-enabled")
        assert(price_visible == true, "default slot " .. tostring(slot) .. " should show price icon")
      end
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

    it("equipped skin shows 脱下 on button", function()
      local catalog = _make_rich_catalog()
      local state, calls = _make_render_state({
        owned_by_role = { ["1"] = { [5001] = true } },
        selected_by_role = { ["1"] = 5001 },
      })
      skin_panel_view.refresh_slots(state, catalog)
      local text = _find_call(calls, "set_button", skin_nodes.action_buttons[1])
      assert(text == "脱下", "equipped button should show 脱下, got: " .. tostring(text))
    end)

    it("equipped skin button is touch-enabled", function()
      local catalog = _make_rich_catalog()
      local state, calls = _make_render_state({
        owned_by_role = { ["1"] = { [5001] = true } },
        selected_by_role = { ["1"] = 5001 },
      })
      skin_panel_view.refresh_slots(state, catalog)
      local enabled = _find_call(calls, "set_touch_enabled", skin_nodes.action_buttons[1])
      assert(enabled == true, "equipped button should be touch-enabled")
    end)

    it("card outline containers stay visible for all occupied slots", function()
      local catalog = _make_rich_catalog()
      local state, calls = _make_render_state({
        owned_by_role = { ["1"] = { [5002] = true } },
        selected_by_role = { ["1"] = 5002 },
      })
      skin_panel_view.refresh_slots(state, catalog)
      local outline1 = _find_call(calls, "set_visible", skin_nodes.card_outlines[1])
      local outline2 = _find_call(calls, "set_visible", skin_nodes.card_outlines[2])
      local outline3 = _find_call(calls, "set_visible", skin_nodes.card_outlines[3])
      assert(outline1 == true, "occupied outline container 1 should be visible")
      assert(outline2 == true, "occupied outline container 2 should be visible")
      assert(outline3 == true, "occupied outline container 3 should be visible")
    end)

    it("card outline containers are hidden for empty slots", function()
      local catalog = _make_rich_catalog()
      local state, calls = _make_render_state()
      skin_panel_view.refresh_slots(state, catalog)
      for slot = 1, 3 do
        local vis = _find_call(calls, "set_visible", skin_nodes.card_outlines[slot])
        assert(vis == true, "occupied outline container " .. slot .. " should be visible")
      end
      for slot = 4, #skin_nodes.card_outlines do
        local vis = _find_call(calls, "set_visible", skin_nodes.card_outlines[slot])
        assert(vis == false, "empty outline container " .. slot .. " should be hidden")
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

    it("uses card image refs instead of skin prefab refs for card textures", function()
      local catalog = _make_rich_catalog()
      local state, _ = _make_render_state()
      state.ui_refs = {
        images = { ["5001"] = "card_tex_pig" },
        skins = { ["5001"] = "unit_prefab_pig" },
      }
      local textures = {}
      local runtime = {
        query_node = function(name) return { name = name } end,
        set_node_texture_keep_size = function(node, key)
          textures[node.name] = key
        end,
      }
      skin_panel_view.refresh_slots(state, catalog, { runtime = runtime })
      assert(textures[skin_nodes.card_images[1]] == "card_tex_pig",
        "skin shop card image must use ui_refs.images, not ui_refs.skins prefab refs")
    end)

    it("sets card texture on all matched nodes when runtime exposes query_nodes", function()
      local catalog = _make_rich_catalog()
      local state, _ = _make_render_state()
      state.ui_refs = { images = { ["5001"] = "tex_pig" } }
      local textures = {}
      local runtime = {
        query_nodes = function(name)
          return {
            { name = name .. "#a" },
            { name = name .. "#b" },
          }
        end,
        set_node_texture_keep_size = function(node, key)
          textures[node.name] = key
        end,
      }
      skin_panel_view.refresh_slots(state, catalog, { runtime = runtime })
      assert(textures[skin_nodes.card_images[1] .. "#a"] == "tex_pig",
        "should set texture on first matched node")
      assert(textures[skin_nodes.card_images[1] .. "#b"] == "tex_pig",
        "should set texture on second matched node")
    end)

    it("ignores non-table query_nodes results when setting card textures", function()
      local catalog = _make_rich_catalog()
      local state, _ = _make_render_state()
      state.ui_refs = { images = { ["5001"] = "tex_pig" } }
      local texture_calls = 0
      local runtime = {
        query_nodes = function() return "not-a-node-list" end,
        set_node_texture_keep_size = function()
          texture_calls = texture_calls + 1
        end,
      }
      skin_panel_view.refresh_slots(state, catalog, { runtime = runtime })
      assert(texture_calls == 0, "non-table query_nodes result should not set textures")
    end)

    it("ignores failed query_nodes calls even when the error payload is table-like", function()
      local catalog = _make_rich_catalog()
      local state, _ = _make_render_state()
      state.ui_refs = { images = { ["5001"] = "tex_pig" } }
      local textures = {}
      local runtime = {
        query_nodes = function()
          error({ { name = "should_not_be_textured" } })
        end,
        set_node_texture_keep_size = function(node, key)
          textures[node.name] = key
        end,
      }
      skin_panel_view.refresh_slots(state, catalog, { runtime = runtime })
      assert(textures.should_not_be_textured == nil,
        "failed query_nodes payload must not be treated as matched nodes")
    end)

    it("shows action buttons for occupied slots and hides trailing empty slots", function()
      local catalog = _make_catalog(3)
      local state, calls = _make_render_state()
      skin_panel_view.refresh_slots(state, catalog)
      local occupied_visible = _find_call(calls, "set_visible", skin_nodes.action_buttons[1])
      local empty_visible = _find_call(calls, "set_visible", skin_nodes.action_buttons[4])
      assert(occupied_visible == true, "occupied slot action button should be visible")
      assert(empty_visible == false, "empty slot action button should be hidden")
    end)

    it("shows card frames for occupied slots and hides trailing empty slots", function()
      local catalog = _make_catalog(3)
      local state, calls = _make_render_state()
      skin_panel_view.refresh_slots(state, catalog)
      local occupied_visible = _find_call(calls, "set_visible", skin_nodes.card_frames[1])
      local empty_visible = _find_call(calls, "set_visible", skin_nodes.card_frames[4])
      assert(occupied_visible == true, "occupied slot frame should be visible")
      assert(empty_visible == false, "empty slot frame should be hidden")
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

    -- L111 mutation closure: src/ui/render/skin_panel.lua _refresh_price_icon
    --   has_price = is_purchase and skin.price ~= nil and skin.currency ~= nil
    -- The three cases below each break a single conjunct so that mutating any
    -- one `and` → `or` flips the visibility on the affected slot. Without
    -- these tests, acceptance-only coverage doesn't close the mutation (the
    -- mutator harness runs busted, not run_acceptance.lua).
    it("price icon hidden when gift unlock retains price/currency (L111 M1)", function()
      local catalog = {
        { product_id = 1, name = "gift_with_price",
          unlock = "gift", gift_name = "谢礼", currency = "金豆", price = 100 },
      }
      local state, calls = _make_render_state()
      skin_panel_view.refresh_slots(state, catalog)
      local vis = _find_call(calls, "set_visible", skin_nodes.price_icons[1])
      assert(vis == false, "gift unlock should hide price icon even when price/currency set")
    end)

    it("price icon hidden when purchase unlock has nil price (L111 M2)", function()
      local catalog = {
        { product_id = 1, name = "purchase_no_price",
          unlock = "purchase", currency = "金豆", price = nil },
      }
      local state, calls = _make_render_state()
      skin_panel_view.refresh_slots(state, catalog)
      local vis = _find_call(calls, "set_visible", skin_nodes.price_icons[1])
      assert(vis == false, "purchase unlock with nil price should hide price icon")
    end)

    it("price icon hidden when purchase unlock has nil currency (L111 M2 sym)", function()
      local catalog = {
        { product_id = 1, name = "purchase_no_currency",
          unlock = "purchase", currency = nil, price = 100 },
      }
      local state, calls = _make_render_state()
      skin_panel_view.refresh_slots(state, catalog)
      local vis = _find_call(calls, "set_visible", skin_nodes.price_icons[1])
      assert(vis == false, "purchase unlock with nil currency should hide price icon")
    end)

    it("price icon hidden for an owned but unequipped purchase skin (穿上 state)", function()
      local catalog = _make_rich_catalog()
      local state, calls = _make_render_state({
        owned_by_role = { ["1"] = { [5001] = true } },
      })
      skin_panel_view.refresh_slots(state, catalog)
      local vis = _find_call(calls, "set_visible", skin_nodes.price_icons[1])
      assert(vis == false, "owned purchase skin should hide its price icon")
    end)

    it("price icon hidden for an equipped purchase skin (脱下 state)", function()
      local catalog = _make_rich_catalog()
      local state, calls = _make_render_state({
        owned_by_role = { ["1"] = { [5001] = true } },
        selected_by_role = { ["1"] = 5001 },
      })
      skin_panel_view.refresh_slots(state, catalog)
      local vis = _find_call(calls, "set_visible", skin_nodes.price_icons[1])
      assert(vis == false, "equipped purchase skin should hide its price icon")
    end)

    it("price icon still visible for an unowned purchase skin beside an owned one", function()
      local catalog = _make_rich_catalog()
      local state, calls = _make_render_state({
        owned_by_role = { ["1"] = { [5001] = true } },
      })
      skin_panel_view.refresh_slots(state, catalog)
      local vis = _find_call(calls, "set_visible", skin_nodes.price_icons[2])
      assert(vis == true, "an unowned purchase skin should still show its price icon")
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

    it("defaults to the first page when panel state is missing", function()
      local catalog = _make_catalog(6)
      local state, calls = _make_render_state()
      state.ui.skin_panel = nil
      skin_panel_view.refresh_slots(state, catalog)
      for slot = 1, 6 do
        local vis = _find_call(calls, "set_visible", skin_nodes.card_images[slot])
        assert(vis == true, "slot " .. slot .. " should render from the first page without panel state")
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

    it("disables touch for trailing empty card slots", function()
      local catalog = _make_catalog(3)
      local state, calls = _make_render_state()
      skin_panel_view.refresh_slots(state, catalog)
      for slot = 1, 3 do
        local enabled = _find_call(calls, "set_touch_enabled", skin_nodes.card_images[slot])
        assert(enabled == true, "slot " .. slot .. " card image should be touch-enabled")
      end
      for slot = 4, 6 do
        local enabled = _find_call(calls, "set_touch_enabled", skin_nodes.card_images[slot])
        assert(enabled == false, "empty card slot " .. slot .. " must not consume clicks")
      end
    end)

    it("clears action buttons and price icons for trailing empty slots", function()
      local catalog = _make_catalog(3)
      local state, calls = _make_render_state()
      skin_panel_view.refresh_slots(state, catalog)
      for slot = 4, 6 do
        local button_text = _find_call(calls, "set_button", skin_nodes.action_buttons[slot])
        local button_touch = _find_call(calls, "set_touch_enabled", skin_nodes.action_buttons[slot])
        local price_visible = _find_call(calls, "set_visible", skin_nodes.price_icons[slot])
        assert(button_text == "", "empty slot " .. slot .. " should clear stale button text")
        assert(button_touch == false, "empty slot " .. slot .. " action button must not consume clicks")
        assert(price_visible == false, "empty slot " .. slot .. " should hide stale price icon")
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

    it("purchase success keeps the originally purchased skin after page changes", function()
      local catalog = {}
      for index = 1, 7 do
        catalog[index] = {
          product_id = 7000 + index,
          name = "skin" .. tostring(index),
          unlock = "purchase",
          currency = "beans",
          price = 10,
        }
      end
      skin_panel.configure_catalog_for_tests(catalog)
      local captured_on_success = nil
      local captured_product_id = nil
      skin_panel.configure_purchase(function(_, skin, on_success)
        captured_product_id = skin.product_id
        captured_on_success = on_success
        return true
      end)

      local s = _make_state()
      skin_panel.open(s, 1)
      skin_panel.equip(s, 1, 1)
      assert(captured_product_id == 7001, "purchase should start for page 1 slot 1")
      skin_panel.handle_action(s, "next", 1)
      assert(s.ui.skin_panel.page_index == 2, "precondition: panel moved to page 2 before payment callback")

      captured_on_success()

      local panel = s.ui.skin_panel
      assert(panel.owned_by_role["1"][7001] == true, "success should own the purchased skin")
      assert(panel.selected_by_role["1"] == 7001, "success should equip the purchased skin")
      assert(panel.owned_by_role["1"][7007] ~= true, "success must not own page 2 slot 1")
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

    it("logs and leaves selection unchanged when purchase handler errors", function()
      skin_panel.configure_catalog_for_tests(_make_rich_catalog())
      skin_panel.configure_purchase(function()
        error("purchase failed")
      end)
      local warnings = {}
      local s = _make_state()
      skin_panel.open(s, 1)

      _with_patches({
        { target = logger, key = "warn", value = function(...)
          warnings[#warnings + 1] = table.concat({ ... }, " ")
        end },
      }, function()
        skin_panel.equip(s, 1, 1)
      end)

      assert(s.ui.skin_panel.selected_by_role["1"] == nil, "failed purchase must not equip skin")
      assert(#warnings == 1, "failed purchase should emit one warning")
      assert(warnings[1]:find("skin_panel: purchase callback failed", 1, true) ~= nil,
        "warning should identify purchase callback failure")
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
      local panel = skin_panel.equip(s, 1, 3)
      assert(panel == s.ui.skin_panel, "not-owned gift skin should return the panel state")
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
      assert(s.ui.skin_panel.open == false,
        "owned equip success must close the skin panel")
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

  -- T16 mutation-pinning addendum.
  describe("internal defaults and dispatch arithmetic (L21/L22/L34/L35/L61/L63/L84/L91/L236)", function()
    it("handle_action with unknown action returns panel with defaults (L21/L22/L236)", function()
      local s = _make_state() -- fresh, no skin_panel yet
      local result = skin_panel.handle_action(s, "unknown_xyz_no_handler", 1)
      assert(type(result) == "table",
        "L236 _ensure_state mutation to nil would return nil; got " .. type(result))
      assert(result.open == false,
        "L21 default open=false; mutation 'true' would yield true. Got " .. tostring(result.open))
      assert(result.page_index == 1,
        "L22 default page_index=1; mutation '0' would yield 0. Got " .. tostring(result.page_index))
    end)

    it("equip with non-integer slot defaults to slot 1 (L34 'or 1')", function()
      skin_panel.configure_catalog_for_tests(_make_catalog(3))
      local s = _make_state()
      skin_panel.open(s, 1)
      skin_panel.unlock(s, 1, "buy", 1) -- own skin_1
      skin_panel.equip(s, 1, "not_an_integer")
      assert(s.ui.skin_panel.selected_by_role["1"] == "skin_1",
        "L34 default slot=1 must pick skin_1; mutation 0 yields nil catalog lookup. " ..
        "Got: " .. tostring(s.ui.skin_panel.selected_by_role["1"]))
    end)

    it("equip on page 2 uses (page-1)*PAGE_SIZE arithmetic (L35 '*' not '/')", function()
      skin_panel.configure_catalog_for_tests(_make_catalog(12)) -- 2 pages of 6
      local s = _make_state()
      skin_panel.open(s, 1)
      skin_panel.handle_action(s, "next", 1) -- advance to page 2
      assert(s.ui.skin_panel.page_index == 2, "precondition: now on page 2")
      skin_panel.unlock(s, 1, "buy", 1) -- slot 1 on page 2 = catalog index 7
      skin_panel.equip(s, 1, 1)
      assert(s.ui.skin_panel.selected_by_role["1"] == "skin_7",
        "L35 multiplication must yield slot 7 (page=2 slot=1); division gives ~1.17 → wrong skin. " ..
        "Got: " .. tostring(s.ui.skin_panel.selected_by_role["1"]))
    end)

    it("buy action with only type field defaults slot to 1 (L61 last '1' default)", function()
      skin_panel.configure_catalog_for_tests(_make_catalog(3))
      local s = _make_state()
      skin_panel.open(s, 1)
      skin_panel.handle_action(s, { type = "buy" }, 1) -- no slot_index/index/slot
      assert(s.ui.skin_panel.owned_by_role["1"]["skin_1"] == true,
        "L61 default '1' must own skin_1; mutation 0 yields out-of-range no-op")
    end)

    it("buy action prefers slot_index over index (L61 first 'or')", function()
      skin_panel.configure_catalog_for_tests(_make_catalog(3))
      local s = _make_state()
      skin_panel.open(s, 1)
      skin_panel.handle_action(s, { type = "buy", slot_index = 2, index = 99 }, 1)
      assert(s.ui.skin_panel.owned_by_role["1"]["skin_2"] == true,
        "L61 first 'or' must short-circuit to slot_index=2; mutation 'and' yields slot=99 (out of range, no own)")
      assert(s.ui.skin_panel.owned_by_role["1"]["skin_99"] == nil,
        "skin_99 must not exist; sanity check")
    end)

    it("buy action falls back to index when slot_index missing (L61 second 'or')", function()
      skin_panel.configure_catalog_for_tests(_make_catalog(3))
      local s = _make_state()
      skin_panel.open(s, 1)
      skin_panel.handle_action(s, { type = "buy", index = 2, slot = 99 }, 1)
      assert(s.ui.skin_panel.owned_by_role["1"]["skin_2"] == true,
        "L61 second 'or' must fall back to index=2 when slot_index nil; " ..
        "mutation 'and' yields slot=99 (out of range)")
    end)

    it("buy action falls back to slot when slot_index+index missing (L61 third 'or')", function()
      skin_panel.configure_catalog_for_tests(_make_catalog(3))
      local s = _make_state()
      skin_panel.open(s, 1)
      skin_panel.handle_action(s, { type = "buy", slot = 2 }, 1)
      -- Original: nil or nil or 2 or 1 → 2. Mutated 3rd 'or→and': nil or nil or 2 and 1 → 1.
      assert(s.ui.skin_panel.owned_by_role["1"]["skin_2"] == true,
        "L61 third 'or' must yield slot=2 from .slot field; mutation 'and' yields 1 (2 and 1 = 1)")
    end)

    it("string 'buy' action (non-table) defaults slot to 1 (L63)", function()
      skin_panel.configure_catalog_for_tests(_make_catalog(3))
      local s = _make_state()
      skin_panel.open(s, 1)
      skin_panel.handle_action(s, "buy", 1)
      assert(s.ui.skin_panel.owned_by_role["1"]["skin_1"] == true,
        "L63 non-table action must default slot to 1; mutation 0 yields no ownership")
    end)

    it("configure_equip(nil) does not throw (L84 '~=' guards the assert)", function()
      local ok, err = pcall(function() skin_panel.configure_equip(nil) end)
      assert(ok,
        "L84 '~=' must skip assert when callback is nil. Mutation '==' makes assert fire on nil. Err: " ..
        tostring(err))
    end)

    it("configure_purchase(nil) does not throw (L91 '~=' guards the assert)", function()
      local ok, err = pcall(function() skin_panel.configure_purchase(nil) end)
      assert(ok,
        "L91 '~=' must skip assert when callback is nil. Mutation '==' makes assert fire on nil. Err: " ..
        tostring(err))
    end)
  end)
end)
