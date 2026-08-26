-- Mutation-closure pins for src/turn/waits/choice_dispatch.lua.
-- Drives the three exported helpers directly with plain game/opts/output tables
-- so the owner-resolution guards, the ensure-actor short-circuit, and the
-- tick-dispatch return contract are observable.
local lu = require("luaunit")
local support = require("test.support.shared_support")
local _assert_eq = support.assert_eq

local choice_dispatch = require("src.turn.waits.choice_dispatch")

TestWaitsChoiceDispatch = {}

function TestWaitsChoiceDispatch:test_returns_the_found_player_id_when_the_choice_owner_resolves()
  -- kills L6 resolve_owner_role_id->nil, L7 ~=/==, L8 find_player_by_id->nil:
  -- the owner branch must win over the current-player fallback.
  local game = {
    find_player_by_id = function(_, id) return { id = 700 + id } end,
    turn = { current_player_index = 1 },
    players = { { id = 11 } },
  }
  local choice = { id = 1, owner_role_id = 7 }
  _assert_eq(choice_dispatch.resolve_choice_owner_id(game, choice), 707,
    "a resolvable owner resolves via find_player_by_id, not the current-player fallback")
end

function TestWaitsChoiceDispatch:test_falls_back_to_the_current_player_when_find_player_by_id_is_absent()
  -- kills L7 and->or: with an owner id but no find_player_by_id function the
  -- guard must stay false; an `or` mutant would enter and call a nil method.
  local game = {
    find_player_by_id = nil,
    turn = { current_player_index = 1 },
    players = { { id = 11 } },
  }
  local choice = { owner_role_id = 7 }
  _assert_eq(choice_dispatch.resolve_choice_owner_id(game, choice), 11,
    "a missing find_player_by_id short-circuits to the current-player fallback")
end

function TestWaitsChoiceDispatch:test_returns_a_nil_action_untouched_without_resolving_an_owner()
  -- kills L19 or->and: a nil action must short-circuit and return; an `and`
  -- mutant would evaluate action.actor_role_id on nil and error.
  local result = choice_dispatch.ensure_action_actor_role_id({}, {}, nil)
  lu.assertEvalToTrue(result == nil, "a nil action is returned as-is")
end

function TestWaitsChoiceDispatch:test_dispatches_the_built_action_and_returns_true()
  -- kills L30 build_action->nil and L37 true->false.
  local dispatched = {}
  local elapsed_writes = {}
  local output_ports = {
    set_pending_choice_elapsed = function(_, value) elapsed_writes[#elapsed_writes + 1] = value end,
  }
  local opts = {
    build_action = function() return { type = "x", actor_role_id = 1 } end,
    dispatch_action_with_close_choice = function(_, _, action) dispatched[#dispatched + 1] = action end,
  }
  local ret = choice_dispatch.dispatch_choice_tick_action({}, {}, { id = 1 }, output_ports, opts, {})
  lu.assertEvalToTrue(ret == true, "a successful dispatch returns true")
  _assert_eq(#dispatched, 1, "the built action is forwarded to dispatch_action_with_close_choice")
  _assert_eq(elapsed_writes[1], 0, "the pending-choice elapsed is reset to 0 on dispatch")
end


return TestWaitsChoiceDispatch
