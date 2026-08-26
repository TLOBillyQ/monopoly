local lu = require("luaunit")
local support = require("test.support.shared_support")
local _with_patches = support.with_patches
local _build_role_with_events = support.build_role_with_events
local _has_event = support.has_event
local item_atlas = require("src.ui.screens.item_atlas")
local item_atlas_view = require("src.ui.render.widgets.item_atlas")
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

local function _make_render_state()
  local calls = {}
  local state = {
    ui = {
      set_visible = function(_, name, visible)
        calls[#calls + 1] = { "set_visible", name, visible }
      end,
      -- #544 退役钉:global 广播变体已拆除,单独打标记录;
      -- 放大/隐藏用例断言零调用(旁观者泄漏即由广播变体造成)。
      set_visible_global = function(_, name, visible)
        calls[#calls + 1] = { "set_visible_global", name, visible }
      end,
      set_touch_enabled = function(_, name, enabled)
        calls[#calls + 1] = { "set_touch_enabled", name, enabled }
      end,
      set_touch_enabled_global = function(_, name, enabled)
        calls[#calls + 1] = { "set_touch_enabled_global", name, enabled }
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

TestItemAtlas = {}

function TestItemAtlas:setUp()
  item_atlas.reset_for_tests()
  runtime_ports.reset_for_tests()
end

function TestItemAtlas:tearDown()
  runtime_ports.reset_for_tests()
  -- 拆了共享端口基线必须装回,否则 mutate 车道窄 suite 子集会撞空端口(#217)。
  support.restore_runtime_services()
end

function TestItemAtlas:test_marks_atlas_open_after_open()
  local s = _make_state()
  local atlas = item_atlas.open(s, 1)
  lu.assertEvalToTrue(atlas.open == true, "atlas should be open")
end

function TestItemAtlas:test_opens_the_atlas_canvas_for_the_active_role()
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

  lu.assertEvalToTrue(_has_event(events, "显示道具图鉴"), "opening atlas should show atlas canvas")
end

function TestItemAtlas:test_open_normalizes_a_nil_page_index_to_page_1()
  local s = _make_state()
  s.ui.item_atlas = { open = false, page_index = nil, selected_item_id = "stale" }
  local atlas = item_atlas.open(s, 1)
  lu.assertEvalToTrue(atlas.page_index == 1, "nil page_index should reopen at page 1")
end

function TestItemAtlas:test_open_refreshes_page_even_when_the_owner_role_cannot_be_resolved()
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

  lu.assertEvalToTrue(refresh_count == 1, "open should refresh atlas page through the global fallback path")
end

function TestItemAtlas:test_owner_refresh_uses_the_state_presentation_runtime()
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

  lu.assertEvalToTrue(refresh_role == role, "owner refresh should run under the provided presentation runtime")
end

function TestItemAtlas:test_marks_atlas_closed_after_close()
  local s = _make_state()
  item_atlas.open(s, 1)
  local atlas = item_atlas.close(s)
  lu.assertEvalToTrue(atlas.open == false, "atlas should be closed")
end

function TestItemAtlas:test_closes_the_atlas_canvas_for_the_active_role()
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

  lu.assertEvalToTrue(_has_event(events, "隐藏道具图鉴"), "closing atlas should hide atlas canvas")
end

function TestItemAtlas:test_configure_catalog_for_tests_replaces_active_catalog()
  local cat = _make_catalog(5)
  item_atlas.configure_catalog_for_tests(cat)
  lu.assertEvalToTrue(#item_atlas.catalog == 5, "catalog size should be 5")
end

function TestItemAtlas:test_reset_for_tests_restores_default_catalog_size()
  item_atlas.configure_catalog_for_tests(_make_catalog(3))
  item_atlas.reset_for_tests()
  lu.assertEvalToTrue(#item_atlas.catalog == 19, "default catalog has 19 items")
end

function TestItemAtlas:test_select_slot_records_selected_item_id()
  item_atlas.configure_catalog_for_tests(_make_catalog(8))
  local s = _make_state()
  item_atlas.open(s, 1)
  item_atlas.handle_action(s, { type = "select", slot_index = 1 }, 1)
  lu.assertEvalToTrue(s.ui.item_atlas.selected_item_id == "item_1", "slot 1 should select item_1")
end

function TestItemAtlas:test_select_slot_5_records_item_5()
  item_atlas.configure_catalog_for_tests(_make_catalog(8))
  local s = _make_state()
  item_atlas.open(s, 1)
  item_atlas.handle_action(s, { type = "select", slot_index = 5 }, 1)
  lu.assertEvalToTrue(s.ui.item_atlas.selected_item_id == "item_5", "slot 5 should select item_5")
end

function TestItemAtlas:test_selecting_empty_slot_does_not_set_selected_item_id()
  item_atlas.configure_catalog_for_tests(_make_catalog(5))
  local s = _make_state()
  item_atlas.open(s, 1)
  item_atlas.handle_action(s, { type = "select", slot_index = 7 }, 1)
  lu.assertEvalToTrue(s.ui.item_atlas.selected_item_id == nil, "empty slot should leave selection nil")
end

function TestItemAtlas:test_dismiss_action_clears_selected_item_id()
  item_atlas.configure_catalog_for_tests(_make_catalog(8))
  local s = _make_state()
  item_atlas.open(s, 1)
  item_atlas.handle_action(s, { type = "select", slot_index = 1 }, 1)
  lu.assertEvalToTrue(s.ui.item_atlas.selected_item_id == "item_1")
  item_atlas.handle_action(s, "dismiss", 1)
  lu.assertEvalToTrue(s.ui.item_atlas.selected_item_id == nil, "dismiss should clear selection")
end

function TestItemAtlas:test_dismiss_action_never_dispatches_anim_done()
  -- #543:图鉴放大卡回归纯浏览用途,获得展示不再经过图鉴屏;
  -- dismiss 只收浏览放大卡,不再向回合机派发 action_anim_done。
  local s = _make_state()
  local dispatched = {}
  s.game = {
    turn = {
      action_anim = { seq = 33, kind = "item_gain_popup", player_id = 7 },
    },
    dispatch_action = function(_, action)
      dispatched[#dispatched + 1] = action
    end,
  }

  item_atlas.handle_action(s, "dismiss", 7)
  lu.assertEvalToTrue(#dispatched == 0, "dismiss must not dispatch action_anim_done")
end

function TestItemAtlas:test_dismiss_action_tolerates_state_without_dispatch_action()
  local s = _make_state()
  s.game = {
    turn = {
      action_anim = { seq = 33, kind = "item_gain_popup", player_id = 7 },
    },
  }

  item_atlas.handle_action(s, "dismiss", 7)
  lu.assertEvalToTrue(s.ui.item_atlas ~= nil, "dismiss should leave atlas state valid")
end

function TestItemAtlas:test_select_and_reselect_refresh_enlarged_card_visibility()
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
    lu.assertEvalToTrue(hide_count == hides_after_open + 1, "reselecting the selected item should hide enlarged view")
  end)

  lu.assertEvalToTrue(shown_item_id == "item_2", "selecting a non-empty slot should show its enlarged card")
end

function TestItemAtlas:test_page_next_advances_page_when_multiple_pages_exist()
  item_atlas.configure_catalog_for_tests(_make_catalog(16))
  local s = _make_state()
  item_atlas.open(s, 1)
  item_atlas.handle_action(s, "next", 1)
  lu.assertEvalToTrue(s.ui.item_atlas.page_index == 2, "page should advance to 2")
end

function TestItemAtlas:test_page_next_does_not_exceed_max_page()
  item_atlas.configure_catalog_for_tests(_make_catalog(8))
  local s = _make_state()
  item_atlas.open(s, 1)
  item_atlas.handle_action(s, "next", 1)
  item_atlas.handle_action(s, "next", 1)
  lu.assertEvalToTrue(s.ui.item_atlas.page_index == 1, "single-page atlas should clamp to page 1")
end

function TestItemAtlas:test_page_prev_goes_to_previous_page()
  item_atlas.configure_catalog_for_tests(_make_catalog(16))
  local s = _make_state()
  item_atlas.open(s, 1)
  item_atlas.handle_action(s, "next", 1)
  lu.assertEvalToTrue(s.ui.item_atlas.page_index == 2)
  item_atlas.handle_action(s, "prev", 1)
  lu.assertEvalToTrue(s.ui.item_atlas.page_index == 1, "prev should go back to page 1")
end

function TestItemAtlas:test_page_prev_does_not_go_below_page_1()
  item_atlas.configure_catalog_for_tests(_make_catalog(16))
  local s = _make_state()
  item_atlas.open(s, 1)
  item_atlas.handle_action(s, "prev", 1)
  lu.assertEvalToTrue(s.ui.item_atlas.page_index == 1, "prev on page 1 should stay at page 1")
end

function TestItemAtlas:test_page_next_clears_selected_item_id()
  item_atlas.configure_catalog_for_tests(_make_catalog(16))
  local s = _make_state()
  item_atlas.open(s, 1)
  item_atlas.handle_action(s, { type = "select", slot_index = 1 }, 1)
  lu.assertEvalToTrue(s.ui.item_atlas.selected_item_id == "item_1")
  item_atlas.handle_action(s, "next", 1)
  lu.assertEvalToTrue(s.ui.item_atlas.selected_item_id == nil, "page_next should clear selection")
end

function TestItemAtlas:test_nil_role_atlas_actions_keep_the_existing_owner_role()
  item_atlas.configure_catalog_for_tests(_make_catalog(16))
  local s = _make_state()
  item_atlas.open(s, 7)

  item_atlas.handle_action(s, "next", nil)
  lu.assertEvalToTrue(s.ui.item_atlas.role_id == 7, "page movement without role_id should keep atlas owner")

  item_atlas.handle_action(s, { type = "select", slot_index = 1 }, nil)
  lu.assertEvalToTrue(s.ui.item_atlas.role_id == 7, "selection without role_id should keep atlas owner")

  item_atlas.handle_action(s, "dismiss", nil)
  lu.assertEvalToTrue(s.ui.item_atlas.role_id == 7, "dismiss without role_id should keep atlas owner")
end

function TestItemAtlas:test_page_next_refreshes_card_textures_for_the_atlas_owner_role()
  item_atlas.configure_catalog_for_tests(_make_catalog(16))
  local s = _make_state()
  s.runtime_asset_context = { refs = { images = {} } }
  for i = 1, 16 do
    s.runtime_asset_context.refs.images["item_" .. tostring(i)] = "tex_" .. tostring(i)
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
  lu.assertEvalToTrue(role2_textures[item_atlas_nodes.card_images[1]] == "tex_9",
    "page_next should refresh slot 1 texture on the atlas owner role")
end

function TestItemAtlas:test_page_prev_clears_selected_item_id()
  item_atlas.configure_catalog_for_tests(_make_catalog(16))
  local s = _make_state()
  item_atlas.open(s, 1)
  item_atlas.handle_action(s, "next", 1)
  item_atlas.handle_action(s, { type = "select", slot_index = 1 }, 1)
  lu.assertEvalToTrue(s.ui.item_atlas.selected_item_id == "item_9")
  item_atlas.handle_action(s, "prev", 1)
  lu.assertEvalToTrue(s.ui.item_atlas.selected_item_id == nil, "page_prev should clear selection")
end

function TestItemAtlas:test_unknown_string_action_returns_state_and_sets_role_id()
  local s = _make_state()
  item_atlas.open(s, 1)
  local atlas = item_atlas.handle_action(s, "no_such_action", 2)
  lu.assertEvalToTrue(atlas == s.ui.item_atlas, "unknown action should still return atlas state")
  lu.assertEvalToTrue(atlas.role_id == 2, "unknown action should update role_id from arg")
end

function TestItemAtlas:test_unknown_table_action_returns_state_without_crashing()
  local s = _make_state()
  item_atlas.open(s, 1)
  local atlas = item_atlas.handle_action(s, { type = "unknown_intent_kind" }, 1)
  lu.assertEvalToTrue(atlas == s.ui.item_atlas, "unknown table action should return atlas state")
end

function TestItemAtlas:test_re_selecting_the_same_slot_clears_the_selection_toggle_off()
  item_atlas.configure_catalog_for_tests(_make_catalog(8))
  local s = _make_state()
  item_atlas.open(s, 1)
  item_atlas.handle_action(s, { type = "select", slot_index = 3 }, 1)
  lu.assertEvalToTrue(s.ui.item_atlas.selected_item_id == "item_3", "first select should pick item_3")
  item_atlas.handle_action(s, { type = "select", slot_index = 3 }, 1)
  lu.assertEvalToTrue(s.ui.item_atlas.selected_item_id == nil, "second select on same slot should clear selection")
end

function TestItemAtlas:test_selecting_a_different_slot_replaces_the_selection()
  item_atlas.configure_catalog_for_tests(_make_catalog(8))
  local s = _make_state()
  item_atlas.open(s, 1)
  item_atlas.handle_action(s, { type = "select", slot_index = 2 }, 1)
  lu.assertEvalToTrue(s.ui.item_atlas.selected_item_id == "item_2")
  item_atlas.handle_action(s, { type = "select", slot_index = 5 }, 1)
  lu.assertEvalToTrue(s.ui.item_atlas.selected_item_id == "item_5", "selecting another slot should replace selection")
end

function TestItemAtlas:test_selecting_an_empty_slot_does_not_clear_an_existing_selection()
  item_atlas.configure_catalog_for_tests(_make_catalog(5))
  local s = _make_state()
  item_atlas.open(s, 1)
  item_atlas.handle_action(s, { type = "select", slot_index = 3 }, 1)
  lu.assertEvalToTrue(s.ui.item_atlas.selected_item_id == "item_3")
  item_atlas.handle_action(s, { type = "select", slot_index = 7 }, 1)
  lu.assertEvalToTrue(s.ui.item_atlas.selected_item_id == "item_3",
    "empty-slot click while item selected must leave selection intact")
end

function TestItemAtlas:test_shows_present_items_and_hides_empty_slots()
  local catalog = _make_catalog(3)
  local state, calls = _make_render_state()
  item_atlas_view.refresh_page(state, catalog, 1)
  for slot = 1, 3 do
    local vis = _find_call(calls, "set_visible", item_atlas_nodes.card_images[slot])
    lu.assertEvalToTrue(vis == true, "slot " .. slot .. " with item should be visible")
  end
  for slot = 4, 8 do
    local vis = _find_call(calls, "set_visible", item_atlas_nodes.card_images[slot])
    lu.assertEvalToTrue(vis == false, "slot " .. slot .. " without item should be hidden")
  end
end

function TestItemAtlas:test_disables_touch_for_hidden_empty_card_slots()
  local catalog = _make_catalog(3)
  local state, calls = _make_render_state()
  item_atlas_view.refresh_page(state, catalog, 1)
  for slot = 1, 3 do
    local enabled = _find_call(calls, "set_touch_enabled", item_atlas_nodes.card_images[slot])
    lu.assertEvalToTrue(enabled == true, "slot " .. slot .. " with item should be touch-enabled")
  end
  for slot = 4, 8 do
    local enabled = _find_call(calls, "set_touch_enabled", item_atlas_nodes.card_images[slot])
    lu.assertEvalToTrue(enabled == false, "hidden slot " .. slot .. " must not consume clicks")
  end
end

function TestItemAtlas:test_never_writes_the_static_title_label_on_refresh_page()
  local catalog = _make_catalog(16)
  local state, calls = _make_render_state()
  item_atlas_view.refresh_page(state, catalog, 2)
  for _, c in ipairs(calls) do
    lu.assertEvalToTrue(not (c[1] == "set_label" and c[2] == "图鉴_图鉴文本"),
      "refresh_page must not write to 图鉴_图鉴文本")
  end
end

function TestItemAtlas:test_single_page_catalog_hides_both_prev_and_next_arrows()
  local catalog = _make_catalog(8)
  local state, calls = _make_render_state()
  item_atlas_view.refresh_page(state, catalog, 1)
  lu.assertEvalToTrue(_find_call(calls, "set_visible", item_atlas_nodes.page_prev) == false,
    "prev arrow should be hidden on single-page catalog")
  lu.assertEvalToTrue(_find_call(calls, "set_visible", item_atlas_nodes.page_next) == false,
    "next arrow should be hidden on single-page catalog")
end

function TestItemAtlas:test_multi_page_first_page_shows_only_next_arrow()
  local catalog = _make_catalog(16)
  local state, calls = _make_render_state()
  item_atlas_view.refresh_page(state, catalog, 1)
  lu.assertEvalToTrue(_find_call(calls, "set_visible", item_atlas_nodes.page_prev) == false,
    "prev arrow should be hidden on first page")
  lu.assertEvalToTrue(_find_call(calls, "set_visible", item_atlas_nodes.page_next) == true,
    "next arrow should be visible on first page of multi-page catalog")
  lu.assertEvalToTrue(_find_call(calls, "set_touch_enabled", item_atlas_nodes.page_prev) == false,
    "hidden prev arrow must not consume clicks on first page")
  lu.assertEvalToTrue(_find_call(calls, "set_touch_enabled", item_atlas_nodes.page_next) == true,
    "visible next arrow should be touchable on first page")
end

function TestItemAtlas:test_multi_page_middle_page_shows_both_arrows()
  local catalog = _make_catalog(24)
  local state, calls = _make_render_state()
  item_atlas_view.refresh_page(state, catalog, 2)
  lu.assertEvalToTrue(_find_call(calls, "set_visible", item_atlas_nodes.page_prev) == true,
    "prev arrow should be visible on middle page")
  lu.assertEvalToTrue(_find_call(calls, "set_visible", item_atlas_nodes.page_next) == true,
    "next arrow should be visible on middle page")
end

function TestItemAtlas:test_multi_page_last_page_shows_only_prev_arrow()
  local catalog = _make_catalog(16)
  local state, calls = _make_render_state()
  item_atlas_view.refresh_page(state, catalog, 2)
  lu.assertEvalToTrue(_find_call(calls, "set_visible", item_atlas_nodes.page_prev) == true,
    "prev arrow should be visible on last page")
  lu.assertEvalToTrue(_find_call(calls, "set_visible", item_atlas_nodes.page_next) == false,
    "next arrow should be hidden on last page")
  lu.assertEvalToTrue(_find_call(calls, "set_touch_enabled", item_atlas_nodes.page_prev) == true,
    "visible prev arrow should be touchable on last page")
  lu.assertEvalToTrue(_find_call(calls, "set_touch_enabled", item_atlas_nodes.page_next) == false,
    "hidden next arrow must not consume clicks on last page")
end

function TestItemAtlas:test_single_page_catalog_with_out_of_range_page_index_still_hides_both_arrows()
  local catalog = _make_catalog(8)
  local state, calls = _make_render_state()
  item_atlas_view.refresh_page(state, catalog, 5)
  lu.assertEvalToTrue(_find_call(calls, "set_visible", item_atlas_nodes.page_prev) == false,
    "single-page catalog must keep prev arrow hidden regardless of page_index")
  lu.assertEvalToTrue(_find_call(calls, "set_visible", item_atlas_nodes.page_next) == false,
    "single-page catalog must keep next arrow hidden regardless of page_index")
end

function TestItemAtlas:test_refresh_page_queries_exactly_page_size_card_nodes_on_a_full_page()
  local catalog = _make_catalog(8)
  local state, _ = _make_render_state()
  state.runtime_asset_context = { refs = { images = {} } }
  for i = 1, 8 do
    state.runtime_asset_context.refs.images["item_" .. i] = "tex_" .. i
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
  lu.assertEvalToTrue(query_count == 8,
    "refresh_page should query exactly 8 card nodes for a full page, got " .. tostring(query_count))
end

function TestItemAtlas:test_sets_texture_when_image_refs_are_provided()
  local catalog = { { id = "item_A", name = "A" } }
  local state, _ = _make_render_state()
  state.runtime_asset_context = { refs = { images = { item_A = "texture_A" } } }
  local runtime = _stub_runtime()
  item_atlas_view.refresh_page(state, catalog, 1, { runtime = runtime })
  lu.assertEvalToTrue(runtime.textures[item_atlas_nodes.card_images[1]] == "texture_A",
    "should set texture for item with image ref")
end

function TestItemAtlas:test_sets_texture_from_resolver_asset_context()
  local catalog = { { id = "item_A", name = "A" } }
  local state, _ = _make_render_state()
  state.runtime_asset_context = { refs = { images = { item_A = "texture_A" } } }
  local runtime = _stub_runtime()

  item_atlas_view.refresh_page(state, catalog, 1, { runtime = runtime })

  lu.assertEvalToTrue(runtime.textures[item_atlas_nodes.card_images[1]] == "texture_A",
    "item atlas renderer should consume resolver asset context")
end

function TestItemAtlas:test_sets_texture_on_all_matched_card_nodes_when_runtime_exposes_query_nodes()
  local catalog = { { id = "item_A", name = "A" } }
  local state, _ = _make_render_state()
  state.runtime_asset_context = { refs = { images = { item_A = "texture_A" } } }
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
  lu.assertEvalToTrue(textures[item_atlas_nodes.card_images[1] .. "#a"] == "texture_A",
    "should set texture on first matched node")
  lu.assertEvalToTrue(textures[item_atlas_nodes.card_images[1] .. "#b"] == "texture_A",
    "should set texture on second matched node")
end

function TestItemAtlas:test_show_enlarged_shows_the_enlarged_card_trio_and_sets_texture()
  local state, calls = _make_render_state()
  state.runtime_asset_context = { refs = { images = { item_X = "texture_X" } } }
  local runtime = _stub_runtime()
  item_atlas_view.show_enlarged(state, "item_X", { runtime = runtime })
  local card_vis = _find_call(calls, "set_visible", item_atlas_nodes.enlarged_card)
  local hint_vis = _find_call(calls, "set_visible", item_atlas_nodes.close_hint_label)
  local blank_vis = _find_call(calls, "set_visible", item_atlas_nodes.close_blank)
  lu.assertEvalToTrue(card_vis == true, "enlarged card should be visible")
  lu.assertEvalToTrue(hint_vis == true, "close hint should be visible")
  lu.assertEvalToTrue(blank_vis == true, "close blank layer should be visible")
  lu.assertEvalToTrue(_find_call(calls, "set_touch_enabled", item_atlas_nodes.close_blank) == true,
    "visible blank close layer should be touchable")
  lu.assertEvalToTrue(runtime.textures[item_atlas_nodes.enlarged_card] == "texture_X",
    "enlarged card should show correct texture")
  lu.assertEvalToTrue(_find_call(calls, "set_visible_global", item_atlas_nodes.enlarged_card) == nil,
    "enlarged overlay must not use global broadcast variants (#544)")
  lu.assertEvalToTrue(_find_call(calls, "set_touch_enabled_global", item_atlas_nodes.close_blank) == nil,
    "close blank touch must not use global broadcast variants (#544)")
end

function TestItemAtlas:test_hide_enlarged_hides_the_enlarged_card_trio()
  local state, calls = _make_render_state()
  item_atlas_view.hide_enlarged(state)
  local card_vis = _find_call(calls, "set_visible", item_atlas_nodes.enlarged_card)
  local hint_vis = _find_call(calls, "set_visible", item_atlas_nodes.close_hint_label)
  local blank_vis = _find_call(calls, "set_visible", item_atlas_nodes.close_blank)
  lu.assertEvalToTrue(card_vis == false, "enlarged card should be hidden")
  lu.assertEvalToTrue(hint_vis == false, "close hint should be hidden")
  lu.assertEvalToTrue(blank_vis == false, "close blank layer should be hidden")
  lu.assertEvalToTrue(_find_call(calls, "set_touch_enabled", item_atlas_nodes.close_blank) == false,
    "hidden blank close layer must not consume clicks")
  lu.assertEvalToTrue(_find_call(calls, "set_visible_global", item_atlas_nodes.enlarged_card) == nil,
    "hide enlarged must not use global broadcast variants (#544)")
end

function TestItemAtlas:test_show_enlarged_sets_texture_on_all_matched_nodes_when_runtime_exposes_query_nodes()
  local state = _make_render_state()
  state.runtime_asset_context = { refs = { images = { item_X = "texture_X" } } }
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
  lu.assertEvalToTrue(textures[item_atlas_nodes.enlarged_card .. "#a"] == "texture_X",
    "should set texture on first matched enlarged node")
  lu.assertEvalToTrue(textures[item_atlas_nodes.enlarged_card .. "#b"] == "texture_X",
    "should set texture on second matched enlarged node")
end

function TestItemAtlas:test_show_enlarged_with_missing_image_ref_is_a_no_op()
  local state, calls = _make_render_state()
  item_atlas_view.show_enlarged(state, "no_such_item")
  lu.assertEvalToTrue(#calls == 0, "no calls when image ref missing")
end

function TestItemAtlas:test_show_enlarged_falls_back_to_module_level_runtime_ui_when_deps_omitted()
  local state, calls = _make_render_state()
  state.runtime_asset_context = { refs = { images = { item_X = "texture_X" } } }
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
  lu.assertEvalToTrue(ok, "show_enlarged should succeed without deps: " .. tostring(err))
  lu.assertEvalToTrue(queried[item_atlas_nodes.enlarged_card] == 1,
    "fallback runtime should query enlarged_card via UIManager exactly once")
  local card_vis = _find_call(calls, "set_visible", item_atlas_nodes.enlarged_card)
  lu.assertEvalToTrue(card_vis == true, "enlarged card should be visible via fallback path")
end

function TestItemAtlas:test_page_2_shows_correct_items_by_offset()
  local catalog = _make_catalog(12)
  local state, calls = _make_render_state()
  state.runtime_asset_context = { refs = { images = {} } }
  for i = 1, 12 do
    state.runtime_asset_context.refs.images["item_" .. i] = "tex_" .. i
  end
  local runtime = _stub_runtime()
  item_atlas_view.refresh_page(state, catalog, 2, { runtime = runtime })
  lu.assertEvalToTrue(runtime.textures[item_atlas_nodes.card_images[1]] == "tex_9",
    "page 2 slot 1 should show item 9")
  lu.assertEvalToTrue(runtime.textures[item_atlas_nodes.card_images[4]] == "tex_12",
    "page 2 slot 4 should show item 12")
  local vis5 = _find_call(calls, "set_visible", item_atlas_nodes.card_images[5])
  lu.assertEvalToTrue(vis5 == false, "page 2 slot 5 should be hidden (only 12 items)")
end

function TestItemAtlas:test_integer_action_selects_slot_by_index()
  item_atlas.configure_catalog_for_tests(_make_catalog(8))
  local s = _make_state()
  item_atlas.open(s, 1)
  item_atlas.handle_action(s, 3, 1)
  lu.assertEvalToTrue(s.ui.item_atlas.selected_item_id == "item_3", "integer 3 should select item_3")
end

-- T16 mutation-pinning addendum.
--
-- _ensure_state defaults observed via unknown-action path (which calls
-- _ensure_state then returns the atlas without further mutation). open() is
-- intentionally NOT called first so the defaults remain visible.
--
function TestItemAtlas:test_initial_open_flag_is_false_until_item_atlas_open_flips_it_l18()
  local s = _make_state()
  local atlas = item_atlas.handle_action(s, "no_such_action", 1)
  lu.assertEvalToTrue(atlas.open == false,
    "default atlas.open must be false; L18 mutation flips _ensure_state default to true. " ..
    "Got: " .. tostring(atlas.open))
end

function TestItemAtlas:test_initial_page_index_is_1_so_item_at_points_at_catalog_1_l19()
  item_atlas.configure_catalog_for_tests(_make_catalog(8))
  local s = _make_state()
  -- handle_action with unknown action triggers _ensure_state without overwriting
  -- page_index. Then a select with slot_index=1 should resolve to catalog[1] (page 1).
  item_atlas.handle_action(s, "no_such_action", 1)
  local atlas = s.ui.item_atlas
  lu.assertEvalToTrue(atlas.page_index == 1,
    "default page_index must be 1; L19 mutation makes it 0. Got: " .. tostring(atlas.page_index))
  -- Cross-check via _item_at: page_index=1 + slot 1 ⇒ item_1; mutated page_index=0 ⇒
  -- catalog[(0-1)*8+1] = catalog[-7] = nil ⇒ no selection.
  item_atlas.handle_action(s, { type = "select", slot_index = 1 }, 1)
  lu.assertEvalToTrue(s.ui.item_atlas.selected_item_id == "item_1",
    "page_index default must allow selecting item_1; L19 makes catalog index negative. " ..
    "Got: " .. tostring(s.ui.item_atlas.selected_item_id))
end

function TestItemAtlas:test_select_with_nil_slot_index_resolves_to_catalog_slot_1_l31()
  item_atlas.configure_catalog_for_tests(_make_catalog(8))
  local s = _make_state()
  item_atlas.open(s, 1)
  -- slot_index=nil → _item_at(atlas, nil) → to_integer(nil) is nil → fallback to 1.
  -- Original: catalog[(1-1)*8 + 1] = catalog[1] = item_1 → selection set.
  -- Mutated `or 0`: catalog[(1-1)*8 + 0] = catalog[0] = nil → no selection.
  item_atlas.handle_action(s, { type = "select", slot_index = nil }, 1)
  lu.assertEvalToTrue(s.ui.item_atlas.selected_item_id == "item_1",
    "_item_at fallback must pick slot 1 when slot_index is nil; L31 mutation `or 1 → or 0` " ..
    "makes catalog[0] = nil and leaves selection unset. Got: " ..
    tostring(s.ui.item_atlas.selected_item_id))
end


return TestItemAtlas

--[[ mutate4lua-manifest
version=4
projectHash=d48052b44839c179
scope.0.id=chunk:test/behavior/ui/test_item_atlas.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=791
scope.0.semanticHash=c166be114042b219
scope.1.id=function:_make_state
scope.1.kind=function
scope.1.startLine=11
scope.1.endLine=13
scope.1.semanticHash=c4aad272ad990756
scope.2.id=function:_make_catalog
scope.2.kind=function
scope.2.startLine=15
scope.2.endLine=21
scope.2.semanticHash=50f17e81d1a8c6b4
scope.3.id=function:_make_render_state
scope.3.kind=function
scope.3.startLine=23
scope.3.endLine=47
scope.3.semanticHash=06df6873c8517419
scope.4.id=function:<anonymous>
scope.4.kind=function
scope.4.startLine=27
scope.4.endLine=29
scope.4.semanticHash=1bb064d29a0d4a10
scope.5.id=function:<anonymous>#2
scope.5.kind=function
scope.5.startLine=32
scope.5.endLine=34
scope.5.semanticHash=1bb064d29a0d4a10
scope.6.id=function:<anonymous>#3
scope.6.kind=function
scope.6.startLine=35
scope.6.endLine=37
scope.6.semanticHash=1bb064d29a0d4a10
scope.7.id=function:<anonymous>#4
scope.7.kind=function
scope.7.startLine=38
scope.7.endLine=40
scope.7.semanticHash=1bb064d29a0d4a10
scope.8.id=function:<anonymous>#5
scope.8.kind=function
scope.8.startLine=41
scope.8.endLine=43
scope.8.semanticHash=1bb064d29a0d4a10
scope.9.id=function:_find_call
scope.9.kind=function
scope.9.startLine=49
scope.9.endLine=57
scope.9.semanticHash=8e4c76588670052a
scope.10.id=function:_stub_runtime
scope.10.kind=function
scope.10.startLine=59
scope.10.endLine=68
scope.10.semanticHash=4b0dc89fba8661c3
scope.11.id=function:<anonymous>#6
scope.11.kind=function
scope.11.startLine=62
scope.11.endLine=62
scope.11.semanticHash=b05ccae5079f855d
scope.12.id=function:<anonymous>#7
scope.12.kind=function
scope.12.startLine=63
scope.12.endLine=65
scope.12.semanticHash=70075ffe366bc378
scope.13.id=function:TestItemAtlas:setUp
scope.13.kind=function
scope.13.startLine=72
scope.13.endLine=75
scope.13.semanticHash=4bad248a1fa2de6f
scope.14.id=function:TestItemAtlas:tearDown
scope.14.kind=function
scope.14.startLine=77
scope.14.endLine=81
scope.14.semanticHash=4bad248a1fa2de6f
scope.15.id=function:TestItemAtlas:test_marks_atlas_open_after_open
scope.15.kind=function
scope.15.startLine=83
scope.15.endLine=87
scope.15.semanticHash=53b0ac94f7760ee8
scope.16.id=function:TestItemAtlas:test_opens_the_atlas_canvas_for_the_active_role
scope.16.kind=function
scope.16.startLine=89
scope.16.endLine=106
scope.16.semanticHash=b8854989efa6bec7
scope.17.id=function:<anonymous>#8
scope.17.kind=function
scope.17.startLine=95
scope.17.endLine=100
scope.17.semanticHash=6fd3f37c2206a2f3
scope.18.id=function:<anonymous>#9
scope.18.kind=function
scope.18.startLine=101
scope.18.endLine=103
scope.18.semanticHash=74d2573cbd69ef93
scope.19.id=function:TestItemAtlas:test_open_normalizes_a_nil_page_index_to_page_1
scope.19.kind=function
scope.19.startLine=108
scope.19.endLine=113
scope.19.semanticHash=975879179e86aab0
scope.20.id=function:TestItemAtlas:test_open_refreshes_page_even_when_the_owner_role_cannot_be_resolved
scope.20.kind=function
scope.20.startLine=115
scope.20.endLine=132
scope.20.semanticHash=1c69b442bb539946
scope.21.id=function:<anonymous>#10
scope.21.kind=function
scope.21.startLine=120
scope.21.endLine=122
scope.21.semanticHash=d654da5e94a5e3f3
scope.22.id=function:<anonymous>#11
scope.22.kind=function
scope.22.startLine=123
scope.22.endLine=125
scope.22.semanticHash=6560bf8dfd1c4b2f
scope.23.id=function:<anonymous>#12
scope.23.kind=function
scope.23.startLine=126
scope.23.endLine=126
scope.23.semanticHash=f5774b2783966d88
scope.24.id=function:<anonymous>#13
scope.24.kind=function
scope.24.startLine=127
scope.24.endLine=129
scope.24.semanticHash=74d2573cbd69ef93
scope.25.id=function:TestItemAtlas:test_owner_refresh_uses_the_state_presentation_runtime
scope.25.kind=function
scope.25.startLine=134
scope.25.endLine=166
scope.25.semanticHash=a2d17da5bb9802e9
scope.26.id=function:<anonymous>#14
scope.26.kind=function
scope.26.startLine=141
scope.26.endLine=146
scope.26.semanticHash=1448d0e75e53de9c
scope.27.id=function:<anonymous>#15
scope.27.kind=function
scope.27.startLine=151
scope.27.endLine=156
scope.27.semanticHash=6fd3f37c2206a2f3
scope.28.id=function:<anonymous>#16
scope.28.kind=function
scope.28.startLine=157
scope.28.endLine=159
scope.28.semanticHash=3064314353f921d7
scope.29.id=function:<anonymous>#17
scope.29.kind=function
scope.29.startLine=160
scope.29.endLine=160
scope.29.semanticHash=f5774b2783966d88
scope.30.id=function:<anonymous>#18
scope.30.kind=function
scope.30.startLine=161
scope.30.endLine=163
scope.30.semanticHash=74d2573cbd69ef93
scope.31.id=function:TestItemAtlas:test_marks_atlas_closed_after_close
scope.31.kind=function
scope.31.startLine=168
scope.31.endLine=173
scope.31.semanticHash=a18ba2d156ab1451
scope.32.id=function:TestItemAtlas:test_closes_the_atlas_canvas_for_the_active_role
scope.32.kind=function
scope.32.startLine=175
scope.32.endLine=193
scope.32.semanticHash=c49d1827933c37c6
scope.33.id=function:<anonymous>#19
scope.33.kind=function
scope.33.startLine=181
scope.33.endLine=186
scope.33.semanticHash=6fd3f37c2206a2f3
scope.34.id=function:<anonymous>#20
scope.34.kind=function
scope.34.startLine=187
scope.34.endLine=190
scope.34.semanticHash=0dc6d39c77b0f6bc
scope.35.id=function:TestItemAtlas:test_configure_catalog_for_tests_replaces_active_catalog
scope.35.kind=function
scope.35.startLine=195
scope.35.endLine=199
scope.35.semanticHash=77c14d211b6044b6
scope.36.id=function:TestItemAtlas:test_reset_for_tests_restores_default_catalog_size
scope.36.kind=function
scope.36.startLine=201
scope.36.endLine=205
scope.36.semanticHash=d83450cf3d12c2ba
scope.37.id=function:TestItemAtlas:test_select_slot_records_selected_item_id
scope.37.kind=function
scope.37.startLine=207
scope.37.endLine=213
scope.37.semanticHash=a8bfa2e34f9b8c22
scope.38.id=function:TestItemAtlas:test_select_slot_5_records_item_5
scope.38.kind=function
scope.38.startLine=215
scope.38.endLine=221
scope.38.semanticHash=a8bfa2e34f9b8c22
scope.39.id=function:TestItemAtlas:test_selecting_empty_slot_does_not_set_selected_item_id
scope.39.kind=function
scope.39.startLine=223
scope.39.endLine=229
scope.39.semanticHash=5111a0cbdb115440
scope.40.id=function:TestItemAtlas:test_dismiss_action_clears_selected_item_id
scope.40.kind=function
scope.40.startLine=231
scope.40.endLine=239
scope.40.semanticHash=2c2e815a1a866d62
scope.41.id=function:TestItemAtlas:test_dismiss_action_never_dispatches_anim_done
scope.41.kind=function
scope.41.startLine=241
scope.41.endLine=257
scope.41.semanticHash=404db3d751335bd1
scope.42.id=function:<anonymous>#21
scope.42.kind=function
scope.42.startLine=250
scope.42.endLine=252
scope.42.semanticHash=2f9eeb74ee56d737
scope.43.id=function:TestItemAtlas:test_dismiss_action_tolerates_state_without_dispatch_action
scope.43.kind=function
scope.43.startLine=259
scope.43.endLine=269
scope.43.semanticHash=eb3c4d311bf9b01b
scope.44.id=function:TestItemAtlas:test_select_and_reselect_refresh_enlarged_card_visibility
scope.44.kind=function
scope.44.startLine=271
scope.44.endLine=293
scope.44.semanticHash=06b50a60396d7e86
scope.45.id=function:<anonymous>#22
scope.45.kind=function
scope.45.startLine=278
scope.45.endLine=280
scope.45.semanticHash=18f1b21865a85e39
scope.46.id=function:<anonymous>#23
scope.46.kind=function
scope.46.startLine=281
scope.46.endLine=283
scope.46.semanticHash=6560bf8dfd1c4b2f
scope.47.id=function:<anonymous>#24
scope.47.kind=function
scope.47.startLine=284
scope.47.endLine=290
scope.47.semanticHash=36d6be5f7d33dd4c
scope.48.id=function:TestItemAtlas:test_page_next_advances_page_when_multiple_pages_exist
scope.48.kind=function
scope.48.startLine=295
scope.48.endLine=301
scope.48.semanticHash=0b8051b4043cccd3
scope.49.id=function:TestItemAtlas:test_page_next_does_not_exceed_max_page
scope.49.kind=function
scope.49.startLine=303
scope.49.endLine=310
scope.49.semanticHash=dbab3526e79be7c2
scope.50.id=function:TestItemAtlas:test_page_prev_goes_to_previous_page
scope.50.kind=function
scope.50.startLine=312
scope.50.endLine=320
scope.50.semanticHash=9e39fe22de8f8951
scope.51.id=function:TestItemAtlas:test_page_prev_does_not_go_below_page_1
scope.51.kind=function
scope.51.startLine=322
scope.51.endLine=328
scope.51.semanticHash=0b8051b4043cccd3
scope.52.id=function:TestItemAtlas:test_page_next_clears_selected_item_id
scope.52.kind=function
scope.52.startLine=330
scope.52.endLine=338
scope.52.semanticHash=2c2e815a1a866d62
scope.53.id=function:TestItemAtlas:test_nil_role_atlas_actions_keep_the_existing_owner_role
scope.53.kind=function
scope.53.startLine=340
scope.53.endLine=353
scope.53.semanticHash=be421158d465b760
scope.54.id=function:TestItemAtlas:test_page_next_refreshes_card_textures_for_the_atlas_owner_role
scope.54.kind=function
scope.54.startLine=355
scope.54.endLine=411
scope.54.semanticHash=0ec4779196a74a90
scope.55.id=function:s.ui.set_visible
scope.55.kind=function
scope.55.startLine=362
scope.55.endLine=362
scope.55.semanticHash=f5774b2783966d88
scope.56.id=function:<anonymous>#25
scope.56.kind=function
scope.56.startLine=365
scope.56.endLine=367
scope.56.semanticHash=f27a380acaa19c35
scope.57.id=function:<anonymous>#26
scope.57.kind=function
scope.57.startLine=368
scope.57.endLine=368
scope.57.semanticHash=f5774b2783966d88
scope.58.id=function:<anonymous>#27
scope.58.kind=function
scope.58.startLine=371
scope.58.endLine=376
scope.58.semanticHash=e5984887eaa027c5
scope.59.id=function:_role_key
scope.59.kind=function
scope.59.startLine=380
scope.59.endLine=386
scope.59.semanticHash=4647cb4034a2647a
scope.60.id=function:<anonymous>#28
scope.60.kind=function
scope.60.startLine=391
scope.60.endLine=401
scope.60.semanticHash=682b5396264eb9ae
scope.61.id=function:<anonymous>#29
scope.61.kind=function
scope.61.startLine=394
scope.61.endLine=398
scope.61.semanticHash=84efee25bc1ec43a
scope.62.id=function:<anonymous>#30
scope.62.kind=function
scope.62.startLine=403
scope.62.endLine=406
scope.62.semanticHash=0dc6d39c77b0f6bc
scope.63.id=function:TestItemAtlas:test_page_prev_clears_selected_item_id
scope.63.kind=function
scope.63.startLine=413
scope.63.endLine=422
scope.63.semanticHash=66bfc596c20302db
scope.64.id=function:TestItemAtlas:test_unknown_string_action_returns_state_and_sets_role_id
scope.64.kind=function
scope.64.startLine=424
scope.64.endLine=430
scope.64.semanticHash=2ce0b37224a10a3b
scope.65.id=function:TestItemAtlas:test_unknown_table_action_returns_state_without_crashing
scope.65.kind=function
scope.65.startLine=432
scope.65.endLine=437
scope.65.semanticHash=7a70b3ab4a32f0bc
scope.66.id=function:TestItemAtlas:test_re_selecting_the_same_slot_clears_the_selection_toggle_off
scope.66.kind=function
scope.66.startLine=439
scope.66.endLine=447
scope.66.semanticHash=31d793417e7a6c91
scope.67.id=function:TestItemAtlas:test_selecting_a_different_slot_replaces_the_selection
scope.67.kind=function
scope.67.startLine=449
scope.67.endLine=457
scope.67.semanticHash=dad872a5f9652b13
scope.68.id=function:TestItemAtlas:test_selecting_an_empty_slot_does_not_clear_an_existing_selection
scope.68.kind=function
scope.68.startLine=459
scope.68.endLine=468
scope.68.semanticHash=dad872a5f9652b13
scope.69.id=function:TestItemAtlas:test_shows_present_items_and_hides_empty_slots
scope.69.kind=function
scope.69.startLine=470
scope.69.endLine=482
scope.69.semanticHash=fbb4d0a3cd3419c6
scope.70.id=function:TestItemAtlas:test_disables_touch_for_hidden_empty_card_slots
scope.70.kind=function
scope.70.startLine=484
scope.70.endLine=496
scope.70.semanticHash=fbb4d0a3cd3419c6
scope.71.id=function:TestItemAtlas:test_never_writes_the_static_title_label_on_refresh_page
scope.71.kind=function
scope.71.startLine=498
scope.71.endLine=506
scope.71.semanticHash=da93ad62bd8bcf60
scope.72.id=function:TestItemAtlas:test_single_page_catalog_hides_both_prev_and_next_arrows
scope.72.kind=function
scope.72.startLine=508
scope.72.endLine=516
scope.72.semanticHash=959dd7dd59b326cc
scope.73.id=function:TestItemAtlas:test_multi_page_first_page_shows_only_next_arrow
scope.73.kind=function
scope.73.startLine=518
scope.73.endLine=530
scope.73.semanticHash=e1534cebec5f0946
scope.74.id=function:TestItemAtlas:test_multi_page_middle_page_shows_both_arrows
scope.74.kind=function
scope.74.startLine=532
scope.74.endLine=540
scope.74.semanticHash=959dd7dd59b326cc
scope.75.id=function:TestItemAtlas:test_multi_page_last_page_shows_only_prev_arrow
scope.75.kind=function
scope.75.startLine=542
scope.75.endLine=554
scope.75.semanticHash=e1534cebec5f0946
scope.76.id=function:TestItemAtlas:test_single_page_catalog_with_out_of_range_page_index_still_hides_both_arrows
scope.76.kind=function
scope.76.startLine=556
scope.76.endLine=564
scope.76.semanticHash=959dd7dd59b326cc
scope.77.id=function:TestItemAtlas:test_refresh_page_queries_exactly_page_size_card_nodes_on_a_full_page
scope.77.kind=function
scope.77.startLine=566
scope.77.endLine=584
scope.77.semanticHash=37adfddfce214396
scope.78.id=function:<anonymous>#31
scope.78.kind=function
scope.78.startLine=575
scope.78.endLine=578
scope.78.semanticHash=0c9da6527ac52530
scope.79.id=function:<anonymous>#32
scope.79.kind=function
scope.79.startLine=579
scope.79.endLine=579
scope.79.semanticHash=4c8e710b8eb041e2
scope.80.id=function:TestItemAtlas:test_sets_texture_when_image_refs_are_provided
scope.80.kind=function
scope.80.startLine=586
scope.80.endLine=594
scope.80.semanticHash=955cbb9206a95034
scope.81.id=function:TestItemAtlas:test_sets_texture_from_resolver_asset_context
scope.81.kind=function
scope.81.startLine=596
scope.81.endLine=606
scope.81.semanticHash=955cbb9206a95034
scope.82.id=function:TestItemAtlas:test_sets_texture_on_all_matched_card_nodes_when_runtime_exposes_query_nodes
scope.82.kind=function
scope.82.startLine=608
scope.82.endLine=629
scope.82.semanticHash=610495136f356b3f
scope.83.id=function:<anonymous>#33
scope.83.kind=function
scope.83.startLine=614
scope.83.endLine=619
scope.83.semanticHash=51e762030bf4b2a1
scope.84.id=function:<anonymous>#34
scope.84.kind=function
scope.84.startLine=620
scope.84.endLine=622
scope.84.semanticHash=70075ffe366bc378
scope.85.id=function:TestItemAtlas:test_show_enlarged_shows_the_enlarged_card_trio_and_sets_texture
scope.85.kind=function
scope.85.startLine=631
scope.85.endLine=650
scope.85.semanticHash=2f4724155ad24e2f
scope.86.id=function:TestItemAtlas:test_hide_enlarged_hides_the_enlarged_card_trio
scope.86.kind=function
scope.86.startLine=652
scope.86.endLine=665
scope.86.semanticHash=720eb4e2d2e56556
scope.87.id=function:TestItemAtlas:test_show_enlarged_sets_texture_on_all_matched_nodes_when_runtime_exposes_query_nodes
scope.87.kind=function
scope.87.startLine=667
scope.87.endLine=687
scope.87.semanticHash=b20728d2090cf32a
scope.88.id=function:<anonymous>#35
scope.88.kind=function
scope.88.startLine=672
scope.88.endLine=677
scope.88.semanticHash=51e762030bf4b2a1
scope.89.id=function:<anonymous>#36
scope.89.kind=function
scope.89.startLine=678
scope.89.endLine=680
scope.89.semanticHash=70075ffe366bc378
scope.90.id=function:TestItemAtlas:test_show_enlarged_with_missing_image_ref_is_a_no_op
scope.90.kind=function
scope.90.startLine=689
scope.90.endLine=693
scope.90.semanticHash=a44c3f83d5c0190e
scope.91.id=function:TestItemAtlas:test_show_enlarged_falls_back_to_module_level_runtime_ui_when_deps_omitted
scope.91.kind=function
scope.91.startLine=695
scope.91.endLine=717
scope.91.semanticHash=b053005d5a952ddd
scope.92.id=function:UIManager.query_nodes_by_name
scope.92.kind=function
scope.92.startLine=700
scope.92.endLine=709
scope.92.semanticHash=3ab08a43ecc4696a
scope.93.id=function:<anonymous>#37
scope.93.kind=function
scope.93.startLine=705
scope.93.endLine=705
scope.93.semanticHash=4c8e710b8eb041e2
scope.94.id=function:<anonymous>#38
scope.94.kind=function
scope.94.startLine=706
scope.94.endLine=706
scope.94.semanticHash=4c8e710b8eb041e2
scope.95.id=function:TestItemAtlas:test_page_2_shows_correct_items_by_offset
scope.95.kind=function
scope.95.startLine=719
scope.95.endLine=734
scope.95.semanticHash=a33adb37a4ebd88c
scope.96.id=function:TestItemAtlas:test_integer_action_selects_slot_by_index
scope.96.kind=function
scope.96.startLine=736
scope.96.endLine=742
scope.96.semanticHash=cf135a0c5569fbd3
scope.97.id=function:TestItemAtlas:test_initial_open_flag_is_false_until_item_atlas_open_flips_it_l18
scope.97.kind=function
scope.97.startLine=750
scope.97.endLine=756
scope.97.semanticHash=206c811d47af4b48
scope.98.id=function:TestItemAtlas:test_initial_page_index_is_1_so_item_at_points_at_catalog_1_l19
scope.98.kind=function
scope.98.startLine=758
scope.98.endLine=773
scope.98.semanticHash=f6cf2113807037ee
scope.99.id=function:TestItemAtlas:test_select_with_nil_slot_index_resolves_to_catalog_slot_1_l31
scope.99.kind=function
scope.99.startLine=775
scope.99.endLine=787
scope.99.semanticHash=318fe5aa309bb152
]]
