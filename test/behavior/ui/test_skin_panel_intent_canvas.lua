local lu = require("luaunit")
local support = require("test.support.shared_support")
local _with_patches = support.with_patches
local _build_role_with_events = support.build_role_with_events
local _has_event = support.has_event
local view_command = require("src.ui.input.view_command")
local presentation_ports = require("src.ui.ports")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local ui_events = require("src.ui.coord.ui_events")
local skin_panel = require("src.ui.screens.skin_panel")
local skin_intents = require("src.ui.screens.skin_panel")
local skin_nodes = require("src.ui.schema.skin")

local function _no_op() end

local function _build_ui_state()
  return {
    set_visible = _no_op,
    set_label = _no_op,
    set_button = _no_op,
    set_touch_enabled = _no_op,
    market_active = false,
    choice_active = false,
    popup_active = false,
    move_active = false,
    query_node = function() return {} end,
  }
end

-- 原生 LuaUnit(推翻自研 busted 兼容运行器决策的迁移):两个顶层 describe 各带钩子,按钩子边界
-- 拍平成两个 Test* 类(open 路径 only before_each;routing 路径 before+after),
-- 用例数与改写前一一对应(2 + 3 = 5 例);断言从裸 assert 切到 lu.assertXxx。
TestSkinPanelIntentCanvasOpenViaViewCommandDispatch = {}

function TestSkinPanelIntentCanvasOpenViaViewCommandDispatch:setUp()
  skin_panel.reset_for_tests()
end

function TestSkinPanelIntentCanvasOpenViaViewCommandDispatch:test_open_skin_panel_intent_switches_canvas_for_resolved_role()
  local clicker_events = {}
  local other_events = {}
  local clicker = _build_role_with_events(1, clicker_events)
  local other = _build_role_with_events(2, other_events)
  local state = {
    ui = _build_ui_state(),
    runtime_asset_context = { refs = { images = {} } },
    gameplay_loop_ports = presentation_ports.build(),
  }

  _with_patches({
    { target = runtime_ports, key = "resolve_role", value = function(role_id)
      if tostring(role_id) == "1" then return clicker end
      if tostring(role_id) == "2" then return other end
      return nil
    end },
    { target = ui_events, key = "roles", value = { clicker, other } },
  }, function()
    view_command.dispatch(state, { type = "open_skin_panel", actor_role_id = 1 })
  end)

  lu.assertEvalToTrue(state.ui.skin_panel and state.ui.skin_panel.open == true,
    "model state must mark skin panel open")
  lu.assertEvalToTrue(_has_event(clicker_events, "显示皮肤商店"),
    "clicker role must receive 显示皮肤商店 — model open without canvas show is the v102 bug")
  lu.assertEvalToTrue(not _has_event(other_events, "显示皮肤商店"),
    "non-clicker role must not have their canvas yanked to skin shop")
end

function TestSkinPanelIntentCanvasOpenViaViewCommandDispatch:test_open_skin_panel_intent_broadcasts_when_actor_role_id_missing()
  local role1_events = {}
  local role2_events = {}
  local role1 = _build_role_with_events(1, role1_events)
  local role2 = _build_role_with_events(2, role2_events)
  local state = {
    ui = _build_ui_state(),
    runtime_asset_context = { refs = { images = {} } },
    gameplay_loop_ports = presentation_ports.build(),
  }

  _with_patches({
    { target = runtime_ports, key = "resolve_role", value = function() return nil end },
    { target = ui_events, key = "roles", value = { role1, role2 } },
  }, function()
    view_command.dispatch(state, { type = "open_skin_panel" })
  end)

  lu.assertEvalToTrue(state.ui.skin_panel and state.ui.skin_panel.open == true,
    "model state must mark skin panel open even without actor_role_id")
  lu.assertEvalToTrue(_has_event(role1_events, "显示皮肤商店"),
    "broadcast path must reach role1 when actor_role_id is missing")
  lu.assertEvalToTrue(_has_event(role2_events, "显示皮肤商店"),
    "broadcast path must reach role2 when actor_role_id is missing")
end

TestSkinPanelIntentCanvasActionButtonRouting = {}

local function _spec_named(specs, name)
  for _, spec in ipairs(specs) do
    if spec.name == name then
      return spec
    end
  end
  return nil
end

local function _state_with(selected)
  return {
    ui = {
      skin_panel = {
        role_id = 1,
        page_index = 1,
        owned_by_role = { ["1"] = { ["s1"] = true, ["s2"] = true } },
        selected_by_role = { ["1"] = selected },
      },
    },
  }
end

function TestSkinPanelIntentCanvasActionButtonRouting:setUp()
  skin_panel.reset_for_tests()
  skin_panel.configure_catalog_for_tests({
    { product_id = "s1", name = "皮肤一" },
    { product_id = "s2", name = "皮肤二" },
  })
end

function TestSkinPanelIntentCanvasActionButtonRouting:tearDown()
  skin_panel.reset_for_tests()
end

function TestSkinPanelIntentCanvasActionButtonRouting:test_action_button_routes_activate_slot_for_equipped_slot()
  -- The input route should report the clicked slot. The transaction flow owns
  -- whether that activation equips or unequips.
  local state = _state_with("s1")
  local spec = _spec_named(skin_intents.build_route_specs(state), skin_nodes.action_buttons[1])
  lu.assertNotNil(spec, "slot 1 action button must have a canvas route")
  local intent = spec.build_intent()
  lu.assertEvalToTrue(intent.type == "skin_panel_action", "route must dispatch a skin_panel_action intent")
  lu.assertEvalToTrue(intent.action.type == "activate_slot",
    "action button route should leave equip/unequip selection to the transaction flow")
  lu.assertEvalToTrue(intent.action.slot_index == 1, "activate_slot intent must carry the clicked slot index")
end

function TestSkinPanelIntentCanvasActionButtonRouting:test_action_button_routes_activate_slot_for_unequipped_slot()
  local state = _state_with("s1")
  local spec = _spec_named(skin_intents.build_route_specs(state), skin_nodes.action_buttons[2])
  lu.assertNotNil(spec, "slot 2 action button must have a canvas route")
  local intent = spec.build_intent()
  lu.assertEvalToTrue(intent.action.type == "activate_slot", "non-equipped slot's button should emit activate_slot")
  lu.assertEvalToTrue(intent.action.slot_index == 2, "activate_slot intent must carry the clicked slot index")
end

function TestSkinPanelIntentCanvasActionButtonRouting:test_action_intent_does_not_read_live_equipped_state()
  local state = _state_with(nil)
  local specs = skin_intents.build_route_specs(state)
  local spec = _spec_named(specs, skin_nodes.action_buttons[1])
  lu.assertNotNil(spec, "slot 1 action button must have a canvas route")
  lu.assertEvalToTrue(spec.build_intent().action.type == "activate_slot",
    "nothing equipped should still route through activate_slot")
  state.ui.skin_panel.selected_by_role["1"] = "s1"
  lu.assertEvalToTrue(spec.build_intent().action.type == "activate_slot",
    "equipped state changes should not alter the input-layer action")
end


-- mutate 车道统一返回全部类（#283 多类文件 return 首类假幸存方向）：
-- 正常车道扫 _G 收全部 Test* 类，但 mutate 内建 runner 只跑 return 的表，
-- 只 return 首个类会让其余类的用例在变异车道完全不执行。合并全部类，
-- 每个 test* 方法跑所属类 setUp/tearDown（见 multi_class_return）。
return require("test.support.multi_class_return").merge(
  TestSkinPanelIntentCanvasOpenViaViewCommandDispatch,
  TestSkinPanelIntentCanvasActionButtonRouting
)
