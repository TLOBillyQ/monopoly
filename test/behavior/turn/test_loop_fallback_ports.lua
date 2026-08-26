-- 原生 LuaUnit 改写：两个无钩子 describe 合并为一个 Test* 类（4 例），
-- assert.equals / assert.is_true / assert.has_no.errors 按映射切到 lu.assertXxx / luax。
local lu = require("luaunit")
local luax = require("test.support.luax")
local gameplay_loop = require("src.turn.loop.init")
local choice_auto_policy = require("src.turn.policies.choice_auto")
local bankruptcy_port = require("src.rules.ports.bankruptcy")
local turn_default_ports = require("src.turn.output.default_ports")

TestLoopFallbackPorts = {}

function TestLoopFallbackPorts:test_installs_complete_no_op_port_contracts()
  local game = {
    players = { { id = 1 } },
    turn = { current_player_index = 1 },
    dirty = {},
  }

  gameplay_loop._M_test.ensure_fallback_ports(game)

  lu.assertEquals(type(game.auto_play_port.is_computer_controlled), "function")
  lu.assertEquals(type(game.auto_play_port.auto_action_for_choice), "function")
  lu.assertEquals(type(game.auto_play_port.pick_target_player), "function")
  lu.assertEquals(type(game.auto_play_port.pick_remote_dice_value), "function")
  lu.assertEquals(type(game.auto_play_port.pick_roadblock_target), "function")
  lu.assertEquals(type(game.bankruptcy_port.eliminate), "function")

  local ok, action = pcall(choice_auto_policy.decide, game, nil, {
    id = "choice_1",
    options = { { id = "first" } },
  }, {
    allow_first_option_fallback = true,
  })

  lu.assertTrue(ok)
  lu.assertEquals(action and action.type, "choice_select")
  lu.assertEquals(action and action.option_id, "first")
  luax.has_no_error(function()
    bankruptcy_port.eliminate(game, game.players[1], { reason = "spec" })
  end)
end

function TestLoopFallbackPorts:test_installs_missing_ports_onto_an_existing_game_table_in_place()
  local game = { players = {} }

  local installed = turn_default_ports.install(game)

  lu.assertEquals(installed, game, "install 应就地返回同一张 game 表")
  lu.assertEquals(type(game.auto_play_port.is_computer_controlled), "function")
  lu.assertEquals(type(game.auto_play_port.auto_action_for_choice), "function")
  lu.assertEquals(type(game.bankruptcy_port.eliminate), "function")
end

function TestLoopFallbackPorts:test_keeps_ports_the_caller_already_provided()
  local auto_play_port = { is_computer_controlled = function() return true end }
  local bankruptcy_port_stub = { eliminate = function() return "kept" end }
  local game = { auto_play_port = auto_play_port, bankruptcy_port = bankruptcy_port_stub }

  turn_default_ports.install(game)

  lu.assertEquals(game.auto_play_port, auto_play_port, "已注入的 auto_play_port 不应被顶掉")
  lu.assertEquals(game.bankruptcy_port, bankruptcy_port_stub, "已注入的 bankruptcy_port 不应被顶掉")
end

function TestLoopFallbackPorts:test_passes_non_table_arguments_through_untouched()
  lu.assertEquals(turn_default_ports.install(nil), nil)
  lu.assertEquals(turn_default_ports.install(false), false)
  lu.assertEquals(turn_default_ports.install("not_a_game"), "not_a_game")
end


return TestLoopFallbackPorts
