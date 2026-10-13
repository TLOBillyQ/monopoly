-- auto_play 端口转发直测:is_computer_controlled / pick_roadblock_target /
-- auto_action_for_choice 的参数透传与返回值契约(其余转发面由 item_play_context 测试驱动)。
require("test.bootstrap").install_package_paths()
local luassert = assert

local auto_play = require("src.rules.ports.auto_play")

describe("TestAutoPlayPorts", function()
it("test_is_computer_controlled_forwards_to_the_injected_port", function()
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

  luassert.truthy(result == true, "the port result must pass through")
  luassert.truthy(seen.g == game, "the game must be forwarded")
  luassert.truthy(seen.player == player, "the player must be forwarded")
end)

it("test_pick_roadblock_target_forwards_to_the_injected_port", function()
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

  luassert.truthy(result == candidates[1], "the port result must pass through")
  luassert.truthy(seen.g == game, "the game must be forwarded")
  luassert.truthy(seen.player == player, "the player must be forwarded")
  luassert.truthy(seen.candidates == candidates, "the candidates must be forwarded")
end)

it("test_auto_action_for_choice_forwards_to_the_injected_port", function()
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

  luassert.truthy(result == "auto_action", "the port result must pass through")
  luassert.truthy(seen.g == game, "the game must be forwarded")
  luassert.truthy(seen.choice == choice, "the choice must be forwarded")
end)

end)
