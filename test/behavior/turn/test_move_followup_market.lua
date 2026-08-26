local lu = require("luaunit")
local luax = require("test.support.luax")
local support = require("test.support.shared_support")
local _assert_eq = support.assert_eq
local move_followup = require("src.turn.phases.move_followup")
local control = require("src.player.control")

local function _stub(modname, replacement)
  local module = require(modname)
  local saved = {}
  for k, v in pairs(replacement) do
    saved[k] = module[k]
    module[k] = v
  end
  return function()
    for k, v in pairs(saved) do
      module[k] = v
    end
  end
end

TestMoveFollowupMarket = {}

local function _make_interrupt()
  return {
    remaining_steps = 2,
    facing = "right",
    branch_parity = 1,
    entered_inner = false,
  }
end

function TestMoveFollowupMarket:test_human_player_with_choice_returns_wait_choice()
  local game = support.new_game()
  game.last_turn = game.last_turn or {}
  local player = game.players[1]
  local interrupt = _make_interrupt()
  local dispatched = {}

  local restore_market = _stub("src.rules.market", {
    choice = {
      build = function()
        return { kind = "market_choice" }, nil
      end,
    },
  })
  local restore_dispatch = _stub("src.turn.output.intent_dispatcher", {
    dispatch = function(_, payload) dispatched[#dispatched + 1] = payload end,
  })

  local state, args = move_followup.run({ game = game }, {
    mode = "resume_turn_move",
    player = player,
    raw_total = 4,
    move_result = { market_interrupt = interrupt },
  })

  restore_market()
  restore_dispatch()

  _assert_eq(state, "wait_choice", "human player with choice should return wait_choice")
  _assert_eq(args.next_state, "move", "wait_choice should chain back to move")
  _assert_eq(#dispatched, 1, "should dispatch need_choice intent")
  _assert_eq(dispatched[1].kind, "need_choice", "dispatched intent kind should be need_choice")
  _assert_eq(args.next_args.continue_from_market, true, "choice wait should resume from market")
  _assert_eq(args.next_args.remaining_steps, 2, "choice wait should preserve remaining steps")
end

function TestMoveFollowupMarket:test_human_player_with_intent_only_falls_through_to_landing()
  local game = support.new_game()
  game.last_turn = game.last_turn or {}
  local player = game.players[1]
  local interrupt = _make_interrupt()
  local dispatched = {}

  local restore_market = _stub("src.rules.market", {
    choice = {
      build = function()
        return nil, { kind = "auto_purchase" }
      end,
    },
  })
  local restore_dispatch = _stub("src.turn.output.intent_dispatcher", {
    dispatch = function(_, payload) dispatched[#dispatched + 1] = payload end,
  })

  local state = move_followup.run({ game = game }, {
    mode = "resume_turn_move",
    player = player,
    raw_total = 4,
    move_result = { market_interrupt = interrupt },
  })

  restore_market()
  restore_dispatch()

  _assert_eq(state, "landing", "human player with intent only should fall through to landing")
  _assert_eq(#dispatched, 1, "should dispatch the intent")
  _assert_eq(dispatched[1].kind, "auto_purchase", "dispatched intent kind should match")
end

function TestMoveFollowupMarket:test_auto_player_with_remaining_steps_resumes_move()
  local game = support.new_game()
  game.last_turn = game.last_turn or {}
  local player = game.players[1]
  control.toggle_manual_delegation(player)
  local interrupt = _make_interrupt()
  local executed = 0

  local restore_market = _stub("src.rules.market", {
    auto = {
      execute = function(_, auto_player)
        executed = executed + 1
        _assert_eq(auto_player, player, "auto market should receive the moving player")
      end,
    },
  })

  local state, args = move_followup.run({ game = game }, {
    mode = "resume_turn_move",
    player = player,
    raw_total = 4,
    move_result = { market_interrupt = interrupt },
  })

  restore_market()

  _assert_eq(executed, 1, "auto market should execute once")
  _assert_eq(state, "move", "auto market with remaining steps should resume movement")
  _assert_eq(args.continue_from_market, true, "auto market resume should set continue flag")
  _assert_eq(args.remaining_steps, 2, "auto market resume should preserve remaining steps")
end

function TestMoveFollowupMarket:test_auto_player_with_one_remaining_step_still_resumes_move()
  local game = support.new_game()
  game.last_turn = game.last_turn or {}
  local player = game.players[1]
  control.toggle_manual_delegation(player)
  local interrupt = _make_interrupt()
  interrupt.remaining_steps = 1

  local restore_market = _stub("src.rules.market", {
    auto = { execute = function() end },
  })

  local state, args = move_followup.run({ game = game }, {
    mode = "resume_turn_move",
    player = player,
    raw_total = 4,
    move_result = { market_interrupt = interrupt },
  })

  restore_market()

  _assert_eq(state, "move", "one remaining step should still resume movement")
  _assert_eq(args.remaining_steps, 1, "remaining step count should be preserved")
end

function TestMoveFollowupMarket:test_auto_player_without_remaining_steps_falls_through_to_landing()
  local game = support.new_game()
  game.last_turn = game.last_turn or {}
  local player = game.players[1]
  control.toggle_manual_delegation(player)
  local interrupt = _make_interrupt()
  interrupt.remaining_steps = nil

  local restore_market = _stub("src.rules.market", {
    auto = { execute = function() end },
  })

  local state, args = move_followup.run({ game = game }, {
    mode = "resume_turn_move",
    player = player,
    raw_total = 4,
    move_result = { market_interrupt = interrupt },
  })

  restore_market()

  _assert_eq(state, "landing", "auto market without remaining steps should land")
  _assert_eq(args.player, player, "landing should keep resolved player")
end

function TestMoveFollowupMarket:test_auto_player_with_zero_remaining_steps_falls_through_to_landing()
  local game = support.new_game()
  game.last_turn = game.last_turn or {}
  local player = game.players[1]
  control.toggle_manual_delegation(player)
  local interrupt = _make_interrupt()
  interrupt.remaining_steps = 0

  local restore_market = _stub("src.rules.market", {
    auto = { execute = function() end },
  })

  local state = move_followup.run({ game = game }, {
    mode = "resume_turn_move",
    player = player,
    raw_total = 4,
    move_result = { market_interrupt = interrupt },
  })

  restore_market()

  _assert_eq(state, "landing", "zero remaining steps should not resume movement")
end

function TestMoveFollowupMarket:test_clears_pending_followup_flag_and_marks_turn_dirty()
  local game = support.new_game()
  game.last_turn = game.last_turn or {}
  game.turn.move_followup_pending = true
  game.dirty.turn = false
  game.dirty.any = false
  local player = game.players[1]
  local restore_hold = _stub("src.state.visual_hold", {
    start = function() end,
  })

  local state = move_followup.run({ game = game }, {
    mode = "resolve_landing",
    player = player,
    move_result = {},
  })

  restore_hold()

  _assert_eq(state, "landing", "resolve_landing should still land")
  _assert_eq(game.turn.move_followup_pending, false, "pending followup flag should be cleared")
  _assert_eq(game.dirty.turn, true, "clearing pending followup should mark turn dirty")
  _assert_eq(game.dirty.any, true, "clearing pending followup should mark any dirty")
end

function TestMoveFollowupMarket:test_leaves_non_pending_followup_flag_and_dirty_state_unchanged()
  local game = support.new_game()
  game.last_turn = game.last_turn or {}
  game.turn.move_followup_pending = false
  game.dirty.turn = false
  game.dirty.any = false
  local player = game.players[1]
  local restore_hold = _stub("src.state.visual_hold", {
    start = function() end,
  })

  move_followup.run({ game = game }, {
    mode = "resolve_landing",
    player = player,
    move_result = {},
  })

  restore_hold()

  _assert_eq(game.turn.move_followup_pending, false, "non-pending flag should stay false")
  _assert_eq(game.dirty.turn, false, "non-pending flag should not mark turn dirty")
  _assert_eq(game.dirty.any, false, "non-pending flag should not mark any dirty")
end

function TestMoveFollowupMarket:test_resolve_landing_supports_player_id_lookup()
  local game = support.new_game()
  game.last_turn = game.last_turn or {}
  local player = game.players[1]
  local move_result = {}

  local state, args = move_followup.run({ game = game }, {
    mode = "resolve_landing",
    player_id = player.id,
    move_result = move_result,
  })

  _assert_eq(state, "landing", "resolve_landing should return landing")
  _assert_eq(args.player, player, "resolve_landing should resolve player_id")
  _assert_eq(args.move_result, move_result, "resolve_landing should preserve move_result")
end

function TestMoveFollowupMarket:test_missing_player_id_lookup_fails_before_landing()
  local game = support.new_game()
  game.last_turn = game.last_turn or {}

  local ok, err = pcall(function()
    move_followup.run({ game = game }, {
      mode = "resolve_landing",
      player_id = 99999,
      move_result = {},
    })
  end)

  _assert_eq(ok, false, "missing player_id should fail")
  lu.assertEvalToTrue(tostring(err):find("missing move followup player", 1, true), tostring(err))
end

function TestMoveFollowupMarket:test_missing_turn_table_keeps_clear_pending_as_noop()
  local ok, err = pcall(function()
    move_followup.run({ game = {} }, {
      mode = "unknown",
    })
  end)

  _assert_eq(ok, false, "unknown mode should still fail")
  lu.assertEvalToTrue(tostring(err):find("unknown move followup mode", 1, true), tostring(err))
end

function TestMoveFollowupMarket:test_resolve_landing_without_player_id_raises_missing_move_followup_player_id()
  -- kills _resolve_player's "missing move followup player_id" -> nil.
  luax.has_error(function()
    move_followup.run({ game = {} }, { mode = "resolve_landing" })
  end, "missing move followup player_id")
end

function TestMoveFollowupMarket:test_apply_location_effects_publishes_each_log_entry_with_tip_true()
  -- kills _handle_apply_location_effects' `tip = true` -> false.
  local published = {}
  local restore = _stub("src.rules.ports.event_feed", {
    publish = function(_, payload) published[#published + 1] = payload end,
  })
  local ok, err = pcall(function()
    move_followup.run({ game = {} }, {
      mode = "apply_location_effects",
      log_entries = { "结算A", "结算B" },
      effects = {},
      next_state = "end_turn",
      next_args = { t = 1 },
    })
  end)
  restore()
  lu.assertEvalToTrue(ok, tostring(err))
  _assert_eq(#published, 2, "each log entry publishes exactly once")
  _assert_eq(published[1].tip, true, "followup log entries publish as tips")
  _assert_eq(published[2].tip, true, "every followup log entry is a tip")
  _assert_eq(published[1].text, "结算A", "the log entry text flows through")
end


return TestMoveFollowupMarket
