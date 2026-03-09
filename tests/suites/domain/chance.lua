local support = require("support.domain_support")
local default_map = require("Config.maps.default_map")
local facing_policy = require("src.game.systems.board.facing_policy")
local function _new_game()
  return support.new_game({ map = default_map })
end
local _resolve_landing = support.resolve_landing
local _visited_tile_ids = support.visited_tile_ids
local _list_contains = support.list_contains
local _first_tile_by_type = support.first_tile_by_type
local _with_patches = support.with_patches
local _assert_eq = support.assert_eq
local chance_effects = support.chance_effects
local _build_ui_port = support.build_ui_port

local function _test_chance_is_mandatory_effect_entrypoint()
  local g = _new_game()
  local p = g:current_player()
  local idx, tile_ref = _first_tile_by_type(g.board, "chance")
  g:update_player_position(p, idx)

  local called = { rand = 0 }
  local prev_lua_api = LuaAPI
  local lua_api = prev_lua_api or {}
  local function rand()
    called.rand = called.rand + 1
    return 0
  end
  _with_patches({
    { key = "LuaAPI", value = lua_api },
    { target = lua_api, key = "rand", value = rand },
  }, function()
    _resolve_landing(g, p, tile_ref, {})
  end)

  assert(called.rand > 0, "chance logic was executed (LuaAPI.rand used)")
end

local function _test_chance_move_backward_pass_market()
  local g = _new_game()
  local p = g:current_player()
  g:update_player_position(p, g.board:index_of_tile_id(32))
  g:set_player_status(p, "move_dir", "down")
  local out = chance_effects.resolve(g, p, { effect = "move_backward", steps = 2, target = "self" }, {})
  assert(out and out.move_result, "move_backward should return move result")
  local visited_ids = _visited_tile_ids(g.board, out.move_result.visited)
  assert(_list_contains(visited_ids, 39), "backward move should pass market")
  assert(out.move_result.market_interrupt == nil, "backward move should not trigger market interrupt")
  _assert_eq(p.status.move_dir, "down", "move_backward should preserve recorded forward heading")
end

local function _test_chance_move_backward_pass_intersection()
  local g = _new_game()
  local p = g:current_player()
  g:update_player_position(p, g.board:index_of_tile_id(42))
  g:set_player_status(p, "move_dir", "down")
  local out = chance_effects.resolve(g, p, { effect = "move_backward", steps = 2, target = "self" }, {})
  assert(out and out.move_result, "move_backward should return move result")
  local visited_ids = _visited_tile_ids(g.board, out.move_result.visited)
  assert(_list_contains(visited_ids, 45), "backward move should pass intersection")
  _assert_eq(p.status.move_dir, "down", "move_backward should preserve heading across intersections")
end

local function _test_chance_move_backward_queues_move_effect_anim()
  local g = _new_game()
  g.anim_gate_port = { wait_action_anim = true, wait_move_anim = false }
  local p = g:current_player()
  g:update_player_position(p, g.board:index_of_tile_id(32))
  g:set_player_status(p, "move_dir", "down")
  local out = chance_effects.resolve(g, p, { effect = "move_backward", steps = 2, target = "self" }, {})
  assert(out and out.move_result, "move_backward should return move result")
  assert(g.turn.action_anim and g.turn.action_anim.kind == "move_effect", "move_backward should queue move_effect anim")
  _assert_eq(g.turn.action_anim.to_index, p.position, "move_effect to_index should match player position")
end

local function _test_chance_move_backward_without_move_dir_uses_stable_fallback()
  local g = _new_game()
  local p = g:current_player()
  g:update_player_position(p, g.board:index_of_tile_id(42))
  g:set_player_status(p, "move_dir", nil)
  local out = chance_effects.resolve(g, p, { effect = "move_backward", steps = 1, target = "self" }, {})
  assert(out and out.move_result, "move_backward without move_dir should still return move result")
  local visited_ids = _visited_tile_ids(g.board, out.move_result.visited)
  _assert_eq(#visited_ids, 1, "move_backward fallback should record one visited tile")
  _assert_eq(visited_ids[1], 3, "move_backward without move_dir should stably fallback to outer_prev")
  _assert_eq(p.status.move_dir, nil, "move_backward fallback should not record a backward heading")
end

local function _test_chance_forced_move_queues_move_effect_anim()
  local g = _new_game()
  g.anim_gate_port = { wait_action_anim = true, wait_move_anim = false }
  local p = g:current_player()
  local dest = 38
  local out = chance_effects.resolve(g, p, {
    effect = "forced_move",
    destination_tile_id = dest,
    target = "self",
  }, {})
  local idx = g.board:index_of_tile_id(dest)
  assert(out and out.kind == "need_landing", "forced_move destination tile should return need_landing")
  _assert_eq(out.board_index, idx, "forced_move board_index should match destination")
  assert(g.turn.action_anim and g.turn.action_anim.kind == "move_effect", "forced_move should queue move_effect anim")
  _assert_eq(g.turn.action_anim.to_index, idx, "forced_move anim to_index should match destination")
  assert(p.status.move_dir == nil, "forced_move should clear stale move_dir")
end

local function _test_chance_forced_move_to_market_sets_default_forward_heading()
  local g = _new_game()
  local p = g:current_player()
  g:set_player_status(p, "move_dir", "left")
  local market_idx = assert(g.board:find_first_by_type("market"), "missing market tile")
  local expected = facing_policy.resolve_forced_move_reset_facing(g.board, market_idx)

  local out = chance_effects.resolve(g, p, {
    effect = "forced_move",
    destination = "market",
    target = "self",
  }, {})

  assert(out and out.kind == "need_landing", "forced_move market should return need_landing")
  _assert_eq(out.board_index, market_idx, "forced_move market should land on market tile")
  _assert_eq(p.status.move_dir, expected, "forced_move market should set default forward heading")
end

return {
  name = "chance",
  tests = {
    { name = "chance_is_mandatory_effect_entrypoint", run = _test_chance_is_mandatory_effect_entrypoint },
    { name = "chance_move_backward_pass_market", run = _test_chance_move_backward_pass_market },
    { name = "chance_move_backward_pass_intersection", run = _test_chance_move_backward_pass_intersection },
    { name = "chance_move_backward_queues_move_effect_anim", run = _test_chance_move_backward_queues_move_effect_anim },
    { name = "chance_move_backward_without_move_dir_uses_stable_fallback", run = _test_chance_move_backward_without_move_dir_uses_stable_fallback },
    { name = "chance_forced_move_queues_move_effect_anim", run = _test_chance_forced_move_queues_move_effect_anim },
    {
      name = "chance_forced_move_to_market_sets_default_forward_heading",
      run = _test_chance_forced_move_to_market_sets_default_forward_heading,
    },
  },
}
