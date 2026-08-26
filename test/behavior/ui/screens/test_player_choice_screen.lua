-- player 选择屏 Screen 深模块直测：descriptor 字段 + 路由意图 + registry 注册。
local lu = require("luaunit")
local registry = require("src.ui.screens_registry")
local player_screen = require("src.ui.screens.player_choice")
local schema = require("src.ui.schema.player_choice")

-- 原生 LuaUnit(推翻自研 busted 兼容运行器决策的迁移):describe/it 拍平为文件级 Test* 类,
-- 无钩子不拆类,用例数与改写前一一对应(3 例);断言从裸 assert 切到 lu.assertXxx。
TestPlayerChoiceScreen = {}

function TestPlayerChoiceScreen:test_exposes_a_descriptor_with_the_pinned_player_fields()
  local d = player_screen.descriptor()
  lu.assertEvalToTrue(d.key == "player", "descriptor key is player")
  lu.assertNotNil(d.root, "has root/canvas node")
  lu.assertNotNil(d.title, "has title")
  lu.assertNotNil(d.option_buttons, "has option_buttons")
end

function TestPlayerChoiceScreen:test_registers_itself_into_the_registry_under_its_key()
  lu.assertNotNil(registry.build_choice_screens().player, "registry aggregates player descriptor")
  lu.assertEvalToTrue(registry.canvas_for("player") == player_screen.canvas, "registry maps player canvas")
  lu.assertEvalToTrue(registry.opener_for("player") == player_screen.open, "registry maps player opener")
end

function TestPlayerChoiceScreen:test_builds_a_route_spec_for_every_slot_node()
  local specs = player_screen.build_route_specs({})
  local spec_names = {}
  for _, s in ipairs(specs) do
    spec_names[s.name] = true
  end
  for _, name in ipairs(schema.slots) do
    lu.assertEvalToTrue(spec_names[name], "slot node has route spec: " .. name)
  end
end


return TestPlayerChoiceScreen
