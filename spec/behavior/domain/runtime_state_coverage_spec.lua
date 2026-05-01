local runtime_state = require("src.state.runtime_state")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

describe("domain runtime state coverage", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("get/set local_actor_role_id", function()
    local state = {}
    _assert_eq(runtime_state.get_local_actor_role_id(state), nil, "initial local_actor_role_id should be nil")
    runtime_state.set_local_actor_role_id(state, "role_p1")
    _assert_eq(runtime_state.get_local_actor_role_id(state), "role_p1", "set_local_actor_role_id should update and return id")
  end)

  it("set_pending_choice with opts.choice_id overrides choice.id", function()
    local state = {}
    local choice = { id = 10, kind = "market_buy" }
    runtime_state.set_pending_choice(state, choice, { choice_id = 99, elapsed_seconds = 1.5 })
    _assert_eq(runtime_state.get_pending_choice(state), choice, "set_pending_choice should store choice")
    _assert_eq(runtime_state.get_pending_choice_id(state), 99, "explicit opts.choice_id should override choice.id")
    _assert_eq(runtime_state.get_pending_choice_elapsed(state), 1.5, "elapsed_seconds from opts should be stored")
  end)

  it("set_pending_choice nil choice_id uses choice.id", function()
    local state = {}
    local choice = { id = 42, kind = "item_phase_choice" }
    runtime_state.set_pending_choice(state, choice)
    _assert_eq(runtime_state.get_pending_choice_id(state), 42, "nil opts.choice_id should fall back to choice.id")
    _assert_eq(runtime_state.get_pending_choice_elapsed(state), 0, "nil elapsed_seconds should default to 0")
  end)

  it("set_pending_choice nil choice resets id", function()
    local state = {}
    runtime_state.set_pending_choice(state, nil)
    _assert_eq(runtime_state.get_pending_choice(state), nil, "nil choice should store nil")
    _assert_eq(runtime_state.get_pending_choice_id(state), nil, "nil choice should leave id nil")
  end)

  it("ensure_board_runtime initializes fields", function()
    local state = {}
    local board_runtime = runtime_state.ensure_board_runtime(state)
    assert(type(board_runtime) == "table", "ensure_board_runtime should return a table")
    assert(type(board_runtime.board_last_positions) == "table", "board_last_positions should be initialized")
    assert(type(board_runtime.follow_targets) == "table", "follow_targets should be initialized")
    _assert_eq(board_runtime.board_sync_pending, false, "board_sync_pending should default to false")
  end)

  it("ensure_board_runtime inherits state fields", function()
    local state = {
      board_last_positions = { p1 = 5 },
      board_sync_pending = true,
      board_last_phase = "land",
      board_last_vehicle_resync_seq = 3,
    }
    local board_runtime = runtime_state.ensure_board_runtime(state)
    _assert_eq(board_runtime.board_last_positions, state.board_last_positions, "board_last_positions should come from state")
    _assert_eq(board_runtime.board_sync_pending, true, "board_sync_pending should inherit from state")
    _assert_eq(board_runtime.board_last_phase, "land", "board_last_phase should inherit from state")
    _assert_eq(board_runtime.board_last_vehicle_resync_seq, 3, "board_last_vehicle_resync_seq should inherit from state")
  end)

  it("set_follow_target_position basic", function()
    local state = {}
    local ok = runtime_state.set_follow_target_position(state, "p1", 7)
    _assert_eq(ok, true, "set_follow_target_position should return true on success")
    _assert_eq(runtime_state.get_follow_target_position(state, "p1"), 7, "get_follow_target_position should return stored position")
  end)

  it("set_follow_target_position nil args returns false", function()
    _assert_eq(runtime_state.set_follow_target_position(nil, "p1", 5), false, "nil state should return false")
    local state = {}
    _assert_eq(runtime_state.set_follow_target_position(state, nil, 5), false, "nil player_id should return false")
    _assert_eq(runtime_state.set_follow_target_position(state, "p1", nil), false, "nil position should return false")
  end)

  it("set_follow_target_position seq rejects stale", function()
    local state = {}
    runtime_state.set_follow_target_position(state, "p1", 10, { seq = 5 })
    local ok = runtime_state.set_follow_target_position(state, "p1", 20, { seq = 3 })
    _assert_eq(ok, false, "stale seq should be rejected")
    _assert_eq(runtime_state.get_follow_target_position(state, "p1"), 10, "position should not change on stale seq")
  end)

  it("set_follow_target_position seq accepts newer", function()
    local state = {}
    runtime_state.set_follow_target_position(state, "p1", 10, { seq = 2 })
    local ok = runtime_state.set_follow_target_position(state, "p1", 20, { seq = 5 })
    _assert_eq(ok, true, "newer seq should be accepted")
    _assert_eq(runtime_state.get_follow_target_position(state, "p1"), 20, "position should update on newer seq")
  end)

  it("get_follow_target_position nil args returns nil", function()
    _assert_eq(runtime_state.get_follow_target_position(nil, "p1"), nil, "nil state should return nil")
    _assert_eq(runtime_state.get_follow_target_position({}, nil), nil, "nil player_id should return nil")
  end)

  it("get_follow_target_position missing returns nil", function()
    local state = {}
    _assert_eq(runtime_state.get_follow_target_position(state, "unknown"), nil, "missing player should return nil")
  end)

  it("ensure_anim_runtime initializes fields", function()
    local state = { move_anim_seq = 3, action_anim_seq = 7 }
    local anim_runtime = runtime_state.ensure_anim_runtime(state)
    assert(type(anim_runtime) == "table", "ensure_anim_runtime should return a table")
    _assert_eq(anim_runtime.move_anim_seq, 3, "move_anim_seq should inherit from state")
    _assert_eq(anim_runtime.action_anim_seq, 7, "action_anim_seq should inherit from state")
  end)

  it("ensure_turn_runtime initializes fields", function()
    local state = {}
    local turn_runtime = runtime_state.ensure_turn_runtime(state)
    assert(type(turn_runtime) == "table", "ensure_turn_runtime should return a table")
    _assert_eq(turn_runtime.next_turn_locked, false, "next_turn_locked should default to false")
    _assert_eq(turn_runtime.landing_visual_release_pulse, false, "landing_visual_release_pulse should default to false")
    assert(type(turn_runtime.landing_visual_hold) == "table", "landing_visual_hold should be initialized")
  end)

  it("get/set landing_visual_hold_active", function()
    local state = {}
    _assert_eq(runtime_state.get_landing_visual_hold_active(state), false, "initial hold active should be false")
    runtime_state.set_landing_visual_hold_active(state, true)
    _assert_eq(runtime_state.get_landing_visual_hold_active(state), true, "hold active should be true after set")
    runtime_state.set_landing_visual_hold_active(state, false)
    _assert_eq(runtime_state.get_landing_visual_hold_active(state), false, "hold active should be false after clear")
  end)

  it("get/set landing_visual_release_pending", function()
    local state = {}
    _assert_eq(runtime_state.get_landing_visual_release_pending(state), false, "initial release_pending should be false")
    runtime_state.set_landing_visual_release_pending(state, true)
    _assert_eq(runtime_state.get_landing_visual_release_pending(state), true, "release_pending should be true after set")
  end)

  it("get/set landing_visual_hold_source", function()
    local state = {}
    _assert_eq(runtime_state.get_landing_visual_hold_source(state), nil, "initial hold source should be nil")
    runtime_state.set_landing_visual_hold_source(state, "landing_effect")
    _assert_eq(runtime_state.get_landing_visual_hold_source(state), "landing_effect", "hold source should update")
  end)

  it("mark and take landing_visual_release_pulse", function()
    local state = {}
    _assert_eq(runtime_state.take_landing_visual_release_pulse(state), false, "pulse should be false before mark")
    runtime_state.mark_landing_visual_release_pulse(state)
    _assert_eq(runtime_state.take_landing_visual_release_pulse(state), true, "pulse should be true after mark")
    _assert_eq(runtime_state.take_landing_visual_release_pulse(state), false, "take should consume the pulse")
  end)

  it("ensure_debug_runtime initializes fields", function()
    local state = {}
    local debug_runtime = runtime_state.ensure_debug_runtime(state)
    assert(type(debug_runtime) == "table", "ensure_debug_runtime should return a table")
    assert(type(debug_runtime.log_once) == "table", "log_once should be initialized")
  end)

  it("ensure_debug_runtime inherits state log_once", function()
    local log_once = { some_key = true }
    local state = { _log_once = log_once }
    local debug_runtime = runtime_state.ensure_debug_runtime(state)
    _assert_eq(debug_runtime.log_once, log_once, "log_once should inherit from state._log_once")
  end)

  it("ensure_all initializes all runtime tables", function()
    local state = {}
    local result = runtime_state.ensure_all(state)
    _assert_eq(result, state, "ensure_all should return the state")
    assert(type(state.ui_runtime) == "table", "ui_runtime should be present after ensure_all")
    assert(type(state.board_runtime) == "table", "board_runtime should be present after ensure_all")
    assert(type(state.anim_runtime) == "table", "anim_runtime should be present after ensure_all")
    assert(type(state.turn_runtime) == "table", "turn_runtime should be present after ensure_all")
    assert(type(state.debug_runtime) == "table", "debug_runtime should be present after ensure_all")
  end)

  it("ensure_ui_runtime idempotent", function()
    local state = {}
    local r1 = runtime_state.ensure_ui_runtime(state)
    local r2 = runtime_state.ensure_ui_runtime(state)
    _assert_eq(r1, r2, "ensure_ui_runtime should return same table on repeated calls")
  end)

  it("ensure_ui_runtime inherits item_name_by_id", function()
    local item_map = { sword = "火焰剑" }
    local state = { item_name_by_id = item_map }
    local ui_runtime = runtime_state.ensure_ui_runtime(state)
    _assert_eq(ui_runtime.item_name_by_id, item_map, "item_name_by_id should inherit from state")
  end)

  it("is_ui_dirty and set_ui_dirty", function()
    local state = {}
    _assert_eq(runtime_state.is_ui_dirty(state), false, "initial ui_dirty should be false")
    runtime_state.set_ui_dirty(state, true)
    _assert_eq(runtime_state.is_ui_dirty(state), true, "should be dirty after set true")
    runtime_state.set_ui_dirty(state, false)
    _assert_eq(runtime_state.is_ui_dirty(state), false, "should be clean after set false")
  end)

  it("get_ui_model and set_ui_model", function()
    local state = {}
    _assert_eq(runtime_state.get_ui_model(state), nil, "initial ui_model should be nil")
    local model = { kind = "main" }
    local returned = runtime_state.set_ui_model(state, model)
    _assert_eq(returned, model, "set_ui_model should return model")
    _assert_eq(runtime_state.get_ui_model(state), model, "get_ui_model should return stored model")
  end)

  it("set_pending_choice_id direct", function()
    local state = {}
    runtime_state.set_pending_choice_id(state, 77)
    _assert_eq(runtime_state.get_pending_choice_id(state), 77, "set_pending_choice_id should store id")
  end)

  it("set_pending_choice_elapsed direct", function()
    local state = {}
    local returned = runtime_state.set_pending_choice_elapsed(state, 3.5)
    _assert_eq(returned, 3.5, "set_pending_choice_elapsed should return elapsed")
    _assert_eq(runtime_state.get_pending_choice_elapsed(state), 3.5, "get should return stored elapsed")
  end)

  it("set_pending_choice_elapsed nil defaults to zero", function()
    local state = {}
    local returned = runtime_state.set_pending_choice_elapsed(state, nil)
    _assert_eq(returned, 0, "nil elapsed should default to 0")
  end)

  it("get_modal_elapsed initial is zero", function()
    local state = {}
    _assert_eq(runtime_state.get_modal_elapsed(state), 0, "initial modal elapsed should be 0")
  end)

  it("get_modal_ref initial is nil", function()
    local state = {}
    _assert_eq(runtime_state.get_modal_ref(state), nil, "initial modal ref should be nil")
  end)

  it("set_modal_timer stores elapsed and ref", function()
    local state = {}
    local ref, elapsed = runtime_state.set_modal_timer(state, { elapsed_seconds = 2.5, ref = "modal_buy" })
    _assert_eq(ref, "modal_buy", "set_modal_timer should return ref")
    _assert_eq(elapsed, 2.5, "set_modal_timer should return elapsed")
    _assert_eq(runtime_state.get_modal_elapsed(state), 2.5, "modal elapsed should be stored")
    _assert_eq(runtime_state.get_modal_ref(state), "modal_buy", "modal ref should be stored")
  end)

  it("set_modal_timer nil payload defaults", function()
    local state = {}
    local ref, elapsed = runtime_state.set_modal_timer(state, nil)
    _assert_eq(ref, nil, "nil payload ref should be nil")
    _assert_eq(elapsed, 0, "nil payload elapsed should default to 0")
  end)
end)
