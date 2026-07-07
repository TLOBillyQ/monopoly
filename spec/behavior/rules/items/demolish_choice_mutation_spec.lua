-- Mutation-pinning specs for src/rules/items/demolish_choice.lua.
--
-- Calls demolish_choice DIRECTLY (see demolish_apply_mutation_spec header for why
-- the shared demolish.lua facade shields the mutated module).
--
-- Surviving mutants targeted here:
--   L23  `value < 0` -> `value <= 0`  (boundary at value == 0)
--   L23  `value < 0` -> `value < 1`   (boundary at value == 0)
--   L30  `not idx or idx == player.position` -> `and`  (position tile exclusion)
--
-- Both L23 mutants are killed with a value-0 target: an enemy building whose
-- total_invested is 0 (price 0, no upgrade costs) but whose level > 0. The
-- original `< 0` keeps it (0 < 0 == false -> return idx); both mutants drop it
-- (0 <= 0 / 0 < 1 == true -> return nil).
local support = require("spec.support.shared_support")
local default_map = require("src.config.content.default_map")
local item_ids = require("src.config.gameplay.item_ids")
local demolish_choice = require("src.rules.items.demolish_choice")

local _assert_eq = support.assert_eq

local function _game(players)
  return support.new_game({ map = default_map, players = players or { "P1", "P2", "P3", "P4" } })
end

local function _enemy_building(game, idx, level)
  local tile = game.board:get_tile(idx)
  game:set_tile_owner(tile, 2)
  game:set_tile_level(tile, level)
  return tile
end

-- A level-1 enemy building whose total_invested evaluates to exactly 0
-- (purchase price 0 + no upgrade costs). find_target's score_fn returns this 0.
local function _zero_value_enemy(game, idx)
  local tile = _enemy_building(game, idx, 1)
  tile.price = 0
  tile.upgrade_costs = {}
  return tile
end

describe("demolish_choice mutation pins (direct module)", function()
  -- L23 `value < 0` boundary: `< 0` -> `<= 0` and `< 0` -> `< 1` ---------------
  it("find_target keeps a zero-invested enemy building (L23 'value < 0' boundary)", function()
    local g = _game({ "P1", "P2" })
    local p = g:current_player()
    assert(p.id ~= 2, "acting player must differ from the enemy owner id 2")

    -- Pick a land tile in range that is not the player's own position.
    local target_idx = nil
    for idx = 1, 60 do
      local tile = g.board:get_tile(idx)
      if tile and tile.type == "land" and idx ~= p.position then
        target_idx = idx
        break
      end
    end
    assert(target_idx, "map must expose a land tile away from the player")
    _zero_value_enemy(g, target_idx)

    local picked = demolish_choice.find_target(g, p, 60)
    _assert_eq(picked, target_idx,
      "value == 0 must be kept (0 < 0 is false); '<= 0' and '< 1' mutants would return nil")
  end)

  it("find_target still returns nil when there is no eligible enemy building", function()
    -- Anchors the negative side: a genuinely absent target (value == -1) stays nil
    -- under the original and both L23 boundary mutants, so the positive test above
    -- is the sole discriminator for value == 0.
    local g = _game({ "P1", "P2" })
    local p = g:current_player()
    _assert_eq(demolish_choice.find_target(g, p, 60), nil, "no eligible tile -> nil")
  end)

  -- L30 `not idx or idx == player.position` -> `and` --------------------------
  it("build_human_choice rejects the fallback best_idx that is the player's own tile (L30 'or')", function()
    -- board_query.indices_in_range already excludes the start tile, so
    -- `idx == player.position` is only reachable via the `#options == 0` fallback,
    -- which pushes best_idx. We make best_idx == player.position (an enemy building
    -- underfoot) and leave the range empty of other targets.
    --   Original `not idx or idx == position`: idx == position -> return nil ->
    --     _is_demolishable_tile rejects -> options stay empty -> build returns nil.
    --   Mutant `not idx and idx == position`: `not idx` is false -> guard skipped ->
    --     the position tile is accepted and pushed -> build returns a choice.
    local g = _game({ "P1", "P2" })
    local p = g:current_player()
    assert(p.id ~= 2, "acting player must differ from the enemy owner id 2")

    -- Put the acting player on a land tile and make it an enemy building.
    local pos_idx = nil
    for idx = 1, 60 do
      local tile = g.board:get_tile(idx)
      if tile and tile.type == "land" then
        pos_idx = idx
        break
      end
    end
    assert(pos_idx, "map must expose a land tile")
    g:update_player_position(p, pos_idx)
    _enemy_building(g, pos_idx, 2) -- enemy building directly under the player

    -- No other owned tiles exist, so the in-range scan yields zero options and the
    -- fallback push(best_idx == pos_idx) is the sole candidate.
    local choice = demolish_choice.build_human_choice(g, p, 60, pos_idx,
      { item_id = item_ids.monster, injure = false, title = "怪兽卡" })

    _assert_eq(choice, nil,
      "the player's own tile must never become an option; the 'and' mutant accepts it and returns a choice")
  end)
end)
