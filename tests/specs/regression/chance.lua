local support = require("support.regression_support")
local _new_game = support.new_game
local _resolve_landing = support.resolve_landing
local _visited_tile_ids = support.visited_tile_ids
local _list_contains = support.list_contains
local _first_tile_by_type = support.first_tile_by_type
local _with_patches = support.with_patches
local _assert_eq = support.assert_eq
local chance_effects = support.chance_effects
local _build_ui_port = support.build_ui_port
local gameplay_rules = require("cfg.GameplayRules")

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

local function _test_chance_move_backward_queues_move_effect_anim()
  local g = _new_game()
  g.ui_port = _build_ui_port({ wait_action_anim = true })
  local p = g:current_player()
  g:update_player_position(p, g.board:index_of_tile_id(32))
  g:set_player_status(p, "move_dir", "down")
  local out = chance_effects.resolve(g, p, { effect = "move_backward", steps = 2, target = "self" }, {})
  assert(out and out.move_result, "move_backward should return move result")
  assert(g.turn.action_anim and g.turn.action_anim.kind == "move_effect", "move_backward should queue move_effect anim")
  _assert_eq(g.turn.action_anim.to_index, p.position, "move_effect to_index should match player position")
end

local function _test_chance_forced_move_queues_move_effect_anim()
  local g = _new_game()
  g.ui_port = _build_ui_port({ wait_action_anim = true })
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
end

local function _test_chance_set_vehicle_ignored_when_feature_disabled()
  local g = _new_game()
  local p = g:current_player()
  p.seat_id = nil

  chance_effects.resolve(g, p, {
    effect = "set_vehicle",
    target = "self",
    negative = false,
    vehicle_id = 4001,
  }, {})

  assert(p.seat_id == nil, "set_vehicle should be ignored when feature disabled")
end

local function _test_chance_set_vehicle_works_when_feature_enabled()
  local g = _new_game()
  local p = g:current_player()

  _with_patches({
    { target = gameplay_rules, key = "vehicle_enabled", value = true },
  }, function()
    chance_effects.resolve(g, p, {
      effect = "set_vehicle",
      target = "self",
      negative = false,
      vehicle_id = 4001,
    }, {})
  end)

  assert(p.seat_id == 4001, "set_vehicle should take effect when feature enabled")
end

local _tests = {
  _test_chance_is_mandatory_effect_entrypoint,
  _test_chance_move_backward_pass_market,
  _test_chance_move_backward_pass_intersection,
  _test_chance_move_backward_queues_move_effect_anim,
  _test_chance_forced_move_queues_move_effect_anim,
  _test_chance_set_vehicle_ignored_when_feature_disabled,
  _test_chance_set_vehicle_works_when_feature_enabled,
}

local _cases = {}
for index, run in ipairs(_tests) do
  _cases[#_cases + 1] = {
    id = "chance.case_" .. tostring(index),
    desc = "chance migrated case " .. tostring(index),
    run = run,
  }
end

return {
  layer = "regression",
  domain = "chance",
  cases = _cases,
}
