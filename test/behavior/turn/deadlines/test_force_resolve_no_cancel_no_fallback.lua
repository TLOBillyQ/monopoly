-- 验证：choice 无 allow_cancel + 无 auto_action + 无注册 fallback → force_skip 必然推进
local lu = require("luaunit")
local force_resolve = require("src.turn.deadlines")
local pending_confirmation = require("src.state.pending_confirmation")
local fallback_registry = require("src.rules.choice.fallback_registry")
local runtime_state = require("src.state.runtime")

local function _build_state()
  local state = {}
  runtime_state.ensure_all(state)
  return state
end

local function _make_auto_play_port()
  return {
    is_auto_player = function(_, _p) return false end,
    auto_action_for_choice = function(_, _c) return nil end,
    pick_target_player = function() return nil end,
    pick_remote_dice_value = function() return nil end,
    pick_roadblock_target = function() return nil end,
  }
end

local function _build_game()
  local advanced = { count = 0 }
  local game = {
    finished = false,
    players = { { id = 1, auto = false } },
    turn = {
      current_player_index = 1,
      pending_choice = nil,
    },
    dirty = { any = false, turn = false },
    auto_play_port = _make_auto_play_port(),
  }
  function game:advance_turn()
    advanced.count = advanced.count + 1
  end
  function game:current_player()
    return self.players[1]
  end
  function game:find_player_by_id(id)
    for _, p in ipairs(self.players) do
      if p.id == id then return p end
    end
    return nil
  end
  return game, advanced
end

TestForceResolveNoCancelNoFallback = {}

function TestForceResolveNoCancelNoFallback:setUp()
  fallback_registry.reset()
end

function TestForceResolveNoCancelNoFallback:test_force_skip_clears_pending_choice_and_sets_force_skip_flag()
  local state = _build_state()
  local game = _build_game()
  local choice = { id = "c2", kind = "weird", options = {} }
  game.turn.pending_choice = choice

  force_resolve.force_skip(game, state, choice, "test")

  lu.assertNil(game.turn.pending_choice)
  lu.assertTrue(state._choice_force_skip_pending == true)
end

function TestForceResolveNoCancelNoFallback:test_force_skip_clears_ui_state_output_port_and_all_choice_deadlines()
  local state = _build_state()
  local game, advanced = _build_game()
  local clear_calls = 0
  local choice = { id = "c3", kind = "market_buy", options = {} }
  pending_confirmation.enter(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK)
  state._resolved_gameplay_loop_ports = {
    output = {
      clear_pending_choice = function(state_arg)
        clear_calls = clear_calls + 1
        lu.assertEquals(state_arg, state)
      end,
    },
  }
  game.turn.pending_choice = choice

  force_resolve.start(state, "choice", { timeout_seconds = 10 })
  force_resolve.start(state, "market_buy", { timeout_seconds = 10 })
  force_resolve.start(state, "target_select", { timeout_seconds = 10 })
  force_resolve.start(state, "modal_popup", { timeout_seconds = 10 })

  force_resolve.force_skip(game, state, choice, "test")

  lu.assertEquals(clear_calls, 1)
  lu.assertFalse(pending_confirmation.is_active(state))
  lu.assertTrue(game.turn._choice_force_skip_pending == true)
  lu.assertNil(game.turn.pending_choice)
  lu.assertFalse(force_resolve.is_active(state, "choice"))
  lu.assertFalse(force_resolve.is_active(state, "market_buy"))
  lu.assertFalse(force_resolve.is_active(state, "target_select"))
  lu.assertFalse(force_resolve.is_active(state, "modal_popup"))
  lu.assertEquals(advanced.count, 1)
end

function TestForceResolveNoCancelNoFallback:test_force_skip_ignores_malformed_output_port_and_nil_state_safely()
  local state = _build_state()
  local game = _build_game()
  state._resolved_gameplay_loop_ports = {
    output = {
      clear_pending_choice = "not a function",
    },
  }
  game.turn.pending_choice = { id = "c4", kind = "weird", options = {} }

  local ok, err = pcall(force_resolve.force_skip, game, state, game.turn.pending_choice, "test")
  lu.assertTrue(ok, tostring(err))
  lu.assertNil(game.turn.pending_choice)

  ok, err = pcall(force_resolve.force_skip, { finished = true, turn = {} }, nil, nil, "test")
  lu.assertTrue(ok, tostring(err))
end

function TestForceResolveNoCancelNoFallback:test_force_skip_tolerates_nil_game_and_missing_output_ports()
  local state = _build_state()
  pending_confirmation.enter(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK)

  local ok, err = pcall(force_resolve.force_skip, nil, state, { id = "c6", kind = "weird" }, "test")

  lu.assertTrue(ok, tostring(err))
  lu.assertFalse(pending_confirmation.is_active(state))
end

function TestForceResolveNoCancelNoFallback:test_force_skip_does_not_advance_a_finished_game()
  local state = _build_state()
  local game, advanced = _build_game()
  game.finished = true

  force_resolve.force_skip(game, state, { id = "c5", kind = "weird", options = {} }, "test")

  lu.assertEquals(advanced.count, 0)
end


return TestForceResolveNoCancelNoFallback
