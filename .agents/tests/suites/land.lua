local support = require("TestSupport")
local _new_game = support.new_game
local _first_land_tile = support.first_land_tile
local _first_adjacent_land_pair = support.first_adjacent_land_pair
local _tile_state = support.tile_state
local _assert_eq = support.assert_eq
local _resolve_landing = support.resolve_landing
local land_actions = support.land_actions
local pricing = support.pricing
local choice_resolver = support.choice_resolver

local function _test_ai_picks_land_purchase()
  local agent = require("src.game.core.runtime.Agent")
  local g = _new_game()
  local ai_player = g.players[2]
  assert(agent.is_auto_player(ai_player), "player 2 should be AI")

  g.turn.current_player_index = 2
  g.dirty.turn = true
  g.dirty.any = true

  assert(g:current_player() == ai_player, "AI should be current player")

  local idx, tile_ref = _first_land_tile(g.board)
  g:update_player_position(ai_player, idx)

  local res = _resolve_landing(g, ai_player, tile_ref, {})
  assert(res and res.waiting, "should wait for choice")

  local pending = g.turn.pending_choice
  assert(pending and pending.kind == "landing_optional_effect", "should have landing choice")

  local action = agent.auto_action_for_choice(g, pending)
  assert(action, "AI should return an action")
  assert(action.type == "choice_select", "AI should select land purchase")
  assert(action.option_id == "buy_land", "AI should pick buy_land")

  local before_cash = ai_player.cash
  choice_resolver.resolve(g, pending, action)
  assert(ai_player.cash == before_cash - tile_ref.price, "AI cash should decrease by land price")
  assert(_tile_state(g, tile_ref).owner_id == ai_player.id, "land should be purchased")
end

local function _test_land_rent_contiguous_sum()
  local g = _new_game()
  local owner = g.players[1]
  local tenant = g.players[2]

  local idx1, tile1, _, tile2 = _first_adjacent_land_pair(g.board)
  g:set_tile_owner(tile1, owner.id)
  g:set_tile_owner(tile2, owner.id)
  g:set_tile_level(tile1, 1)
  g:set_tile_level(tile2, 2)
  g:set_player_property(owner, tile1.id, true)
  g:set_player_property(owner, tile2.id, true)

  g:update_player_position(tenant, idx1)
  local before = tenant.cash
  land_actions.execute_pay_rent(g, tenant.id, tile1.id)
  local expected = pricing.rent_for_level(tile1, 1) + pricing.rent_for_level(tile2, 2)
  _assert_eq(before - tenant.cash, expected, "contiguous rent sum")

  g:set_tile_level(tile1, 2)
  local before2 = tenant.cash
  land_actions.execute_pay_rent(g, tenant.id, tile1.id)
  local expected2 = pricing.rent_for_level(tile1, 2) + pricing.rent_for_level(tile2, 2)
  _assert_eq(before2 - tenant.cash, expected2, "contiguous rent sum after upgrade")
end

local function _test_land_rent_graph_adjacency_breaks_path_neighbors()
  local g = _new_game()
  local owner = g.players[1]
  local tenant = g.players[2]
  local idx_a = g.board:index_of_tile_id(27)
  local idx_b = g.board:index_of_tile_id(28)
  assert(idx_a and idx_b, "expected tile ids 27/28")
  local tile_a = g.board:get_tile(idx_a)
  local tile_b = g.board:get_tile(idx_b)
  assert(tile_a and tile_b, "expected land tiles")

  g:set_tile_owner(tile_a, owner.id)
  g:set_tile_owner(tile_b, owner.id)
  g:set_tile_level(tile_a, 1)
  g:set_tile_level(tile_b, 2)
  g:set_player_property(owner, tile_a.id, true)
  g:set_player_property(owner, tile_b.id, true)

  g:update_player_position(tenant, idx_a)
  local before = tenant.cash
  land_actions.execute_pay_rent(g, tenant.id, tile_a.id)
  local expected = pricing.rent_for_level(tile_a, 1)
  _assert_eq(before - tenant.cash, expected, "graph adjacency rent excludes non-neighbors")
end

local function _test_rent_owner_missing_skips_payment()
  local land = require("src.game.systems.land.Land")
  local g = _new_game()
  local tenant = g.players[1]
  local owner = g.players[2]
  local idx, tile_ref = _first_land_tile(g.board)

  g:set_tile_owner(tile_ref, owner.id)
  g:set_tile_level(tile_ref, 1)
  g:set_player_property(owner, tile_ref.id, true)
  g:update_player_position(tenant, idx)

  g:set_player_status(tenant, "pending_free_rent", true)
  g:player_send_to_mountain(owner)
  local before = tenant.cash
  land.executors.pay_rent.apply({ game = g, player = tenant, tile = tile_ref })
  _assert_eq(tenant.cash, before, "rent skipped when owner in mountain")
  assert(tenant.status.pending_free_rent == true, "pending_free_rent should remain when owner missing")

  g:set_player_status(tenant, "pending_free_rent", false)
  owner.eliminated = true
  local before2 = tenant.cash
  local ok = land_actions.execute_pay_rent(g, tenant.id, tile_ref.id)
  _assert_eq(ok, false, "execute_pay_rent should return false when owner missing")
  _assert_eq(tenant.cash, before2, "rent skipped when owner missing")
end

return {
  _test_ai_picks_land_purchase,
  _test_land_rent_contiguous_sum,
  _test_land_rent_graph_adjacency_breaks_path_neighbors,
  _test_rent_owner_missing_skips_payment,
}
