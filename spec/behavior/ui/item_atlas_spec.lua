local support = require("spec.support.shared_support")
local _with_patches = support.with_patches
local _build_role_with_events = support.build_role_with_events
local _has_event = support.has_event
local item_atlas = require("src.ui.coord.item_atlas")
local runtime_ports = require("src.foundation.ports.runtime_ports")

local function _make_state()
  return { ui = {} }
end

local function _make_catalog(n)
  local t = {}
  for i = 1, n do
    t[i] = { id = "item_" .. i, name = "道具" .. i }
  end
  return t
end

describe("item_atlas", function()
  before_each(function()
    item_atlas.reset_for_tests()
  end)

  describe("open/close", function()
    it("marks atlas open after open()", function()
      local s = _make_state()
      local atlas = item_atlas.open(s, 1)
      assert(atlas.open == true, "atlas should be open")
    end)

    it("opens the atlas canvas for the active role", function()
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
        item_atlas.open(s, 1)
      end)

      assert(_has_event(events, "显示道具图鉴"), "opening atlas should show atlas canvas")
    end)

    it("stores role_id on open", function()
      local s = _make_state()
      local atlas = item_atlas.open(s, 2)
      assert(atlas.role_id == 2, "role_id should be stored")
    end)

    it("marks atlas closed after close()", function()
      local s = _make_state()
      item_atlas.open(s, 1)
      local atlas = item_atlas.close(s)
      assert(atlas.open == false, "atlas should be closed")
    end)

    it("closes the atlas canvas for the active role", function()
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
        item_atlas.open(s, 1)
        item_atlas.handle_action(s, "close", 1)
      end)

      assert(_has_event(events, "隐藏道具图鉴"), "closing atlas should hide atlas canvas")
    end)
  end)

  describe("catalog injection", function()
    it("configure_catalog_for_tests replaces active catalog", function()
      local cat = _make_catalog(5)
      item_atlas.configure_catalog_for_tests(cat)
      assert(#item_atlas.catalog == 5, "catalog size should be 5")
    end)

    it("reset_for_tests restores default catalog size", function()
      item_atlas.configure_catalog_for_tests(_make_catalog(3))
      item_atlas.reset_for_tests()
      assert(#item_atlas.catalog == 19, "default catalog has 19 items")
    end)

    it("page shows correct slot count with 8-item catalog", function()
      item_atlas.configure_catalog_for_tests(_make_catalog(8))
      local s = _make_state()
      item_atlas.open(s, 1)
      local atlas = s.ui.item_atlas
      local count = 0
      for i = 1, 8 do
        local idx = (atlas.page_index - 1) * 8 + i
        if item_atlas.catalog[idx] then count = count + 1 end
      end
      assert(count == 8, "8-item catalog should show 8 slots, got " .. tostring(count))
    end)

    it("page shows correct slot count with 5-item catalog", function()
      item_atlas.configure_catalog_for_tests(_make_catalog(5))
      local s = _make_state()
      item_atlas.open(s, 1)
      local atlas = s.ui.item_atlas
      local count = 0
      for i = 1, 8 do
        local idx = (atlas.page_index - 1) * 8 + i
        if item_atlas.catalog[idx] then count = count + 1 end
      end
      assert(count == 5, "5-item catalog should show 5 slots, got " .. tostring(count))
    end)
  end)

  describe("select slot", function()
    it("select slot records selected_item_id", function()
      item_atlas.configure_catalog_for_tests(_make_catalog(8))
      local s = _make_state()
      item_atlas.open(s, 1)
      item_atlas.handle_action(s, { type = "select", slot_index = 1 }, 1)
      assert(s.ui.item_atlas.selected_item_id == "item_1", "slot 1 should select item_1")
    end)

    it("select slot 5 records item_5", function()
      item_atlas.configure_catalog_for_tests(_make_catalog(8))
      local s = _make_state()
      item_atlas.open(s, 1)
      item_atlas.handle_action(s, { type = "select", slot_index = 5 }, 1)
      assert(s.ui.item_atlas.selected_item_id == "item_5", "slot 5 should select item_5")
    end)
  end)

  describe("pagination", function()
    it("page_next advances page when multiple pages exist", function()
      item_atlas.configure_catalog_for_tests(_make_catalog(16))
      local s = _make_state()
      item_atlas.open(s, 1)
      item_atlas.handle_action(s, "next", 1)
      assert(s.ui.item_atlas.page_index == 2, "page should advance to 2")
    end)

    it("page_next does not exceed max page", function()
      item_atlas.configure_catalog_for_tests(_make_catalog(8))
      local s = _make_state()
      item_atlas.open(s, 1)
      item_atlas.handle_action(s, "next", 1)
      item_atlas.handle_action(s, "next", 1)
      assert(s.ui.item_atlas.page_index == 1, "single-page atlas should clamp to page 1")
    end)
  end)

  describe("handle_action", function()
    it("close action closes atlas", function()
      local s = _make_state()
      item_atlas.open(s, 1)
      item_atlas.handle_action(s, "close", 1)
      assert(s.ui.item_atlas.open == false, "close action should close atlas")
    end)
  end)
end)
