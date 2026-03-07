local support = require("TestSupport")
local default_map = require("Config.maps.default_map")
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
local test_profile_bootstrap = require("src.app.testing.test_profile_bootstrap")

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

local function _test_chance_backward_intersection_profile_reproduces_chain()
  local g = support.new_game({
    map = default_map,
    players = { "P1", "P2", "P3", "P4" },
    ai = { [2] = true, [3] = true, [4] = true },
  })
  local p = g:current_player()
  test_profile_bootstrap.apply(g, "机会卡倒退交叉口测试")

  local out = chance_effects.resolve(g, p, { effect = "move_backward", steps = 2, target = "self" }, {})
  assert(out and out.move_result, "profile-driven move_backward should return move result")
  local visited_ids = _visited_tile_ids(g.board, out.move_result.visited)
  assert(_list_contains(visited_ids, 45), "profile-driven move_backward should pass intersection")
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
  _assert_eq(p.status.move_dir, "left", "move_backward fallback should persist the next backward heading")
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

return {
  name = "chance",
  tests = {
    { name = "chance_is_mandatory_effect_entrypoint", run = _test_chance_is_mandatory_effect_entrypoint },
    { name = "chance_move_backward_pass_market", run = _test_chance_move_backward_pass_market },
    { name = "chance_move_backward_pass_intersection", run = _test_chance_move_backward_pass_intersection },
    { name = "chance_backward_intersection_profile_reproduces_chain", run = _test_chance_backward_intersection_profile_reproduces_chain },
    { name = "chance_move_backward_queues_move_effect_anim", run = _test_chance_move_backward_queues_move_effect_anim },
    { name = "chance_move_backward_without_move_dir_uses_stable_fallback", run = _test_chance_move_backward_without_move_dir_uses_stable_fallback },
    { name = "chance_forced_move_queues_move_effect_anim", run = _test_chance_forced_move_queues_move_effect_anim },
  },
}
