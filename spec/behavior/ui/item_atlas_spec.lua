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
    runtime_ports.reset_for_tests()
  end)

  after_each(function()
    runtime_ports.reset_for_tests()
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

    it("open normalizes a nil page_index to page 1", function()
      local s = _make_state()
      s.ui.item_atlas = { open = false, page_index = nil, selected_item_id = "stale" }
      local atlas = item_atlas.open(s, 1)
      assert(atlas.page_index == 1, "nil page_index should reopen at page 1")
    end)

    it("open refreshes page even when the owner role cannot be resolved", function()
      local s = _make_state()
      local refresh_count = 0

      _with_patches({
        { target = runtime_ports, key = "resolve_role", value = function()
          return nil
        end },
        { target = item_atlas_view, key = "refresh_page", value = function()
          refresh_count = refresh_count + 1
        end },
        { target = item_atlas_view, key = "hide_enlarged", value = function() end },
      }, function()
        item_atlas.open(s, 99)
      end)

      assert(refresh_count == 1, "open should refresh atlas page through the global fallback path")
    end)

    it("owner refresh uses the state presentation runtime", function()
      local role = { id = 4 }
      local active_role = nil
      local refresh_role = nil
      local s = _make_state()
      s.presentation_runtime = {
        runtime = {
          with_client_role = function(next_role, fn)
            active_role = next_role
            local result = fn()
            active_role = nil
            return result
          end,
        },
      }

      _with_patches({
        { target = runtime_ports, key = "resolve_role", value = function(role_id)
          if role_id == 4 then
            return role
          end
          return nil
        end },
        { target = item_atlas_view, key = "refresh_page", value = function()
          refresh_role = active_role
        end },
        { target = item_atlas_view, key = "hide_enlarged", value = function() end },
      }, function()
        item_atlas.open(s, 4)
      end)

      assert(refresh_role == role, "owner refresh should run under the provided presentation runtime")
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

    it("select and reselect refresh enlarged-card visibility", function()
      item_atlas.configure_catalog_for_tests(_make_catalog(8))
      local s = _make_state()
      local shown_item_id = nil
      local hide_count = 0

      _with_patches({
        { target = item_atlas_view, key = "show_enlarged", value = function(_, item_id)
          shown_item_id = item_id
        end },
        { target = item_atlas_view, key = "hide_enlarged", value = function()
          hide_count = hide_count + 1
        end },
      }, function()
        item_atlas.open(s, 1)
        local hides_after_open = hide_count
        item_atlas.handle_action(s, { type = "select", slot_index = 2 }, 1)
        item_atlas.handle_action(s, { type = "select", slot_index = 2 }, 1)
        assert(hide_count == hides_after_open + 1, "reselecting the selected item should hide enlarged view")
      end)

      assert(shown_item_id == "item_2", "selecting a non-empty slot should show its enlarged card")
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

    it("nil-role atlas actions keep the existing owner role", function()
      item_atlas.configure_catalog_for_tests(_make_catalog(16))
      local s = _make_state()
      item_atlas.open(s, 7)

      item_atlas.handle_action(s, "next", nil)
      assert(s.ui.item_atlas.role_id == 7, "page movement without role_id should keep atlas owner")

      item_atlas.handle_action(s, { type = "select", slot_index = 1 }, nil)
      assert(s.ui.item_atlas.role_id == 7, "selection without role_id should keep atlas owner")

      item_atlas.handle_action(s, "dismiss", nil)
      assert(s.ui.item_atlas.role_id == 7, "dismiss without role_id should keep atlas owner")
    end)

    it("page_next refreshes card textures for the atlas owner role", function()
      item_atlas.configure_catalog_for_tests(_make_catalog(16))
      local s = _make_state()
      s.ui_refs = { images = {} }
      for i = 1, 16 do
        s.ui_refs.images["item_" .. tostring(i)] = "tex_" .. tostring(i)
      end
      s.ui.set_visible = function() end

      local role2 = {
        get_roleid = function()
          return 2
        end,
        send_ui_custom_event = function() end,
      }
      runtime_ports.configure({
        resolve_role = function(role_id)
          if tostring(role_id) == "2" then
            return role2
          end
          return nil
        end,
      })

      local textures_by_role = {}
      local function _role_key()
        local role = UIManager and UIManager.client_role or nil
        if role and role.get_roleid then
          return role.get_roleid()
        end
        return "global"
      end

      _with_patches({
        { key = "UIManager", value = {
          client_role = nil,
          query_nodes_by_name = function(name)
            return {
              {
                set_texture_keep_size = function(_, key)
                  local role_key = _role_key()
                  textures_by_role[role_key] = textures_by_role[role_key] or {}
                  textures_by_role[role_key][name] = key
                end,
              },
            }
          end,
        } },
      }, function()
        item_atlas.open(s, 2)
        item_atlas.handle_action(s, "next", 2)
      end, { skip_runtime_context_refresh = true })

      local role2_textures = textures_by_role[2] or {}
      assert(role2_textures[item_atlas_nodes.card_images[1]] == "tex_9",
        "page_next should refresh slot 1 texture on the atlas owner role")
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

    it("next action delegates to _page_next", function()
      item_atlas.configure_catalog_for_tests(_make_catalog(16))
      local s = _make_state()
      item_atlas.open(s, 1)
      item_atlas.handle_action(s, "next", 1)
      assert(s.ui.item_atlas.page_index == 2, "next via handle_action should advance page")
    end)

    it("prev action delegates to _page_prev", function()
      item_atlas.configure_catalog_for_tests(_make_catalog(16))
      local s = _make_state()
      item_atlas.open(s, 1)
      item_atlas.handle_action(s, "next", 1)
      item_atlas.handle_action(s, "prev", 1)
      assert(s.ui.item_atlas.page_index == 1, "prev via handle_action should rewind page")
    end)

    it("dismiss action delegates to _dismiss", function()
      item_atlas.configure_catalog_for_tests(_make_catalog(8))
      local s = _make_state()
      item_atlas.open(s, 1)
      item_atlas.handle_action(s, { type = "select", slot_index = 1 }, 1)
      item_atlas.handle_action(s, "dismiss", 1)
      assert(s.ui.item_atlas.selected_item_id == nil, "dismiss via handle_action should clear selection")
    end)

    it("table action with type=select delegates to _select_slot", function()
      item_atlas.configure_catalog_for_tests(_make_catalog(8))
      local s = _make_state()
      item_atlas.open(s, 1)
      item_atlas.handle_action(s, { type = "select", slot_index = 4 }, 1)
      assert(s.ui.item_atlas.selected_item_id == "item_4", "table select should pick the correct slot")
    end)

    it("unknown string action returns state and sets role_id", function()
      local s = _make_state()
      item_atlas.open(s, 1)
      local atlas = item_atlas.handle_action(s, "no_such_action", 2)
      assert(atlas == s.ui.item_atlas, "unknown action should still return atlas state")
      assert(atlas.role_id == 2, "unknown action should update role_id from arg")
    end)

    it("unknown table action returns state without crashing", function()
      local s = _make_state()
      item_atlas.open(s, 1)
      local atlas = item_atlas.handle_action(s, { type = "unknown_intent_kind" }, 1)
      assert(atlas == s.ui.item_atlas, "unknown table action should return atlas state")
    end)

    it("table action with type=select on out-of-range slot leaves selection nil", function()
      item_atlas.configure_catalog_for_tests(_make_catalog(5))
      local s = _make_state()
      item_atlas.open(s, 1)
      item_atlas.handle_action(s, { type = "select", slot_index = 7 }, 1)
      assert(s.ui.item_atlas.selected_item_id == nil, "select on empty slot leaves selection nil")
    end)
  end)

  describe("_select_slot branches", function()
    it("re-selecting the same slot clears the selection (toggle off)", function()
      item_atlas.configure_catalog_for_tests(_make_catalog(8))
      local s = _make_state()
      item_atlas.open(s, 1)
      item_atlas.handle_action(s, { type = "select", slot_index = 3 }, 1)
      assert(s.ui.item_atlas.selected_item_id == "item_3", "first select should pick item_3")
      item_atlas.handle_action(s, { type = "select", slot_index = 3 }, 1)
      assert(s.ui.item_atlas.selected_item_id == nil, "second select on same slot should clear selection")
    end)

    it("selecting a different slot replaces the selection", function()
      item_atlas.configure_catalog_for_tests(_make_catalog(8))
      local s = _make_state()
      item_atlas.open(s, 1)
      item_atlas.handle_action(s, { type = "select", slot_index = 2 }, 1)
      assert(s.ui.item_atlas.selected_item_id == "item_2")
      item_atlas.handle_action(s, { type = "select", slot_index = 5 }, 1)
      assert(s.ui.item_atlas.selected_item_id == "item_5", "selecting another slot should replace selection")
    end)

    it("selecting an empty slot does not clear an existing selection", function()
      item_atlas.configure_catalog_for_tests(_make_catalog(5))
      local s = _make_state()
      item_atlas.open(s, 1)
      item_atlas.handle_action(s, { type = "select", slot_index = 3 }, 1)
      assert(s.ui.item_atlas.selected_item_id == "item_3")
      item_atlas.handle_action(s, { type = "select", slot_index = 7 }, 1)
      assert(s.ui.item_atlas.selected_item_id == "item_3",
        "empty-slot click while item selected must leave selection intact")
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
          set_touch_enabled = function(_, name, enabled)
            calls[#calls + 1] = { "set_touch_enabled", name, enabled }
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

    it("disables touch for hidden empty card slots", function()
      local catalog = _make_catalog(3)
      local state, calls = _make_render_state()
      item_atlas_view.refresh_page(state, catalog, 1)
      for slot = 1, 3 do
        local enabled = _find_call(calls, "set_touch_enabled", item_atlas_nodes.card_images[slot])
        assert(enabled == true, "slot " .. slot .. " with item should be touch-enabled")
      end
      for slot = 4, 8 do
        local enabled = _find_call(calls, "set_touch_enabled", item_atlas_nodes.card_images[slot])
        assert(enabled == false, "hidden slot " .. slot .. " must not consume clicks")
      end
    end)

    it("never writes the static title label on refresh_page", function()
      local catalog = _make_catalog(16)
      local state, calls = _make_render_state()
      item_atlas_view.refresh_page(state, catalog, 2)
      for _, c in ipairs(calls) do
        assert(not (c[1] == "set_label" and c[2] == "图鉴_图鉴文本"),
          "refresh_page must not write to 图鉴_图鉴文本")
      end
    end)

    it("single-page catalog hides both prev and next arrows", function()
      local catalog = _make_catalog(8)
      local state, calls = _make_render_state()
      item_atlas_view.refresh_page(state, catalog, 1)
      assert(_find_call(calls, "set_visible", item_atlas_nodes.page_prev) == false,
        "prev arrow should be hidden on single-page catalog")
      assert(_find_call(calls, "set_visible", item_atlas_nodes.page_next) == false,
        "next arrow should be hidden on single-page catalog")
    end)

    it("multi-page first page shows only next arrow", function()
      local catalog = _make_catalog(16)
      local state, calls = _make_render_state()
      item_atlas_view.refresh_page(state, catalog, 1)
      assert(_find_call(calls, "set_visible", item_atlas_nodes.page_prev) == false,
        "prev arrow should be hidden on first page")
      assert(_find_call(calls, "set_visible", item_atlas_nodes.page_next) == true,
        "next arrow should be visible on first page of multi-page catalog")
      assert(_find_call(calls, "set_touch_enabled", item_atlas_nodes.page_prev) == false,
        "hidden prev arrow must not consume clicks on first page")
      assert(_find_call(calls, "set_touch_enabled", item_atlas_nodes.page_next) == true,
        "visible next arrow should be touchable on first page")
    end)

    it("multi-page middle page shows both arrows", function()
      local catalog = _make_catalog(24)
      local state, calls = _make_render_state()
      item_atlas_view.refresh_page(state, catalog, 2)
      assert(_find_call(calls, "set_visible", item_atlas_nodes.page_prev) == true,
        "prev arrow should be visible on middle page")
      assert(_find_call(calls, "set_visible", item_atlas_nodes.page_next) == true,
        "next arrow should be visible on middle page")
    end)

    it("multi-page last page shows only prev arrow", function()
      local catalog = _make_catalog(16)
      local state, calls = _make_render_state()
      item_atlas_view.refresh_page(state, catalog, 2)
      assert(_find_call(calls, "set_visible", item_atlas_nodes.page_prev) == true,
        "prev arrow should be visible on last page")
      assert(_find_call(calls, "set_visible", item_atlas_nodes.page_next) == false,
        "next arrow should be hidden on last page")
      assert(_find_call(calls, "set_touch_enabled", item_atlas_nodes.page_prev) == true,
        "visible prev arrow should be touchable on last page")
      assert(_find_call(calls, "set_touch_enabled", item_atlas_nodes.page_next) == false,
        "hidden next arrow must not consume clicks on last page")
    end)

    it("single-page catalog with out-of-range page_index still hides both arrows", function()
      local catalog = _make_catalog(8)
      local state, calls = _make_render_state()
      item_atlas_view.refresh_page(state, catalog, 5)
      assert(_find_call(calls, "set_visible", item_atlas_nodes.page_prev) == false,
        "single-page catalog must keep prev arrow hidden regardless of page_index")
      assert(_find_call(calls, "set_visible", item_atlas_nodes.page_next) == false,
        "single-page catalog must keep next arrow hidden regardless of page_index")
    end)

    it("refresh_page queries exactly PAGE_SIZE card nodes on a full page", function()
      local catalog = _make_catalog(8)
      local state, _ = _make_render_state()
      state.ui_refs = { images = {} }
      for i = 1, 8 do
        state.ui_refs.images["item_" .. i] = "tex_" .. i
      end
      local query_count = 0
      local runtime = {
        query_node = function(name)
          query_count = query_count + 1
          return { name = name }
        end,
        set_node_texture_keep_size = function(_, _) end,
      }
      item_atlas_view.refresh_page(state, catalog, 1, { runtime = runtime })
      assert(query_count == 8,
        "refresh_page should query exactly 8 card nodes for a full page, got " .. tostring(query_count))
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

    it("sets texture on all matched card nodes when runtime exposes query_nodes", function()
      local catalog = { { id = "item_A", name = "A" } }
      local state, _ = _make_render_state()
      state.ui_refs = { images = { item_A = "texture_A" } }
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
      item_atlas_view.refresh_page(state, catalog, 1, { runtime = runtime })
      assert(textures[item_atlas_nodes.card_images[1] .. "#a"] == "texture_A",
        "should set texture on first matched node")
      assert(textures[item_atlas_nodes.card_images[1] .. "#b"] == "texture_A",
        "should set texture on second matched node")
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
      assert(_find_call(calls, "set_touch_enabled", item_atlas_nodes.close_blank) == true,
        "visible blank close layer should be touchable")
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
      assert(_find_call(calls, "set_touch_enabled", item_atlas_nodes.close_blank) == false,
        "hidden blank close layer must not consume clicks")
    end)

    it("show_enlarged sets texture on all matched nodes when runtime exposes query_nodes", function()
      local state = _make_render_state()
      state.ui_refs = { images = { item_X = "texture_X" } }
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
      item_atlas_view.show_enlarged(state, "item_X", { runtime = runtime })
      assert(textures[item_atlas_nodes.enlarged_card .. "#a"] == "texture_X",
        "should set texture on first matched enlarged node")
      assert(textures[item_atlas_nodes.enlarged_card .. "#b"] == "texture_X",
        "should set texture on second matched enlarged node")
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

  -- T16 mutation-pinning addendum.
  --
  -- _ensure_state defaults observed via unknown-action path (which calls
  -- _ensure_state then returns the atlas without further mutation). open() is
  -- intentionally NOT called first so the defaults remain visible.
  --
  describe("_ensure_state defaults (L18, L19 pin)", function()
    it("initial open flag is false until item_atlas.open() flips it (L18)", function()
      local s = _make_state()
      local atlas = item_atlas.handle_action(s, "no_such_action", 1)
      assert(atlas.open == false,
        "default atlas.open must be false; L18 mutation flips _ensure_state default to true. " ..
        "Got: " .. tostring(atlas.open))
    end)

    it("initial page_index is 1 so _item_at points at catalog[1] (L19)", function()
      item_atlas.configure_catalog_for_tests(_make_catalog(8))
      local s = _make_state()
      -- handle_action with unknown action triggers _ensure_state without overwriting
      -- page_index. Then a select with slot_index=1 should resolve to catalog[1] (page 1).
      item_atlas.handle_action(s, "no_such_action", 1)
      local atlas = s.ui.item_atlas
      assert(atlas.page_index == 1,
        "default page_index must be 1; L19 mutation makes it 0. Got: " .. tostring(atlas.page_index))
      -- Cross-check via _item_at: page_index=1 + slot 1 ⇒ item_1; mutated page_index=0 ⇒
      -- catalog[(0-1)*8+1] = catalog[-7] = nil ⇒ no selection.
      item_atlas.handle_action(s, { type = "select", slot_index = 1 }, 1)
      assert(s.ui.item_atlas.selected_item_id == "item_1",
        "page_index default must allow selecting item_1; L19 makes catalog index negative. " ..
        "Got: " .. tostring(s.ui.item_atlas.selected_item_id))
    end)
  end)

  describe("_item_at slot fallback (L31 pin)", function()
    it("select with nil slot_index resolves to catalog slot 1 (L31)", function()
      item_atlas.configure_catalog_for_tests(_make_catalog(8))
      local s = _make_state()
      item_atlas.open(s, 1)
      -- slot_index=nil → _item_at(atlas, nil) → to_integer(nil) is nil → fallback to 1.
      -- Original: catalog[(1-1)*8 + 1] = catalog[1] = item_1 → selection set.
      -- Mutated `or 0`: catalog[(1-1)*8 + 0] = catalog[0] = nil → no selection.
      item_atlas.handle_action(s, { type = "select", slot_index = nil }, 1)
      assert(s.ui.item_atlas.selected_item_id == "item_1",
        "_item_at fallback must pick slot 1 when slot_index is nil; L31 mutation `or 1 → or 0` " ..
        "makes catalog[0] = nil and leaves selection unset. Got: " ..
        tostring(s.ui.item_atlas.selected_item_id))
    end)
  end)
end)
