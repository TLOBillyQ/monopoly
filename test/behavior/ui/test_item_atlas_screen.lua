-- screens/item_atlas 面板面规约(#262 幸存闭合):开/关屏 notify 载荷
-- (source/text/key)与模块装载时 catalog 初值非 nil。
local support = require("test.support.shared_support")
local _assert_eq = support.assert_eq
local _with_patches = support.with_patches
local item_atlas = require("src.ui.screens.item_atlas")
local panel_tip = require("src.ui.coord.panel_tip")
local panel_helpers = require("src.ui.render.support.panel_helpers")
local canvas = require("src.ui.coord.canvas_coordinator")
local item_atlas_view = require("src.ui.render.widgets.item_atlas")

local function _panel_patches(tips, switches)
  return {
    { target = panel_tip, key = "enqueue", value = function(source, text, key)
      tips[#tips + 1] = { source = source, text = text, key = key }
    end },
    { target = panel_helpers, key = "with_owner_role", value = function(_, _, fn)
      return fn()
    end },
    { target = canvas, key = "switch_by_role_id", value = function(_, target, role_id)
      switches[#switches + 1] = { target = target, role_id = role_id }
    end },
    { target = item_atlas_view, key = "refresh_page", value = function() end },
    { target = item_atlas_view, key = "hide_enlarged", value = function() end },
  }
end

TestItemAtlasScreen = {}

function TestItemAtlasScreen:test_reset_for_tests_binds_the_default_catalog()
  -- 装载时预绑已删(#262,等价变异);catalog 字段由注入路径维护。
  item_atlas.reset_for_tests()
  local atlas_state = require("src.ui.screens.item_atlas.item_atlas_state")
  _assert_eq(item_atlas.catalog, atlas_state.catalog(), "reset should rebind the default catalog")
  _assert_eq(item_atlas.catalog ~= nil, true, "catalog after reset must not be nil")
end

function TestItemAtlasScreen:test_open_notifies_with_the_exact_tip_payload()
  -- kills "ui.item_atlas" -> nil 与 "图鉴已打开" -> nil。
  local tips = {}
  local switches = {}
  _with_patches(_panel_patches(tips, switches), function()
    item_atlas.open({ ui = {} }, 3)
  end)
  _assert_eq(#tips, 1, "open should notify exactly once")
  _assert_eq(tips[1].source, "ui.item_atlas", "open tip should carry the panel source")
  _assert_eq(tips[1].text, "图鉴已打开", "open tip should carry the opened text")
  _assert_eq(tips[1].key, "item_atlas:open:3", "open tip should carry the role-scoped key")
end

function TestItemAtlasScreen:test_close_notifies_with_the_exact_tip_payload()
  -- kills "已关闭" -> nil 与 "item_atlas:close" -> nil。
  local tips = {}
  local switches = {}
  _with_patches(_panel_patches(tips, switches), function()
    item_atlas.close({ ui = {} }, 3)
  end)
  _assert_eq(#tips, 1, "close should notify exactly once")
  _assert_eq(tips[1].source, "ui.item_atlas", "close tip should carry the panel source")
  _assert_eq(tips[1].text, "已关闭", "close tip should carry the closed text")
  _assert_eq(tips[1].key, "item_atlas:close", "close tip should carry the close key")
end


return TestItemAtlasScreen
