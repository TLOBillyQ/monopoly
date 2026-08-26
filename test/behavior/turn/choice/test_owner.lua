local lu = require("luaunit")

local support = require("test.support.shared_support")
local _assert_eq = support.assert_eq

local owner = require("src.turn.choice.owner")

-- 三个 describe 均无钩子,合并进 TestOwner;用例数与改写前一一对应(2+2+3 = 7 例)。
TestOwner = {}

function TestOwner:test_resolves_via_find_player_by_id_not_the_current_player_fallback()
  local game = {
    find_player_by_id = function(_, id) return { id = 700 + id } end,
    turn = { current_player_index = 1 },
    players = { { id = 11 } },
  }
  _assert_eq(owner.resolve_role_id(game, { owner_role_id = 7 }), 707,
    "a resolvable owner resolves through find_player_by_id")
end

function TestOwner:test_falls_back_to_the_current_player_id_when_find_is_absent()
  local game = {
    find_player_by_id = nil,
    turn = { current_player_index = 1 },
    players = { { id = 11 } },
  }
  _assert_eq(owner.resolve_role_id(game, { owner_role_id = 7 }), 11,
    "a missing find_player_by_id short-circuits to the current-player fallback")
end

function TestOwner:test_returns_the_found_player_object()
  local found = { id = 42 }
  local game = { find_player_by_id = function() return found end }
  lu.assertEvalToTrue(owner.resolve_player(game, { owner_role_id = 42 }) == found,
    "resolve_player returns the player object, not its id")
end

function TestOwner:test_falls_back_to_game_current_player_via_method_call()
  local cur = { id = 9 }
  local game = { current_player = function() return cur end }
  lu.assertEvalToTrue(owner.resolve_player(game, {}) == cur,
    "no owner resolves through the current_player() method fallback")
end

function TestOwner:test_returns_a_nil_action_untouched_without_resolving()
  lu.assertEvalToTrue(owner.ensure_actor_role_id({}, {}, nil) == nil, "a nil action is returned as-is")
end

function TestOwner:test_does_not_overwrite_an_already_set_actor()
  local action = { actor_role_id = 3 }
  owner.ensure_actor_role_id({ find_player_by_id = function() return { id = 99 } end }, { owner_role_id = 1 }, action)
  _assert_eq(action.actor_role_id, 3, "a present actor_role_id is preserved")
end

function TestOwner:test_fills_actor_from_the_resolved_owner_id_when_absent()
  local action = {}
  local game = { find_player_by_id = function(_, id) return { id = id } end }
  owner.ensure_actor_role_id(game, { owner_role_id = 5 }, action)
  _assert_eq(action.actor_role_id, 5, "an absent actor is filled from resolve_role_id")
end


return TestOwner
