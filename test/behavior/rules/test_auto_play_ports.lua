-- auto_play 端口转发直测:is_computer_controlled / pick_roadblock_target /
-- auto_action_for_choice 的参数透传与返回值契约(其余转发面由 item_play_context 测试驱动)。
local lu = require("luaunit")

local auto_play = require("src.rules.ports.auto_play")

TestAutoPlayPorts = {}

function TestAutoPlayPorts:test_is_computer_controlled_forwards_to_the_injected_port()
  local seen = {}
  local game = {
    auto_play_port = {
      is_computer_controlled = function(g, player)
        seen.g = g
        seen.player = player
        return true
      end,
    },
  }
  local player = { id = 2 }
  local result = auto_play.is_computer_controlled(game, player)

  lu.assertEvalToTrue(result == true, "the port result must pass through")
  lu.assertEvalToTrue(seen.g == game, "the game must be forwarded")
  lu.assertEvalToTrue(seen.player == player, "the player must be forwarded")
end

function TestAutoPlayPorts:test_pick_roadblock_target_forwards_to_the_injected_port()
  local seen = {}
  local game = {
    auto_play_port = {
      pick_roadblock_target = function(g, player, candidates)
        seen.g = g
        seen.player = player
        seen.candidates = candidates
        return candidates[1]
      end,
    },
  }
  local player = { id = 2 }
  local candidates = { { id = 5 }, { id = 6 } }
  local result = auto_play.pick_roadblock_target(game, player, candidates)

  lu.assertEvalToTrue(result == candidates[1], "the port result must pass through")
  lu.assertEvalToTrue(seen.g == game, "the game must be forwarded")
  lu.assertEvalToTrue(seen.player == player, "the player must be forwarded")
  lu.assertEvalToTrue(seen.candidates == candidates, "the candidates must be forwarded")
end

function TestAutoPlayPorts:test_auto_action_for_choice_forwards_to_the_injected_port()
  local seen = {}
  local game = {
    auto_play_port = {
      auto_action_for_choice = function(g, choice)
        seen.g = g
        seen.choice = choice
        return "auto_action"
      end,
    },
  }
  local choice = { id = 1 }
  local result = auto_play.auto_action_for_choice(game, choice)

  lu.assertEvalToTrue(result == "auto_action", "the port result must pass through")
  lu.assertEvalToTrue(seen.g == game, "the game must be forwarded")
  lu.assertEvalToTrue(seen.choice == choice, "the choice must be forwarded")
end

return TestAutoPlayPorts
