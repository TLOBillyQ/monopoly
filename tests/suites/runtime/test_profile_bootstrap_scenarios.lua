local support = require("support.test_profile_support")
local tile_state = support.tile_state

local function _test_market_is_eight_steps_before_market()
  local game = support.apply_profile("market")
  local market_index = game.board:index_of_tile_id(support.map_cfg.market_id)
  assert(market_index ~= nil, "market tile id should exist in board path")
  assert(game.players[1].position + 8 == market_index,
    "p1 should start eight steps before market after bootstrap")
end

local function _test_hospital_is_before_hospital_with_remote_dice()
  local game = support.apply_profile("hospital")
  local p1_pos = game.players[1].position
  local hospital_idx = game.board:index_of_tile_id(36)
  assert(hospital_idx ~= nil, "hospital tile should exist in board path")
  assert(p1_pos + 1 == hospital_idx, "p1 should start one step before hospital")
  support.assert_inventory_counts(game.players[1], { [2002] = 1 })
end

local function _test_mountain_is_before_mountain_with_remote_dice()
  local game = support.apply_profile("mountain")
  local p1_pos = game.players[1].position
  local mountain_idx = game.board:index_of_tile_id(37)
  assert(mountain_idx ~= nil, "mountain tile should exist in board path")
  assert(p1_pos + 1 == mountain_idx, "p1 should start one step before mountain")
  support.assert_inventory_counts(game.players[1], { [2002] = 1 })
end

local function _test_strong_card_bootstraps_rent_target()
  local game = support.apply_profile("strong_card")
  local target_tile = assert(game.board:get_tile_by_id(12), "strong card staging target tile should exist")
  local target_state = tile_state(game, target_tile)
  local player_index = game.board:index_of_tile_id(11)

  assert(game.players[1].position == player_index, "strong card staging should place p1 on configured tile")
  support.assert_inventory_counts(game.players[1], {
    [2001] = 1,
    [2002] = 1,
    [2009] = 1,
  })
  assert(target_state.owner_id == game.players[2].id, "strong card staging should assign target building owner")
  assert(target_state.level == 2, "strong card staging should assign target building level")
end

local function _test_monster_bootstraps_target_building()
  local game = support.apply_profile("monster")
  local target_tile = assert(game.board:get_tile_by_id(12), "monster staging target tile should exist")
  local target_state = tile_state(game, target_tile)
  local player_index = game.board:index_of_tile_id(40)

  assert(game.players[1].position == player_index, "monster staging should place p1 on configured tile")
  support.assert_inventory_counts(game.players[1], {
    [2002] = 1,
    [2008] = 1,
  })
  assert(target_state.owner_id == game.players[2].id, "monster staging should assign target building owner")
  assert(target_state.level == 2, "monster staging should assign target building level")
end

local function _test_missile_bootstraps_target_tile_and_overlays()
  local game = support.apply_profile("missile")
  local target_tile = assert(game.board:get_tile_by_id(11), "missile staging target tile should exist")
  local target_state = tile_state(game, target_tile)
  local target_index = game.board:index_of_tile_id(11)
  local player_index = game.board:index_of_tile_id(40)

  assert(game.players[1].position == player_index, "missile staging should place p1 on configured tile")
  support.assert_inventory_counts(game.players[1], {
    [2002] = 1,
    [2013] = 1,
  })
  assert(target_state.owner_id == game.players[2].id, "missile staging should assign target building owner")
  assert(target_state.level == 2, "missile staging should assign target building level")
  assert(game.board:has_roadblock(target_index) == true, "missile staging should place roadblock on target tile")
  assert(game.board:has_mine(target_index) == true, "missile staging should place mine on target tile")
  assert(game.players[2].position == target_index, "missile staging should place occupant on target tile")
end

local function _test_mine_bootstraps_positions_and_inventory()
  local game = support.apply_profile("mine")
  support.assert_player_on_tile_id(game, 1, 7)
  support.assert_player_on_tile_id(game, 2, 6)
  support.assert_inventory_counts(game.players[1], { [2005] = 1 })
  support.assert_inventory_counts(game.players[2], { [2002] = 1 })
end

local function _test_circle_bootstraps_position_and_inventory()
  local game = support.apply_profile("circle")
  support.assert_player_on_tile_id(game, 1, 15)
  support.assert_inventory_counts(game.players[1], { [2002] = 2 })
end

local function _test_forced_move_hospital_bootstraps_position_and_remote_dice()
  local game = support.apply_profile("forced_move_hospital")
  support.assert_player_on_tile_id(game, 1, 44)
  support.assert_inventory_counts(game.players[1], { [2002] = 1 })
end

local function _test_exile_bootstraps_target_pair_and_item()
  local game = support.apply_profile("exile")
  support.assert_player_on_tile_id(game, 1, 7)
  support.assert_player_on_tile_id(game, 2, 8)
  support.assert_inventory_counts(game.players[1], { [2012] = 1 })
end

local function _test_roadblock_hit_bootstraps_forward_overlay()
  local game = support.apply_profile("roadblock_hit")
  local target_index = assert(game.board:index_of_tile_id(8), "roadblock_hit target tile should exist")
  support.assert_player_on_tile_id(game, 1, 7)
  assert(game.board:has_roadblock(target_index) == true, "roadblock_hit should preload roadblock overlay")
  support.assert_inventory_counts(game.players[1], { [2002] = 1 })
end

local function _test_clear_obstacles_bootstraps_overlay_cluster()
  local game = support.apply_profile("clear_obstacles")
  local idx8 = assert(game.board:index_of_tile_id(8), "clear_obstacles tile 8 should exist")
  local idx9 = assert(game.board:index_of_tile_id(9), "clear_obstacles tile 9 should exist")
  assert(game.board:has_roadblock(idx8) == true, "clear_obstacles should preload first roadblock")
  assert(game.board:has_roadblock(idx9) == true, "clear_obstacles should preload second roadblock")
  assert(game.board:has_mine(idx9) == true, "clear_obstacles should preload mine on second obstacle tile")
  support.assert_inventory_counts(game.players[1], { [2006] = 1 })
end

local function _test_steal_bootstraps_positions_and_inventory()
  local game = support.apply_profile("steal")
  support.assert_player_on_tile_id(game, 1, 7)
  support.assert_player_on_tile_id(game, 2, 8)
  support.assert_inventory_counts(game.players[1], { [2007] = 1 })
  support.assert_inventory_counts(game.players[2], { [2001] = 1, [2010] = 1 })
end

local function _test_steal_one_bootstraps_positions_and_inventory()
  local game = support.apply_profile("steal_one")
  support.assert_player_on_tile_id(game, 1, 7)
  support.assert_player_on_tile_id(game, 2, 8)
  support.assert_inventory_counts(game.players[1], { [2007] = 1 })
  support.assert_inventory_counts(game.players[2], { [2001] = 1 })
end

local function _test_steal_queue_keeps_route_and_interrupt_stable()
  local game = support.apply_profile("steal_queue")
  local p1 = game.players[1]
  local p2 = game.players[2]
  local p3 = game.players[3]
  local p1_index = assert(game.board:index_of_tile_id(7), "tile 7 should exist in board path")
  local p2_index = assert(game.board:index_of_tile_id(8), "tile 8 should exist in board path")
  local p3_index = assert(game.board:index_of_tile_id(9), "tile 9 should exist in board path")
  local landing_tile = assert(game.board:get_tile(p1_index + 3), "steal queue landing tile should exist")

  assert(p1.position == p1_index, "queue steal staging should place p1 on tile 7")
  assert(p2.position == p2_index, "queue steal staging should place p2 on tile 8")
  assert(p3.position == p3_index, "queue steal staging should place p3 on tile 9")
  assert(landing_tile.id == 40, "queue steal staging should keep tile 40 as three-step landing tile")

  local move_result = support.movement.move(game, p1, 3, { branch_parity = 3, skip_market_check = true })
  local interrupt = assert(move_result.steal_interrupt, "queue steal staging should still trigger steal interrupt")

  assert(interrupt.position == p2_index, "current steal interrupt should stop on the first encountered player tile")
  assert(interrupt.remaining_steps == 2, "steal interrupt should leave two resumable steps from tile 8")
  assert(#(interrupt.encountered_ids or {}) == 1 and interrupt.encountered_ids[1] == p2.id,
    "current steal interrupt should only capture current-step targets")
end

return {
  name = "runtime.test_profile_bootstrap_scenarios",
  tests = {
    { name = "market_is_eight_steps_before_market", run = _test_market_is_eight_steps_before_market },
    { name = "hospital_is_before_hospital_with_remote_dice", run = _test_hospital_is_before_hospital_with_remote_dice },
    { name = "mountain_is_before_mountain_with_remote_dice", run = _test_mountain_is_before_mountain_with_remote_dice },
    { name = "strong_card_bootstraps_rent_target", run = _test_strong_card_bootstraps_rent_target },
    { name = "monster_bootstraps_target_building", run = _test_monster_bootstraps_target_building },
    { name = "missile_bootstraps_target_tile_and_overlays", run = _test_missile_bootstraps_target_tile_and_overlays },
    { name = "mine_bootstraps_positions_and_inventory", run = _test_mine_bootstraps_positions_and_inventory },
    { name = "circle_bootstraps_position_and_inventory", run = _test_circle_bootstraps_position_and_inventory },
    { name = "forced_move_hospital_bootstraps_position_and_remote_dice", run = _test_forced_move_hospital_bootstraps_position_and_remote_dice },
    { name = "exile_bootstraps_target_pair_and_item", run = _test_exile_bootstraps_target_pair_and_item },
    { name = "roadblock_hit_bootstraps_forward_overlay", run = _test_roadblock_hit_bootstraps_forward_overlay },
    { name = "clear_obstacles_bootstraps_overlay_cluster", run = _test_clear_obstacles_bootstraps_overlay_cluster },
    { name = "steal_bootstraps_positions_and_inventory", run = _test_steal_bootstraps_positions_and_inventory },
    { name = "steal_one_bootstraps_positions_and_inventory", run = _test_steal_one_bootstraps_positions_and_inventory },
    { name = "steal_queue_keeps_route_and_interrupt_stable", run = _test_steal_queue_keeps_route_and_interrupt_stable },
  },
}
