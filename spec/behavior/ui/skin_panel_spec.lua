local support = require("spec.support.shared_support")
local _with_patches = support.with_patches
local _build_role_with_events = support.build_role_with_events
local _has_event = support.has_event
local skin_panel = require("src.ui.coord.skin_panel")
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
  end)

  describe("handle_action", function()
    it("buy action unlocks skin", function()
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
  end)
end)
