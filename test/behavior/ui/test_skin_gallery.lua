-- Behavior specs for src/ui/screens/skin_panel/skin_gallery.lua.
-- 画廊适配器只持有关屏路由，展示与所有权事实留在 canonical 面板。

local P = require("test.support.shared_support")
local _assert_eq = P.assert_eq
local _with_patches = P.with_patches
local luax = require("test.support.luax")
local skin_gallery = require("src.ui.screens.skin_panel.skin_gallery")
local skin_panel = require("src.ui.screens.skin_panel")

TestSkinGallery = {}

function TestSkinGallery:test_asserts_descriptive_errors_for_missing_state()
  -- 杀 L7 两层消息钉:state 缺失与 state.ui 缺失必须各报各的消息。
  luax.has_error(function()
    skin_gallery.handle_action(nil, "close")
  end, "missing state")
  luax.has_error(function()
    skin_gallery.handle_action({}, "close")
  end, "missing state.ui")
end

function TestSkinGallery:test_unlock_keeps_facts_in_skin_panel_and_only_routes_close()
  local canonical = { open = true, owned_by_role = { ["1"] = { [101] = true } } }
  local state = { ui = {} }
  _with_patches({
    { target = skin_panel, key = "unlock", value = function() return canonical end },
  }, function()
    local result = skin_gallery.handle_action(state, "buy", 1)
    _assert_eq(result, canonical, "unlock should return the canonical skin panel state")
    _assert_eq(state.ui.skin_gallery.mode, "skin", "unlock should route close to the skin panel")
    _assert_eq(state.ui.skin_gallery.owned_by_role, nil, "gallery route must not mirror skin ownership")
  end)
end

function TestSkinGallery:test_equip_keeps_selection_in_skin_panel_and_only_routes_close()
  local canonical = { open = false, selected_by_role = { ["1"] = 101 } }
  local state = { ui = {} }
  _with_patches({
    { target = skin_panel, key = "equip", value = function() return canonical end },
  }, function()
    local result = skin_gallery.handle_action(state, "equip", 1)
    _assert_eq(result, canonical, "equip should return the canonical skin panel state")
    _assert_eq(state.ui.skin_gallery.mode, nil, "equip should clear the route after the panel auto-closes")
    _assert_eq(state.ui.skin_gallery.selected_by_role, nil, "gallery route must not mirror skin selection")
  end)
end

function TestSkinGallery:test_existing_route_drops_legacy_mirrored_fields()
  local state = {
    ui = {
      item_atlas = { open = true },
      skin_gallery = {
        mode = "gallery",
        open = true,
        page_index = 2,
        role_id = 1,
        owned_by_role = { ["1"] = {} },
        selected_by_role = { ["1"] = 101 },
      },
    },
  }

  local route = skin_gallery.handle_action(state, "bogus", 1)

  _assert_eq(route.mode, "gallery", "legacy cleanup should preserve the active close route")
  _assert_eq(route.open, nil, "legacy cleanup should drop mirrored visibility")
  _assert_eq(route.page_index, nil, "legacy cleanup should drop mirrored pagination")
  _assert_eq(route.role_id, nil, "legacy cleanup should drop mirrored role")
  _assert_eq(route.owned_by_role, nil, "legacy cleanup should drop mirrored ownership")
  _assert_eq(route.selected_by_role, nil, "legacy cleanup should drop mirrored selection")
end

function TestSkinGallery:test_existing_route_drops_stale_skin_mode_after_equip_closed_panel()
  local state = {
    ui = {
      skin_panel = { open = false },
      skin_gallery = { mode = "skin", open = false },
    },
  }

  local route = skin_gallery.handle_action(state, "bogus", 1)

  _assert_eq(route.mode, nil, "legacy cleanup should drop a route to an already closed skin panel")
end

return TestSkinGallery
