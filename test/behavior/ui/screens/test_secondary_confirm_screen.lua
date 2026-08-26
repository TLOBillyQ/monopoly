-- secondary_confirm 选择屏 Screen 深模块直测：descriptor 字段 + 路由意图 + registry 注册。
local lu = require("luaunit")
local registry = require("src.ui.screens_registry")
local secondary_screen = require("src.ui.screens.secondary_confirm")
local schema = require("src.ui.schema.secondary_confirm")
local modal_state = require("src.ui.state.modal")
local runtime_state = require("src.ui.state.runtime")

-- 原生 LuaUnit(推翻自研 busted 兼容运行器决策的迁移):describe/it 拍平为文件级 Test* 类,
-- 无钩子不拆类,用例数与改写前一一对应(4 例);断言从裸 assert 切到 lu.assertXxx。
TestSecondaryConfirmScreen = {}

function TestSecondaryConfirmScreen:test_exposes_a_descriptor_with_the_pinned_secondary_confirm_fields()
  local d = secondary_screen.descriptor()
  lu.assertEvalToTrue(d.key == "secondary_confirm", "descriptor key is secondary_confirm")
  lu.assertNotNil(d.root, "has root/canvas node")
  lu.assertNotNil(d.title, "has title")
  lu.assertNotNil(d.body, "has body")
  lu.assertNotNil(d.confirm, "has confirm node")
  lu.assertNotNil(d.cancel, "has cancel node")
end

function TestSecondaryConfirmScreen:test_registers_itself_into_the_registry_under_its_key()
  lu.assertNotNil(registry.build_choice_screens().secondary_confirm, "registry aggregates secondary_confirm descriptor")
  lu.assertEvalToTrue(registry.canvas_for("secondary_confirm") == secondary_screen.canvas, "registry maps secondary_confirm canvas")
  lu.assertEvalToTrue(registry.opener_for("secondary_confirm") == secondary_screen.open, "registry maps secondary_confirm opener")
end

function TestSecondaryConfirmScreen:test_builds_a_confirm_route_spec_that_uses_choice_confirm_intent()
  local specs = secondary_screen.build_route_specs({})
  local confirm_spec
  for _, s in ipairs(specs) do
    if s.name == schema.confirm then confirm_spec = s end
  end
  lu.assertNotNil(confirm_spec, "confirm node has a route spec")
  lu.assertNotNil(confirm_spec.build_intent, "confirm spec has build_intent")
end

function TestSecondaryConfirmScreen:test_builds_a_cancel_route_spec_that_uses_choice_cancel_intent()
  local specs = secondary_screen.build_route_specs({})
  local cancel_spec
  for _, s in ipairs(specs) do
    if s.name == schema.cancel then cancel_spec = s end
  end
  lu.assertNotNil(cancel_spec, "cancel node has a route spec")
  lu.assertNotNil(cancel_spec.build_intent, "cancel spec has build_intent")
end

-- build_intent 必须真的被调用:只断言「闭包存在」杀不掉 ui_event_intents
-- require → nil 的变异(闭包惰性引用,永不求值)。
function TestSecondaryConfirmScreen:test_confirm_build_intent_returns_a_choice_select_intent()
  local state = {}
  runtime_state.set_ui_model(state, { choice = { id = "c9" } })
  modal_state.open_choice(state, "c9", { "opt1" }, "opt1")
  local specs = secondary_screen.build_route_specs(state)
  local confirm_spec
  for _, s in ipairs(specs) do
    if s.name == schema.confirm then confirm_spec = s end
  end
  local intent = confirm_spec.build_intent()
  lu.assertEvalToTrue(intent ~= nil and intent.type == "choice_select",
    "confirm intent is a choice_select")
  lu.assertEvalToTrue(intent.choice_id == "c9", "confirm intent carries the pending choice id")
  lu.assertEvalToTrue(intent.option_id == "opt1", "confirm intent carries the selected option")
end

function TestSecondaryConfirmScreen:test_cancel_build_intent_returns_a_choice_cancel_intent()
  local state = {}
  runtime_state.set_ui_model(state, { choice = { id = "c9" } })
  local specs = secondary_screen.build_route_specs(state)
  local cancel_spec
  for _, s in ipairs(specs) do
    if s.name == schema.cancel then cancel_spec = s end
  end
  local intent = cancel_spec.build_intent()
  lu.assertEvalToTrue(intent ~= nil and intent.type == "choice_cancel",
    "cancel intent is a choice_cancel")
  lu.assertEvalToTrue(intent.choice_id == "c9", "cancel intent carries the pending choice id")
end


return TestSecondaryConfirmScreen
