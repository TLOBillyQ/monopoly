local gameplay_loop = require("src.turn.loop.init")
local choice_auto_policy = require("src.turn.policies.choice_auto")
local bankruptcy_port = require("src.rules.ports.bankruptcy")

describe("gameplay loop fallback ports", function()
  it("installs complete no-op port contracts", function()
    local game = {
      players = { { id = 1, auto = false } },
      turn = { current_player_index = 1 },
      dirty = {},
    }

    gameplay_loop._M_test.ensure_fallback_ports(game)

    assert.equals("function", type(game.auto_play_port.is_auto_player))
    assert.equals("function", type(game.auto_play_port.auto_action_for_choice))
    assert.equals("function", type(game.auto_play_port.pick_target_player))
    assert.equals("function", type(game.auto_play_port.pick_remote_dice_value))
    assert.equals("function", type(game.auto_play_port.pick_roadblock_target))
    assert.equals("function", type(game.bankruptcy_port.eliminate))

    local ok, action = pcall(choice_auto_policy.decide, game, nil, {
      id = "choice_1",
      options = { { id = "first" } },
    }, {
      allow_first_option_fallback = true,
    })

    assert.is_true(ok)
    assert.equals("choice_select", action and action.type)
    assert.equals("first", action and action.option_id)
    assert.has_no.errors(function()
      bankruptcy_port.eliminate(game, game.players[1], { reason = "spec" })
    end)
  end)
end)
