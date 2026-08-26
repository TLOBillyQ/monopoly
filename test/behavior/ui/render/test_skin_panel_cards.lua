-- Behavior specs for src/ui/render/widgets/skin_panel_cards.lua.
-- 皮肤卡牌槽位的装饰节点:卡牌底框控制态、描边容器与金额图标的触控一律保持
-- 禁用(touch_enabled=false)——false->true 变异在这里必须露馅。

local P = require("test.support.shared_support")
local _assert_eq = P.assert_eq
local _with_patches = P.with_patches
local skin_panel_cards = require("src.ui.render.widgets.skin_panel_cards")
local skin_nodes = require("src.ui.schema.skin")
local ui_controls = require("src.ui.render.support.ui_controls")

local function _ui_spy()
  local calls = {}
  return {
    calls = calls,
    ui = {
      set_visible = function(_, name, value)
        calls[#calls + 1] = { "visible", name, value }
      end,
      set_touch_enabled = function(_, name, value)
        calls[#calls + 1] = { "touch", name, value }
      end,
    },
  }
end

local function _refresh(slot, view)
  local spy = _ui_spy()
  skin_panel_cards.refresh_slot_visuals({}, spy.ui, {}, slot, view)
  return spy.calls
end

TestSkinPanelCards = {}

function TestSkinPanelCards:test_card_frame_control_state_keeps_touch_disabled()
  -- 杀 L12 false->true:卡牌底框的 set_control_state 必须带 touch_enabled=false。
  local seen = nil
  _with_patches({
    {
      target = ui_controls,
      key = "set_control_state",
      value = function(_, name, opts)
        seen = { name, opts }
      end,
    },
  }, function()
    _refresh(1, { has_skin = true, skin = { product_id = "p1" }, price_icon_visible = false })
  end)
  _assert_eq(seen ~= nil, true, "card frame control state should be applied")
  _assert_eq(seen[2].touch_enabled, false, "card frame touch must stay disabled")
end

function TestSkinPanelCards:test_card_outline_container_touch_stays_disabled()
  -- 杀 L24 false->true:描边容器的 set_touch_enabled 必须收到 false。
  local calls = _refresh(1, { has_skin = true, skin = { product_id = "p1" }, price_icon_visible = false })
  local found = false
  for _, call in ipairs(calls) do
    if call[1] == "touch" and string.match(call[2], "描边") then
      found = true
      _assert_eq(call[3], false, "outline container touch must stay disabled")
    end
  end
  _assert_eq(found, true, "outline container touch call should be observed")
end

function TestSkinPanelCards:test_price_icon_touch_stays_disabled()
  -- 杀 L87 false->true:金额图标的 set_touch_enabled 必须收到 false。
  local calls = _refresh(1, { has_skin = true, skin = { product_id = "p1" }, price_icon_visible = false })
  local found = false
  for _, call in ipairs(calls) do
    if call[1] == "touch" and string.match(call[2], "金额图标") then
      found = true
      _assert_eq(call[3], false, "price icon touch must stay disabled")
    end
  end
  _assert_eq(found, true, "price icon touch call should be observed")
end

TestSkinSchemaContract = {}

function TestSkinSchemaContract:test_core_skin_node_names_are_pinned()
  -- 硬编码契约钉:节点名字符串是宿主 UI 契约,值->nil 变异必须露馅。
  _assert_eq(skin_nodes.close_button, "皮肤商店-关闭", "close_button node name is pinned")
  _assert_eq(skin_nodes.activity_background, "皮肤商店-活动背景", "activity_background node name is pinned")
  _assert_eq(skin_nodes.title_label, "皮肤_皮肤商店文本", "title_label node name is pinned")
  _assert_eq(skin_nodes.panel_frames[1], "皮肤_皮肤商店底框", "panel frame 1 is pinned")
  _assert_eq(skin_nodes.panel_frames[2], "皮肤_皮肤商店底框2", "panel frame 2 is pinned")
end

function TestSkinSchemaContract:test_static_visual_nodes_reference_existing_frames()
  -- 杀 L21 的 panel_frames[1] -> panel_frames[0]:静态可见节点表不得出现 nil 条目。
  _assert_eq(skin_nodes.static_visual_nodes[3], skin_nodes.panel_frames[1],
    "static visual node 3 should be the first panel frame")
  _assert_eq(skin_nodes.static_visual_nodes[4], skin_nodes.panel_frames[2],
    "static visual node 4 should be the second panel frame")
end

function TestSkinSchemaContract:test_card_slot_tables_start_at_index_one()
  -- 杀 L25 循环 1->0:卡牌槽位表不得多出 [0] 条目。
  _assert_eq(skin_nodes.card_images[0], nil, "card images must start at index 1")
  _assert_eq(skin_nodes.card_frames[0], nil, "card frames must start at index 1")
  _assert_eq(skin_nodes.card_outlines[0], nil, "card outlines must start at index 1")
  _assert_eq(skin_nodes.price_icons[0], nil, "price icons must start at index 1")
  _assert_eq(skin_nodes.action_buttons[0], nil, "action buttons must start at index 1")
end

-- mutate 车道统一返回全部类(#283):内建 runner 只跑 return 的表,单类 return
-- 会让其余类的用例在变异车道完全不执行。
return require("test.support.multi_class_return").merge(
  TestSkinPanelCards,
  TestSkinSchemaContract
)
