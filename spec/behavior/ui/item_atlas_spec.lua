local support = require("spec.support.shared_support")
local _with_patches = support.with_patches
local _build_role_with_events = support.build_role_with_events
local _has_event = support.has_event
local item_atlas = require("src.ui.coord.item_atlas")
local item_atlas_view = require("src.ui.render.item_atlas")
local item_atlas_nodes = require("src.ui.schema.item_atlas")
local runtime_ports = require("src.foundation.ports.runtime_ports")

local function _make_state()
  return { ui = {} }
end

local function _make_catalog(n)
  local t = {}
  for i = 1, n do
    t[i] = { id = "item_" .. i, name = "道具" .. i, description = "描述" .. i }
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

    it("selecting empty slot does not set selected_item_id", function()
      item_atlas.configure_catalog_for_tests(_make_catalog(5))
      local s = _make_state()
      item_atlas.open(s, 1)
      item_atlas.handle_action(s, { type = "select", slot_index = 7 }, 1)
      assert(s.ui.item_atlas.selected_item_id == nil, "empty slot should leave selection nil")
    end)

    it("dismiss action clears selected_item_id", function()
      item_atlas.configure_catalog_for_tests(_make_catalog(8))
      local s = _make_state()
      item_atlas.open(s, 1)
      item_atlas.handle_action(s, { type = "select", slot_index = 1 }, 1)
      assert(s.ui.item_atlas.selected_item_id == "item_1")
      item_atlas.handle_action(s, "dismiss", 1)
      assert(s.ui.item_atlas.selected_item_id == nil, "dismiss should clear selection")
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

    it("page_prev goes to previous page", function()
      item_atlas.configure_catalog_for_tests(_make_catalog(16))
      local s = _make_state()
      item_atlas.open(s, 1)
      item_atlas.handle_action(s, "next", 1)
      assert(s.ui.item_atlas.page_index == 2)
      item_atlas.handle_action(s, "prev", 1)
      assert(s.ui.item_atlas.page_index == 1, "prev should go back to page 1")
    end)

    it("page_prev does not go below page 1", function()
      item_atlas.configure_catalog_for_tests(_make_catalog(16))
      local s = _make_state()
      item_atlas.open(s, 1)
      item_atlas.handle_action(s, "prev", 1)
      assert(s.ui.item_atlas.page_index == 1, "prev on page 1 should stay at page 1")
    end)

    it("page_next clears selected_item_id", function()
      item_atlas.configure_catalog_for_tests(_make_catalog(16))
      local s = _make_state()
      item_atlas.open(s, 1)
      item_atlas.handle_action(s, { type = "select", slot_index = 1 }, 1)
      assert(s.ui.item_atlas.selected_item_id == "item_1")
      item_atlas.handle_action(s, "next", 1)
      assert(s.ui.item_atlas.selected_item_id == nil, "page_next should clear selection")
    end)

    it("page_prev clears selected_item_id", function()
      item_atlas.configure_catalog_for_tests(_make_catalog(16))
      local s = _make_state()
      item_atlas.open(s, 1)
      item_atlas.handle_action(s, "next", 1)
      item_atlas.handle_action(s, { type = "select", slot_index = 1 }, 1)
      assert(s.ui.item_atlas.selected_item_id == "item_9")
      item_atlas.handle_action(s, "prev", 1)
      assert(s.ui.item_atlas.selected_item_id == nil, "page_prev should clear selection")
    end)

    it("last page shows remaining items", function()
      item_atlas.configure_catalog_for_tests(_make_catalog(10))
      local s = _make_state()
      item_atlas.open(s, 1)
      item_atlas.handle_action(s, "next", 1)
      assert(s.ui.item_atlas.page_index == 2)
      local count = 0
      for i = 1, 8 do
        local idx = (s.ui.item_atlas.page_index - 1) * 8 + i
        if item_atlas.catalog[idx] then count = count + 1 end
      end
      assert(count == 2, "last page of 10-item catalog should show 2 slots, got " .. tostring(count))
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

  describe("render view", function()
    local function _make_render_state()
      local calls = {}
      local state = {
        ui = {
          set_visible = function(_, name, visible)
            calls[#calls + 1] = { "set_visible", name, visible }
          end,
          set_label = function(_, name, text)
            calls[#calls + 1] = { "set_label", name, text }
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

    local function _stub_runtime()
      local textures = {}
      return {
        query_node = function(name) return { name = name } end,
        set_node_texture_keep_size = function(node, key)
          textures[node.name] = key
        end,
        textures = textures,
      }
    end

    it("shows present items and hides empty slots", function()
      local catalog = _make_catalog(3)
      local state, calls = _make_render_state()
      item_atlas_view.refresh_page(state, catalog, 1)
      for slot = 1, 3 do
        local vis = _find_call(calls, "set_visible", item_atlas_nodes.card_images[slot])
        assert(vis == true, "slot " .. slot .. " with item should be visible")
      end
      for slot = 4, 8 do
        local vis = _find_call(calls, "set_visible", item_atlas_nodes.card_images[slot])
        assert(vis == false, "slot " .. slot .. " without item should be hidden")
      end
    end)

    it("updates page label with current/total", function()
      local catalog = _make_catalog(16)
      local state, calls = _make_render_state()
      item_atlas_view.refresh_page(state, catalog, 2)
      local label = _find_call(calls, "set_label", item_atlas_nodes.title_label)
      assert(label == "2/2", "page label should show 2/2, got: " .. tostring(label))
    end)

    it("sets texture when image refs are provided", function()
      local catalog = { { id = "item_A", name = "A" } }
      local state, _ = _make_render_state()
      state.ui_refs = { images = { item_A = "texture_A" } }
      local runtime = _stub_runtime()
      item_atlas_view.refresh_page(state, catalog, 1, { runtime = runtime })
      assert(runtime.textures[item_atlas_nodes.card_images[1]] == "texture_A",
        "should set texture for item with image ref")
    end)

    it("show_enlarged shows the enlarged-card trio and sets texture", function()
      local state, calls = _make_render_state()
      state.ui_refs = { images = { item_X = "texture_X" } }
      local runtime = _stub_runtime()
      item_atlas_view.show_enlarged(state, "item_X", { runtime = runtime })
      local card_vis = _find_call(calls, "set_visible", item_atlas_nodes.enlarged_card)
      local hint_vis = _find_call(calls, "set_visible", item_atlas_nodes.close_hint_label)
      local blank_vis = _find_call(calls, "set_visible", item_atlas_nodes.close_blank)
      assert(card_vis == true, "enlarged card should be visible")
      assert(hint_vis == true, "close hint should be visible")
      assert(blank_vis == true, "close blank layer should be visible")
      assert(runtime.textures[item_atlas_nodes.enlarged_card] == "texture_X",
        "enlarged card should show correct texture")
    end)

    it("hide_enlarged hides the enlarged-card trio", function()
      local state, calls = _make_render_state()
      item_atlas_view.hide_enlarged(state)
      local card_vis = _find_call(calls, "set_visible", item_atlas_nodes.enlarged_card)
      local hint_vis = _find_call(calls, "set_visible", item_atlas_nodes.close_hint_label)
      local blank_vis = _find_call(calls, "set_visible", item_atlas_nodes.close_blank)
      assert(card_vis == false, "enlarged card should be hidden")
      assert(hint_vis == false, "close hint should be hidden")
      assert(blank_vis == false, "close blank layer should be hidden")
    end)

    it("show_enlarged with missing image ref is a no-op", function()
      local state, calls = _make_render_state()
      item_atlas_view.show_enlarged(state, "no_such_item")
      assert(#calls == 0, "no calls when image ref missing")
    end)

    it("show_enlarged falls back to module-level runtime_ui when deps omitted", function()
      local state, calls = _make_render_state()
      state.ui_refs = { images = { item_X = "texture_X" } }
      local queried = {}
      local prev_query = UIManager.query_nodes_by_name
      UIManager.query_nodes_by_name = function(name)
        queried[name] = (queried[name] or 0) + 1
        return {
          {
            name = name,
            set_texture_keep_size = function(_, _) end,
            set_texture_native_size = function(_, _) end,
          },
        }
      end
      local ok, err = pcall(item_atlas_view.show_enlarged, state, "item_X")
      UIManager.query_nodes_by_name = prev_query
      assert(ok, "show_enlarged should succeed without deps: " .. tostring(err))
      assert(queried[item_atlas_nodes.enlarged_card] == 1,
        "fallback runtime should query enlarged_card via UIManager exactly once")
      local card_vis = _find_call(calls, "set_visible", item_atlas_nodes.enlarged_card)
      assert(card_vis == true, "enlarged card should be visible via fallback path")
    end)

    it("page 2 shows correct items by offset", function()
      local catalog = _make_catalog(12)
      local state, calls = _make_render_state()
      state.ui_refs = { images = {} }
      for i = 1, 12 do
        state.ui_refs.images["item_" .. i] = "tex_" .. i
      end
      local runtime = _stub_runtime()
      item_atlas_view.refresh_page(state, catalog, 2, { runtime = runtime })
      assert(runtime.textures[item_atlas_nodes.card_images[1]] == "tex_9",
        "page 2 slot 1 should show item 9")
      assert(runtime.textures[item_atlas_nodes.card_images[4]] == "tex_12",
        "page 2 slot 4 should show item 12")
      local vis5 = _find_call(calls, "set_visible", item_atlas_nodes.card_images[5])
      assert(vis5 == false, "page 2 slot 5 should be hidden (only 12 items)")
    end)
  end)

  describe("integer action routing", function()
    it("integer action selects slot by index", function()
      item_atlas.configure_catalog_for_tests(_make_catalog(8))
      local s = _make_state()
      item_atlas.open(s, 1)
      item_atlas.handle_action(s, 3, 1)
      assert(s.ui.item_atlas.selected_item_id == "item_3", "integer 3 should select item_3")
    end)
  end)
end)
