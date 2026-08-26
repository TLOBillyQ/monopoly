-- ui/input/intent_dispatcher.lua 直测:intent 派发分流——端口解析/兜底
-- 调用、view-command 终态、should_block 短路、无 game 告警、game-action 优先。
local lu = require("luaunit")
local luax = require("test.support.luax")
local support = require("test.support.shared_support")

local intent_dispatcher = require("src.ui.input.intent_dispatcher")
local turn_action_port = require("src.ui.input.turn_action")
local game_action_dispatcher = require("src.ui.input.game_action")
local command_policy = require("src.ui.input.command_policy")
local log = require("src.foundation.log")

TestIntentDispatcher = {}

local function _drive(opts)
  local captured = {}
  opts = opts or {}
  local port_calls = 0
  support.with_patches({
    { target = turn_action_port, key = "resolve", value = function()
      port_calls = port_calls + 1
      captured.resolve_calls = port_calls
      return { id = "port" .. port_calls }
    end },
    { target = turn_action_port, key = "should_block", value = function()
      return opts.blocked or false
    end },
    { target = game_action_dispatcher, key = "dispatch", value = function(_, _, intent, _, port, _)
      captured.game_action = { intent = intent, port = port }
      return opts.game_action_consumed or false
    end },
    { target = command_policy, key = "dispatches_before_game", value = function()
      return opts.before_game or false
    end },
    { target = intent_dispatcher, key = "dispatch_view_command", value = function(state, intent)
      captured.view_command = intent
    end },
    { target = log, key = "warn", value = function(...)
      captured.warned = captured.warned or {}
      captured.warned[#captured.warned + 1] = table.concat({ ... }, " ")
    end },
  }, function()
    local game
    if opts.no_game then
      game = nil
    else
      game = { id = "g" }
    end
    intent_dispatcher.dispatch({ id = "st" }, game, { type = "move" }, {})
  end)
  return captured
end

-- 无显式端口时解析一次并转发给 game-action。
function TestIntentDispatcher:test_resolves_the_turn_action_port_once()
  local captured = _drive({})
  lu.assertEvalToTrue(captured.resolve_calls == 1, "the port must resolve exactly once")
  lu.assertEvalToTrue(captured.game_action ~= nil, "a game action must dispatch")
  lu.assertEvalToTrue(captured.game_action.port.id == "port1", "the resolved port must be forwarded")
  lu.assertEvalToTrue(captured.game_action.intent.type == "move", "the intent must be forwarded")
end

-- 兜底 or 短路:action_port 已非 nil 时不得再解析(变异 or→and 会解析
-- 两次,第二次端口对象不同,断言拆穿)。
function TestIntentDispatcher:test_resolve_or_fallback_must_not_double_resolve()
  local captured = _drive({})
  lu.assertEvalToTrue(captured.resolve_calls == 1, "the fallback must short-circuit")
end

-- 缺 intent 断言带消息。
function TestIntentDispatcher:test_missing_intent_asserts()
  luax.has_error(function()
    intent_dispatcher.dispatch({ id = "st" }, { id = "g" }, nil, {})
  end, "missing intent")
end

-- should_block 短路:两个派发面都不动。
function TestIntentDispatcher:test_blocked_intent_skips_both_dispatches()
  local captured = _drive({ blocked = true })
  lu.assertEvalToTrue(captured.game_action == nil and captured.view_command == nil,
    "a blocked intent must not dispatch anywhere")
end

-- 无 game 时告警,告警携带 intent 类型。
function TestIntentDispatcher:test_without_game_warns_with_the_intent_type()
  local captured = _drive({ no_game = true })
  lu.assertEvalToTrue(captured.warned ~= nil and #captured.warned >= 1,
    "a missing game must warn")
  lu.assertEvalToTrue(captured.warned[1]:find("move", 1, true) ~= nil,
    "the warning must carry the intent type")
  lu.assertEvalToTrue(captured.view_command == nil, "a missing game must not dispatch a view command")
end

-- view command 在 game 前派发即为终态。
function TestIntentDispatcher:test_view_command_before_game_is_terminal()
  local captured = _drive({ before_game = true })
  lu.assertEvalToTrue(captured.view_command ~= nil, "a before-game intent must dispatch the view command")
  lu.assertEvalToTrue(captured.game_action == nil, "the game action must not dispatch")
end

-- game-action 消费后不再回落 view command。
function TestIntentDispatcher:test_game_action_consumed_skips_view_command()
  local captured = _drive({ game_action_consumed = true })
  lu.assertEvalToTrue(captured.game_action ~= nil, "the game action must dispatch")
  lu.assertEvalToTrue(captured.view_command == nil, "a consumed action must not fall through")
end

-- game-action 未消费时回落 view command。
function TestIntentDispatcher:test_falls_through_to_view_command()
  local captured = _drive({})
  lu.assertEvalToTrue(captured.game_action ~= nil, "the game action must dispatch first")
  lu.assertEvalToTrue(captured.view_command ~= nil, "an unconsumed action must fall through")
end

return TestIntentDispatcher
