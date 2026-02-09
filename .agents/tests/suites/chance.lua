local support = require("TestSupport")
local _new_game = support.new_game
local _resolve_landing = support.resolve_landing
local _visited_tile_ids = support.visited_tile_ids
local _list_contains = support.list_contains
local _first_tile_by_type = support.first_tile_by_type
local _with_patches = support.with_patches
local chance_effects = support.chance_effects

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
end

return {
  _test_chance_is_mandatory_effect_entrypoint,
  _test_chance_move_backward_pass_market,
  _test_chance_move_backward_pass_intersection,
}
