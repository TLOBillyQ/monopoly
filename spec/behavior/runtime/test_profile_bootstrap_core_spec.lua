local support = require("support.test_profile_support")
local tile_state = support.tile_state
local test_profile_resolver = require("src.app.testing.test_profile_resolver")

describe("runtime.test_profile_bootstrap_core", function()
  it("profile_bootstrap_applies_player_position_by_tile_id", function()
    local game = support.apply_profile("bankruptcy")
    support.assert_player_on_tile_id(game, 1, 35)
    support.assert_player_on_tile_id(game, 2, 39)
  end)

  it("profile_bootstrap_applies_item_counts", function()
    local game = support.apply_profile("tax")
    support.assert_inventory_counts(game.players[1], {
      [2002] = 1,
      [2010] = 1,
    })
    assert(game.players[1].inventory:count() == 2, "tax should grant exactly 2 items to p1")
  end)

  it("profile_bootstrap_rejects_item_count_over_inventory_limit", function()
    local game = support.new_game()
    local ok, err = pcall(function()
      support.with_patches({
        {
          target = test_profile_resolver,
          key = "resolve_bootstrap",
          value = function()
            return {
              players = {
                [1] = {
                  item_counts = {
                    [2001] = 2,
                    [2002] = 2,
                    [2003] = 2,
                  },
                },
              },
            }
          end,
        },
      }, function()
        require("src.app.testing.test_profile_bootstrap").apply(game, "default")
      end)
    end)
    assert(ok == false, "item_counts exceeding inventory limit should fail fast")
    assert(tostring(err):find("item_counts exceeds inventory limit", 1, true) ~= nil,
      "error should explain inventory limit breach")
  end)

  it("bankruptcy_applies_tile_override", function()
    local game = support.apply_profile("bankruptcy")
    local tile = game.board:get_tile_by_id(1)
    local state = tile_state(game, tile)
    assert(state.owner_id == game.players[2].id, "tile 1 owner should be player2")
    assert(state.level == 3, "tile 1 level should be 3")
    assert(game.players[2].properties[1] == true, "player2 should own tile 1")
    assert(game.players[1].cash == 3000, "p1 cash should match bankruptcy")
  end)

  it("upgrade_build_applies_bootstrap", function()
    local game = support.apply_profile("upgrade_build")
    support.assert_player_on_tile_id(game, 1, 35)

    local tile = game.board:get_tile_by_id(1)
    local state = tile_state(game, tile)
    assert(state.owner_id == game.players[1].id, "tile 1 owner should be player1")
    assert(state.level == 0, "tile 1 level should be 0")
    assert(game.players[1].properties[1] == true, "player1 should own tile 1")
    support.assert_inventory_counts(game.players[1], {
      [2002] = 1,
    })
  end)

  it("market_applies_player_position", function()
    local game = support.apply_profile("market")
    support.assert_player_on_tile_id(game, 1, 27)
  end)

  it("market_preloads_remote_dice", function()
    local game = support.apply_profile("market")
    support.assert_inventory_counts(game.players[1], {
      [2002] = 2,
    })
  end)
end)
