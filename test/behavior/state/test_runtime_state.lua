local lu = require("luaunit")
local runtime_state = require("src.state.runtime")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local _config_reset = require("test.support.config_reset")

TestRuntimeState = {}

function TestRuntimeState:setUp()
  _config_reset.reset_all()
end

function TestRuntimeState:test_set_pending_choice_with_opts_choice_id_overrides_choice_id()
  local state = {}
  local choice = { id = 10, kind = "market_buy" }
  runtime_state.set_pending_choice(state, choice, { choice_id = 99, elapsed_seconds = 1.5 })
  _assert_eq(runtime_state.get_pending_choice(state), choice, "set_pending_choice should store choice")
  _assert_eq(runtime_state.get_pending_choice_id(state), 99, "explicit opts.choice_id should override choice.id")
  _assert_eq(runtime_state.get_pending_choice_elapsed(state), 1.5, "elapsed_seconds from opts should be stored")
end

function TestRuntimeState:test_set_pending_choice_nil_choice_id_uses_choice_id()
  local state = {}
  local choice = { id = 42, kind = "item_phase_passive" }
  runtime_state.set_pending_choice(state, choice)
  _assert_eq(runtime_state.get_pending_choice_id(state), 42, "nil opts.choice_id should fall back to choice.id")
  _assert_eq(runtime_state.get_pending_choice_elapsed(state), 0, "nil elapsed_seconds should default to 0")
end

function TestRuntimeState:test_set_pending_choice_nil_choice_resets_id()
  local state = {}
  runtime_state.set_pending_choice(state, nil)
  _assert_eq(runtime_state.get_pending_choice(state), nil, "nil choice should store nil")
  _assert_eq(runtime_state.get_pending_choice_id(state), nil, "nil choice should leave id nil")
end

function TestRuntimeState:test_ensure_board_runtime_initializes_fields()
  local state = {}
  local board_runtime = runtime_state.ensure_board_runtime(state)
  lu.assertEvalToTrue(type(board_runtime) == "table", "ensure_board_runtime should return a table")
  lu.assertEvalToTrue(type(board_runtime.board_last_positions) == "table", "board_last_positions should be initialized")
  lu.assertEvalToTrue(type(board_runtime.follow_targets) == "table", "follow_targets should be initialized")
  _assert_eq(board_runtime.board_sync_pending, false, "board_sync_pending should default to false")
end

function TestRuntimeState:test_ensure_board_runtime_inherits_state_fields()
  local state = {
    board_last_positions = { p1 = 5 },
    board_sync_pending = true,
    board_last_phase = "land",
  }
  local board_runtime = runtime_state.ensure_board_runtime(state)
  _assert_eq(board_runtime.board_last_positions, state.board_last_positions, "board_last_positions should come from state")
  _assert_eq(board_runtime.board_sync_pending, true, "board_sync_pending should inherit from state")
  _assert_eq(board_runtime.board_last_phase, "land", "board_last_phase should inherit from state")
end

function TestRuntimeState:test_set_follow_target_position_basic()
  local state = {}
  local ok = runtime_state.set_follow_target_position(state, "p1", 7)
  _assert_eq(ok, true, "set_follow_target_position should return true on success")
  _assert_eq(runtime_state.get_follow_target_position(state, "p1"), 7, "get_follow_target_position should return stored position")
end

function TestRuntimeState:test_set_follow_target_position_nil_args_returns_false()
  _assert_eq(runtime_state.set_follow_target_position(nil, "p1", 5), false, "nil state should return false")
  local state = {}
  _assert_eq(runtime_state.set_follow_target_position(state, nil, 5), false, "nil player_id should return false")
  _assert_eq(runtime_state.set_follow_target_position(state, "p1", nil), false, "nil position should return false")
end

function TestRuntimeState:test_set_follow_target_position_seq_rejects_stale()
  local state = {}
  runtime_state.set_follow_target_position(state, "p1", 10, { seq = 5 })
  local ok = runtime_state.set_follow_target_position(state, "p1", 20, { seq = 3 })
  _assert_eq(ok, false, "stale seq should be rejected")
  _assert_eq(runtime_state.get_follow_target_position(state, "p1"), 10, "position should not change on stale seq")
end

function TestRuntimeState:test_set_follow_target_position_seq_accepts_newer()
  local state = {}
  runtime_state.set_follow_target_position(state, "p1", 10, { seq = 2 })
  local ok = runtime_state.set_follow_target_position(state, "p1", 20, { seq = 5 })
  _assert_eq(ok, true, "newer seq should be accepted")
  _assert_eq(runtime_state.get_follow_target_position(state, "p1"), 20, "position should update on newer seq")
end

function TestRuntimeState:test_get_follow_target_position_nil_args_returns_nil()
  _assert_eq(runtime_state.get_follow_target_position(nil, "p1"), nil, "nil state should return nil")
  _assert_eq(runtime_state.get_follow_target_position({}, nil), nil, "nil player_id should return nil")
end

function TestRuntimeState:test_set_follow_target_position_equal_seq_is_not_stale()
  local state = {}
  runtime_state.set_follow_target_position(state, "p1", 10, { seq = 5 })
  local ok = runtime_state.set_follow_target_position(state, "p1", 20, { seq = 5 })
  _assert_eq(ok, true, "equal seq should not count as stale (kills next_seq < last_seq -> <=)")
  _assert_eq(runtime_state.get_follow_target_position(state, "p1"), 20, "equal seq write should apply")
end

function TestRuntimeState:test_ensure_turn_runtime_inherits_next_turn_locked()
  local state = { next_turn_locked = true }
  local turn_runtime = runtime_state.ensure_turn_runtime(state)
  _assert_eq(turn_runtime.next_turn_locked, true,
    "next_turn_locked should inherit the true flag (kills == true -> false)")
end

function TestRuntimeState:test_ensure_turn_runtime_inherits_role_control_lock_suppress()
  local state = { role_control_lock_suppress = 3 }
  local turn_runtime = runtime_state.ensure_turn_runtime(state)
  _assert_eq(turn_runtime.role_control_lock_suppress, 3,
    "non-nil suppress should pass through (kills `or 0` -> `and 0`)")
end

function TestRuntimeState:test_ensure_turn_runtime_defaults_role_control_lock_suppress_zero()
  local state = {}
  local turn_runtime = runtime_state.ensure_turn_runtime(state)
  _assert_eq(turn_runtime.role_control_lock_suppress, 0,
    "nil suppress should default to 0 (kills `or 0` -> `or 1`)")
end

function TestRuntimeState:test_mark_landing_visual_release_pulse_returns_true()
  local state = {}
  _assert_eq(runtime_state.mark_landing_visual_release_pulse(state), true,
    "mark should return true (kills return true -> false)")
end

function TestRuntimeState:test_ensure_turn_runtime_hold_carries_a_deferred_dirty_bucket()
  local state = {}
  local turn_runtime = runtime_state.ensure_turn_runtime(state)
  lu.assertEvalToTrue(type(turn_runtime.landing_visual_hold.deferred_dirty) == "table",
    "the hold must carry a deferred-dirty bucket (kills dirty_tracker.new() -> nil)")
end

function TestRuntimeState:test_get_follow_target_position_missing_returns_nil()
  local state = {}
  _assert_eq(runtime_state.get_follow_target_position(state, "unknown"), nil, "missing player should return nil")
end

function TestRuntimeState:test_ensure_anim_runtime_initializes_fields()
  local state = { move_anim_seq = 3, action_anim_seq = 7 }
  local anim_runtime = runtime_state.ensure_anim_runtime(state)
  lu.assertEvalToTrue(type(anim_runtime) == "table", "ensure_anim_runtime should return a table")
  _assert_eq(anim_runtime.move_anim_seq, 3, "move_anim_seq should inherit from state")
  _assert_eq(anim_runtime.action_anim_seq, 7, "action_anim_seq should inherit from state")
end

function TestRuntimeState:test_ensure_turn_runtime_initializes_fields()
  local state = {}
  local turn_runtime = runtime_state.ensure_turn_runtime(state)
  lu.assertEvalToTrue(type(turn_runtime) == "table", "ensure_turn_runtime should return a table")
  _assert_eq(turn_runtime.next_turn_locked, false, "next_turn_locked should default to false")
  _assert_eq(turn_runtime.landing_visual_release_pulse, false, "landing_visual_release_pulse should default to false")
  lu.assertEvalToTrue(type(turn_runtime.landing_visual_hold) == "table", "landing_visual_hold should be initialized")
end

function TestRuntimeState:test_get_set_landing_visual_hold_active()
  local state = {}
  _assert_eq(runtime_state.get_landing_visual_hold_active(state), false, "initial hold active should be false")
  runtime_state.set_landing_visual_hold_active(state, true)
  _assert_eq(runtime_state.get_landing_visual_hold_active(state), true, "hold active should be true after set")
  runtime_state.set_landing_visual_hold_active(state, false)
  _assert_eq(runtime_state.get_landing_visual_hold_active(state), false, "hold active should be false after clear")
end

function TestRuntimeState:test_get_set_landing_visual_release_pending()
  local state = {}
  _assert_eq(runtime_state.get_landing_visual_release_pending(state), false, "initial release_pending should be false")
  runtime_state.set_landing_visual_release_pending(state, true)
  _assert_eq(runtime_state.get_landing_visual_release_pending(state), true, "release_pending should be true after set")
end

function TestRuntimeState:test_get_set_landing_visual_hold_source()
  local state = {}
  _assert_eq(runtime_state.get_landing_visual_hold_source(state), nil, "initial hold source should be nil")
  runtime_state.set_landing_visual_hold_source(state, "landing_effect")
  _assert_eq(runtime_state.get_landing_visual_hold_source(state), "landing_effect", "hold source should update")
end

function TestRuntimeState:test_mark_and_take_landing_visual_release_pulse()
  local state = {}
  _assert_eq(runtime_state.take_landing_visual_release_pulse(state), false, "pulse should be false before mark")
  runtime_state.mark_landing_visual_release_pulse(state)
  _assert_eq(runtime_state.take_landing_visual_release_pulse(state), true, "pulse should be true after mark")
  _assert_eq(runtime_state.take_landing_visual_release_pulse(state), false, "take should consume the pulse")
end

function TestRuntimeState:test_ensure_debug_runtime_initializes_fields()
  local state = {}
  local debug_runtime = runtime_state.ensure_debug_runtime(state)
  lu.assertEvalToTrue(type(debug_runtime) == "table", "ensure_debug_runtime should return a table")
  lu.assertEvalToTrue(type(debug_runtime.log_once) == "table", "log_once should be initialized")
end

function TestRuntimeState:test_ensure_debug_runtime_inherits_state_log_once()
  local log_once = { some_key = true }
  local state = { _log_once = log_once }
  local debug_runtime = runtime_state.ensure_debug_runtime(state)
  _assert_eq(debug_runtime.log_once, log_once, "log_once should inherit from state._log_once")
end

function TestRuntimeState:test_ensure_all_initializes_all_runtime_tables()
  local state = {}
  local result = runtime_state.ensure_all(state)
  _assert_eq(result, state, "ensure_all should return the state")
  lu.assertEvalToTrue(type(state.ui_runtime) == "table", "ui_runtime should be present after ensure_all")
  lu.assertEvalToTrue(type(state.board_runtime) == "table", "board_runtime should be present after ensure_all")
  lu.assertEvalToTrue(type(state.anim_runtime) == "table", "anim_runtime should be present after ensure_all")
  lu.assertEvalToTrue(type(state.turn_runtime) == "table", "turn_runtime should be present after ensure_all")
  lu.assertEvalToTrue(type(state.debug_runtime) == "table", "debug_runtime should be present after ensure_all")
end

function TestRuntimeState:test_ensure_ui_runtime_idempotent()
  local state = {}
  local r1 = runtime_state.ensure_ui_runtime(state)
  local r2 = runtime_state.ensure_ui_runtime(state)
  _assert_eq(r1, r2, "ensure_ui_runtime should return same table on repeated calls")
end

function TestRuntimeState:test_ensure_ui_runtime_inherits_item_name_by_id()
  local item_map = { sword = "火焰剑" }
  local state = { item_name_by_id = item_map }
  local ui_runtime = runtime_state.ensure_ui_runtime(state)
  _assert_eq(ui_runtime.item_name_by_id, item_map, "item_name_by_id should inherit from state")
end

function TestRuntimeState:test_is_ui_dirty_and_set_ui_dirty()
  local state = {}
  _assert_eq(runtime_state.is_ui_dirty(state), false, "initial ui_dirty should be false")
  runtime_state.set_ui_dirty(state, true)
  _assert_eq(runtime_state.is_ui_dirty(state), true, "should be dirty after set true")
  runtime_state.set_ui_dirty(state, false)
  _assert_eq(runtime_state.is_ui_dirty(state), false, "should be clean after set false")
end

function TestRuntimeState:test_get_ui_model_and_set_ui_model()
  local state = {}
  _assert_eq(runtime_state.get_ui_model(state), nil, "initial ui_model should be nil")
  local model = { kind = "main" }
  local returned = runtime_state.set_ui_model(state, model)
  _assert_eq(returned, model, "set_ui_model should return model")
  _assert_eq(runtime_state.get_ui_model(state), model, "get_ui_model should return stored model")
end

function TestRuntimeState:test_set_pending_choice_id_direct()
  local state = {}
  runtime_state.set_pending_choice_id(state, 77)
  _assert_eq(runtime_state.get_pending_choice_id(state), 77, "set_pending_choice_id should store id")
end

function TestRuntimeState:test_set_pending_choice_elapsed_direct()
  local state = {}
  local returned = runtime_state.set_pending_choice_elapsed(state, 3.5)
  _assert_eq(returned, 3.5, "set_pending_choice_elapsed should return elapsed")
  _assert_eq(runtime_state.get_pending_choice_elapsed(state), 3.5, "get should return stored elapsed")
end

function TestRuntimeState:test_set_pending_choice_elapsed_nil_defaults_to_zero()
  local state = {}
  local returned = runtime_state.set_pending_choice_elapsed(state, nil)
  _assert_eq(returned, 0, "nil elapsed should default to 0")
end

function TestRuntimeState:test_set_modal_timer_stores_elapsed_and_ref()
  local state = {}
  local ref, elapsed = runtime_state.set_modal_timer(state, { elapsed_seconds = 2.5, ref = "modal_buy" })
  _assert_eq(ref, "modal_buy", "set_modal_timer should return ref")
  _assert_eq(elapsed, 2.5, "set_modal_timer should return elapsed")
  _assert_eq(runtime_state.get_modal_elapsed(state), 2.5, "modal elapsed should be stored")
  _assert_eq(runtime_state.get_modal_ref(state), "modal_buy", "modal ref should be stored")
end

function TestRuntimeState:test_set_modal_timer_nil_payload_defaults()
  local state = {}
  local ref, elapsed = runtime_state.set_modal_timer(state, nil)
  _assert_eq(ref, nil, "nil payload ref should be nil")
  _assert_eq(elapsed, 0, "nil payload elapsed should default to 0")
end


return TestRuntimeState
