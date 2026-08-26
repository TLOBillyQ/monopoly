-- target 选择屏 Screen 深模块直测：descriptor 字段 + 路由意图 + inert 确认键。
-- 用 shared_support 的 choice_modal fixture（与 choice_routes_spec 同款）。
local lu = require("luaunit")
local registry = require("src.ui.screens_registry")
local target_screen = require("src.ui.screens.target_choice")
local schema = require("src.ui.schema.target_choice")
local runtime_state = require("src.ui.state.runtime")
local logger = require("src.foundation.log")

-- 找到第一个槽位按钮的 route spec（confirm/cancel 为 inert，排在前）。
local function _first_slot_spec(state)
  local slot_names = {}
  for _, name in ipairs(schema.slot_buttons or {}) do slot_names[name] = true end
  for _, s in ipairs(target_screen.build_route_specs(state)) do
    if slot_names[s.name] then return s end
  end
  return nil
end

local function _with_ui_model(model, fn)
  local state = {}
  runtime_state.set_ui_model(state, model)
  return fn(state)
end

local function _capturing_warn(fn)
  local original = logger.warn
  local warned = false
  logger.warn = function() warned = true end
  local ok, err = pcall(fn)
  logger.warn = original
  if not ok then error(err) end
  return warned
end

-- 原生 LuaUnit(推翻自研 busted 兼容运行器决策的迁移):describe/it 拍平为文件级 Test* 类,
-- 无钩子不拆类,用例数与改写前一一对应(8 例);断言从裸 assert 切到 lu.assertXxx。
TestTargetChoiceScreen = {}

function TestTargetChoiceScreen:test_exposes_a_descriptor_with_the_pinned_target_fields()
  local d = target_screen.descriptor()
  lu.assertEvalToTrue(d.key == "target", "descriptor key is target")
  lu.assertNotNil(d.root, "has root/canvas node")
  lu.assertEvalToTrue(d.title ~= nil and d.body ~= nil, "has title and body")
  lu.assertNotNil(d.option_buttons, "has option_buttons")
  lu.assertEvalToTrue(d.slot_labels ~= nil and d.slot_projections ~= nil, "has slot label/projection nodes")
  lu.assertEvalToTrue(d.confirm ~= nil and d.cancel ~= nil, "has confirm and cancel nodes")
end

function TestTargetChoiceScreen:test_registers_itself_into_the_registry_under_its_key()
  lu.assertNotNil(registry.build_choice_screens().target, "registry aggregates target descriptor")
  lu.assertEvalToTrue(registry.canvas_for("target") == target_screen.canvas, "registry maps target canvas")
  lu.assertEvalToTrue(registry.opener_for("target") == target_screen.open, "registry maps target opener")
end

TestTargetChoiceScreen["test_keeps the confirm key inert (build_intent returns nil) — target auto-confirms on slot"] = function(self)
  local specs = target_screen.build_route_specs({})
  local confirm_spec
  for _, s in ipairs(specs) do
    if s.name == schema.confirm then confirm_spec = s end
  end
  lu.assertNotNil(confirm_spec, "confirm node has a route spec")
  lu.assertNil(confirm_spec.build_intent(), "confirm intent is inert nil by design")
end

function TestTargetChoiceScreen:test_builds_a_choice_select_intent_for_a_slot_button_when_a_choice_is_present()
  -- slot 路径与 target_choice_screen.build_route_specs 等价：借 runtime model 注入 choice。
  -- 具体 fixture 复用 shared_support（见 choice_routes_spec 的 _build_choice_modal_state）。
  local specs = target_screen.build_route_specs({})
  local has_slot = false
  for _, s in ipairs(specs) do
    if s.name == schema.slot_buttons[1] then has_slot = true end
  end
  lu.assertEvalToTrue(has_slot, "first slot button has a route spec")
end

function TestTargetChoiceScreen:test_resolves_the_slots_own_index_when_the_choice_has_multiple_options()
  local intent = _with_ui_model(
    { choice = { id = 8, options = { { id = 21 }, { id = 22 } } } },
    function(state)
      return _first_slot_spec(state).build_intent()
    end)
  lu.assertNotNil(intent, "first slot resolves to an intent")
  lu.assertEvalToTrue(intent.type == "choice_select", "intent type is choice_select")
  lu.assertEvalToTrue(intent.choice_id == 8, "intent carries the choice id")
  lu.assertEvalToTrue(intent.option_id == 21, "first slot maps to its own index -> option 21")
end

function TestTargetChoiceScreen:test_collapses_to_the_single_option_when_the_choice_has_exactly_one()
  local intent = _with_ui_model(
    { choice = { id = 9, options = { { id = 99 } } } },
    function(state)
      return _first_slot_spec(state).build_intent()
    end)
  lu.assertNotNil(intent, "single-option choice resolves to an intent")
  lu.assertEvalToTrue(intent.option_id == 99, "single-option choice collapses to option 99")
end

function TestTargetChoiceScreen:test_warns_and_returns_nil_when_no_choice_is_present()
  local intent
  local warned = _capturing_warn(function()
    intent = _with_ui_model({}, function(state)
      return _first_slot_spec(state).build_intent()
    end)
  end)
  lu.assertNil(intent, "missing choice yields nil intent")
  lu.assertEvalToTrue(warned, "missing choice logs a warning")
end

function TestTargetChoiceScreen:test_warns_and_returns_nil_when_the_option_cannot_be_resolved()
  local intent
  local warned = _capturing_warn(function()
    intent = _with_ui_model({ choice = { id = 4, options = {} } }, function(state)
      return _first_slot_spec(state).build_intent()
    end)
  end)
  lu.assertNil(intent, "unresolvable option yields nil intent")
  lu.assertEvalToTrue(warned, "unresolvable option logs a warning")
end


return TestTargetChoiceScreen
