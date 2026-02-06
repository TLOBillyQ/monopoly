local projection_service_mod = require("src.v2.application.ProjectionService")
local intent_mapper_mod = require("src.v2.presentation.IntentMapper")

local t = dofile(".agents/tests/v2/helpers/testkit.lua")

local function _read_file(path)
  local fd = io.open(path, "r")
  if not fd then
    return nil
  end
  local content = fd:read("*a")
  fd:close()
  return content
end

local function _test_projection_item_slots_and_phase()
  local service = t.new_service()
  local state = service:state()
  t.give_item(state, state.turn.current_seat, 2001)
  local projection = service:projection()
  t.assert_true(type(projection.item_slots) == "table", "投影应包含道具槽")
  t.assert_eq(projection.item_slots[1], 2001, "道具槽应反映当前玩家道具")
  t.assert_true(type(projection.panel.phase_label) == "string", "投影应包含阶段标签")
end

local function _test_projection_market_choice()
  local service = t.new_service()
  local state = service:state()
  local choice = t.services.market.build_choice(state, 1)
  t.assert_true(choice ~= nil, "黑市应可生成选择")
  state.turn.pending_interaction = choice
  state.turn.phase = "wait_choice"
  state.ui_selected_market_option = t.first_option_id(choice)
  local projection = service:projection()
  t.assert_true(projection.choice ~= nil, "应投影通用选择")
  t.assert_true(projection.market ~= nil, "黑市选择应投影 market 结构")
end

local function _test_intent_mapper_use_item()
  local service = t.new_service()
  local mapper = intent_mapper_mod.new()
  local command = mapper:to_command({ type = "use_item", item_id = 2001 }, 101, service:state())
  t.assert_true(command ~= nil, "use_item 意图应映射命令")
  t.assert_eq(command.type, t.commands.types.use_item, "命令类型应为 use_item")
  t.assert_eq(command.payload.item_id, 2001, "应透传 item_id")
end

local function _test_intent_mapper_market_buy()
  local service = t.new_service()
  local mapper = intent_mapper_mod.new()
  local command = mapper:to_command({ type = "market_buy", option_id = 2003 }, 101, service:state())
  t.assert_true(command ~= nil, "market_buy 意图应映射命令")
  t.assert_eq(command.type, t.commands.types.market_buy, "命令类型应为 market_buy")
  t.assert_eq(command.payload.option_id, 2003, "应透传 option_id")
end

local function _test_intent_mapper_anim_and_restart()
  local service = t.new_service()
  local mapper = intent_mapper_mod.new()
  local move_done = mapper:to_command({ type = "move_anim_done", seq = 9 }, 101, service:state())
  local action_done = mapper:to_command({ type = "action_anim_done", seq = 5 }, 101, service:state())
  local restart = mapper:to_command({ type = "restart_match" }, 101, service:state())
  t.assert_eq(move_done.type, t.commands.types.move_anim_done, "move anim done 映射错误")
  t.assert_eq(action_done.type, t.commands.types.action_anim_done, "action anim done 映射错误")
  t.assert_eq(restart.type, t.commands.types.restart_match, "restart 映射错误")
end

local function _test_architecture_guard_no_src_game_import()
  local files = {
    "src/app/init.lua",
  }
  local p = io.popen("find src/v2 -type f -name '*.lua' | sort")
  if p then
    for line in p:lines() do
      files[#files + 1] = line
    end
    p:close()
  end
  for _, path in ipairs(files) do
    local content = _read_file(path)
    t.assert_true(content ~= nil, "读取文件失败: " .. tostring(path))
    local hit = string.find(content, "src%.game%.", 1)
    t.assert_true(hit == nil, "架构守卫失败，发现 src.game 依赖: " .. tostring(path))
  end
end

local function _test_runtime_loaded_modules_guard()
  local _ = projection_service_mod
  local __ = intent_mapper_mod
  for name in pairs(package.loaded) do
    local hit = string.find(name, "src%.game%.", 1)
    t.assert_true(hit == nil, "运行期不应加载 legacy 模块: " .. tostring(name))
  end
end

return {
  { name = "presentation/projection_item_slots", run = _test_projection_item_slots_and_phase },
  { name = "presentation/projection_market_choice", run = _test_projection_market_choice },
  { name = "presentation/intent_mapper_use_item", run = _test_intent_mapper_use_item },
  { name = "presentation/intent_mapper_market_buy", run = _test_intent_mapper_market_buy },
  { name = "presentation/intent_mapper_anim_restart", run = _test_intent_mapper_anim_and_restart },
  { name = "architecture/no_src_game_import", run = _test_architecture_guard_no_src_game_import },
  { name = "architecture/runtime_module_guard", run = _test_runtime_loaded_modules_guard },
}
