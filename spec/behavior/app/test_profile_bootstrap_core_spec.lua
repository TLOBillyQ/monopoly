local support = require("spec.support.test_profile_support")
local test_profile_resolver = require("src.app.testing.test_profile_resolver")
local startup_bootstrap = require("src.app.profile_bootstrap")

describe("runtime.test_profile_bootstrap_core", function()
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

  it("profile_bootstrap_sets_tile_level", function()
    local game = support.new_game()
    startup_bootstrap.apply_bootstrap(game, {
      tiles = { [1] = { level = 2 } },
    })
    local tile = game.board:get_tile_by_id(1)
    assert(tile ~= nil, "tile id=1 must exist in default board")
    assert(tile.level == 2, "bootstrap should have set tile level to 2, got: " .. tostring(tile.level))
  end)

  it("profile_bootstrap_sets_tile_owner", function()
    local game = support.new_game()
    local player = game.players[1]
    startup_bootstrap.apply_bootstrap(game, {
      tiles = { [1] = { owner_player_index = 1, level = 1 } },
    })
    local tile = game.board:get_tile_by_id(1)
    assert(tile ~= nil, "tile id=1 must exist in default board")
    assert(tile.owner_id == player.id,
      "bootstrap should have set tile owner to player 1, got: " .. tostring(tile.owner_id))
  end)

  it("profile_bootstrap_places_roadblock_overlay", function()
    local game = support.new_game()
    startup_bootstrap.apply_bootstrap(game, {
      overlays = { roadblocks = { 1 } },
    })
    local board_index = game.board:index_of_tile_id(1)
    assert(board_index ~= nil, "tile id=1 must be in board path")
    assert(game.board:has_roadblock(board_index),
      "bootstrap should have placed a roadblock at board index " .. tostring(board_index))
  end)

  it("profile_bootstrap_places_mine_overlay", function()
    local game = support.new_game()
    startup_bootstrap.apply_bootstrap(game, {
      overlays = { mines = { 1 } },
    })
    local board_index = game.board:index_of_tile_id(1)
    assert(board_index ~= nil, "tile id=1 must be in board path")
    assert(game.board:has_mine(board_index),
      "bootstrap should have placed a mine at board index " .. tostring(board_index))
  end)

  it("profile_bootstrap_sets_current_turn_player_index", function()
    local game = support.new_game()
    startup_bootstrap.apply_bootstrap(game, {
      current_turn_player_index = 2,
    })
    assert(game.turn.current_player_index == 2,
      "bootstrap should set current_player_index to 2, got: " .. tostring(game.turn.current_player_index))
  end)

  it("profile_bootstrap_skips_turn_bootstrap_when_nil", function()
    local game = support.new_game()
    local original_index = game.turn.current_player_index
    startup_bootstrap.apply_bootstrap(game, {})
    assert(game.turn.current_player_index == original_index,
      "bootstrap should not change current_player_index when cfg omits it")
  end)

  it("profile_bootstrap_applies_market_limits", function()
    local game = support.new_game()
    local product_id = game.market_limits and next(game.market_limits) or nil
    if product_id then
      startup_bootstrap.apply_bootstrap(game, {
        market_limits = { [product_id] = 0 },
      })
      assert(game.market_limits[product_id] == 0,
        "bootstrap should override market limit to 0, got: " .. tostring(game.market_limits[product_id]))
    end
  end)
end)
