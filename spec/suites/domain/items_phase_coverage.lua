local phase_module = require("src.rules.items.phase")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _make_game()
  return {
    turn = {},
    dirty = { turn = false, any = false },
  }
end

-- is_enabled

local function test_is_enabled_pre_action_true()
  _assert_eq(phase_module.is_enabled("pre_action"), true, "pre_action should be enabled")
end

local function test_is_enabled_pre_move_true()
  _assert_eq(phase_module.is_enabled("pre_move"), true, "pre_move should be enabled")
end

local function test_is_enabled_post_action_true()
  _assert_eq(phase_module.is_enabled("post_action"), true, "post_action should be enabled")
end

local function test_is_enabled_unknown_false()
  _assert_eq(phase_module.is_enabled("unknown_phase"), false, "unknown phase should not be enabled")
end

local function test_is_enabled_nil_false()
  _assert_eq(phase_module.is_enabled(nil), false, "nil phase should not be enabled")
end

-- is_repeatable

local function test_is_repeatable_pre_action_true()
  _assert_eq(phase_module.is_repeatable("pre_action"), true, "pre_action should be repeatable")
end

local function test_is_repeatable_pre_move_true()
  _assert_eq(phase_module.is_repeatable("pre_move"), true, "pre_move should be repeatable")
end

local function test_is_repeatable_post_action_true()
  _assert_eq(phase_module.is_repeatable("post_action"), true, "post_action should be repeatable")
end

local function test_is_repeatable_unknown_false()
  _assert_eq(phase_module.is_repeatable("other"), false, "unknown phase should not be repeatable")
end

-- finish

local function test_finish_marks_phase_done()
  local game = _make_game()
  phase_module.finish(game, "pre_action")
  assert(game.turn.item_phase, "item_phase should be initialized")
  _assert_eq(game.turn.item_phase.pre_action.done, true, "done should be true")
  _assert_eq(game.dirty.turn, true, "dirty.turn should be set")
  _assert_eq(game.dirty.any, true, "dirty.any should be set")
end

local function test_finish_clears_item_phase_active_when_matches()
  local game = _make_game()
  game.turn.item_phase_active = "pre_action"
  phase_module.finish(game, "pre_action")
  _assert_eq(game.turn.item_phase_active, "", "item_phase_active should be cleared when phase matches")
end

local function test_finish_does_not_clear_active_when_different_phase()
  local game = _make_game()
  game.turn.item_phase_active = "pre_move"
  phase_module.finish(game, "pre_action")
  _assert_eq(game.turn.item_phase_active, "pre_move", "item_phase_active should not be cleared when phase differs")
end

-- _build_wait_choice_next_state / _build_wait_choice_next_args

local function test_build_wait_choice_next_state_returns_meta_value()
  local meta = { resume_next_state = "move", resume_next_args = { x = 1 } }
  _assert_eq(phase_module._build_wait_choice_next_state(meta), "move", "should return resume_next_state")
end

local function test_build_wait_choice_next_state_errors_on_nil_meta()
  local ok = pcall(function() phase_module._build_wait_choice_next_state(nil) end)
  _assert_eq(ok, false, "nil meta should error")
end

local function test_build_wait_choice_next_state_errors_on_missing_resume_next_state()
  local ok = pcall(function() phase_module._build_wait_choice_next_state({}) end)
  _assert_eq(ok, false, "missing resume_next_state should error")
end

local function test_build_wait_choice_next_args_returns_meta_value()
  local meta = { resume_next_state = "move", resume_next_args = { player = 1 } }
  local args = phase_module._build_wait_choice_next_args(meta)
  assert(args ~= nil and args.player == 1, "should return resume_next_args with player=1")
end

local function test_build_wait_choice_next_args_returns_nil_for_nil_meta()
  local args = phase_module._build_wait_choice_next_args(nil)
  _assert_eq(args, nil, "nil meta should return nil")
end

local function test_build_wait_choice_args_returns_both()
  local meta = { resume_next_state = "land", resume_next_args = { y = 2 } }
  local result = phase_module.build_wait_choice_args(meta)
  _assert_eq(result.next_state, "land", "next_state should match resume_next_state")
  _assert_eq(result.next_args.y, 2, "next_args should match resume_next_args")
end

-- mark_active

local function test_mark_active_sets_phase_active()
  local game = _make_game()
  phase_module.mark_active(game, "pre_move")
  assert(game.turn.item_phase, "item_phase should exist")
  _assert_eq(game.turn.item_phase.pre_move.active, true, "active should be true")
  _assert_eq(game.turn.item_phase_active, "pre_move", "item_phase_active should be set")
  _assert_eq(game.dirty.turn, true, "dirty.turn should be set")
end

-- decorate_followup_choice_spec

local function test_decorate_followup_sets_meta_fields()
  local spec = {}
  local meta = { phase = "pre_action", resume_next_state = "move", resume_next_args = { a = 1 } }
  phase_module.decorate_followup_choice_spec(spec, meta)
  _assert_eq(spec.meta.phase, "pre_action", "meta.phase should be set")
  _assert_eq(spec.meta.resume_next_state, "move", "meta.resume_next_state should be set")
  _assert_eq(spec.meta.resume_next_args.a, 1, "meta.resume_next_args should be set")
end

local function test_decorate_followup_repeatable_sets_allow_cancel()
  local spec = {}
  local meta = { phase = "pre_action", resume_next_state = "move", resume_next_args = nil }
  phase_module.decorate_followup_choice_spec(spec, meta)
  _assert_eq(spec.allow_cancel, true, "repeatable phase should set allow_cancel=true")
  _assert_eq(spec.cancel_label, "返回", "cancel_label should be 返回 when not already set")
end

local function test_decorate_followup_non_repeatable_no_cancel()
  local spec = {}
  local meta = { phase = "unknown_non_repeatable", resume_next_state = "x", resume_next_args = nil }
  phase_module.decorate_followup_choice_spec(spec, meta)
  _assert_eq(spec.allow_cancel, nil, "non-repeatable phase should not set allow_cancel")
end

local function test_decorate_followup_preserves_existing_cancel_label()
  local spec = { cancel_label = "custom" }
  local meta = { phase = "pre_move", resume_next_state = "x", resume_next_args = nil }
  phase_module.decorate_followup_choice_spec(spec, meta)
  _assert_eq(spec.cancel_label, "custom", "existing cancel_label should be preserved")
end

local function test_decorate_followup_non_table_spec_returns_spec()
  local result = phase_module.decorate_followup_choice_spec("not_a_table", {})
  _assert_eq(result, "not_a_table", "non-table spec should be returned unchanged")
end

local function test_decorate_followup_nil_meta_returns_spec()
  local spec = { data = true }
  local result = phase_module.decorate_followup_choice_spec(spec, nil)
  _assert_eq(result, spec, "nil meta should return spec unchanged")
end

return {
  name = "domain items phase coverage",
  tests = {
    { name = "is_enabled pre_action true", run = test_is_enabled_pre_action_true },
    { name = "is_enabled pre_move true", run = test_is_enabled_pre_move_true },
    { name = "is_enabled post_action true", run = test_is_enabled_post_action_true },
    { name = "is_enabled unknown false", run = test_is_enabled_unknown_false },
    { name = "is_enabled nil false", run = test_is_enabled_nil_false },
    { name = "is_repeatable pre_action true", run = test_is_repeatable_pre_action_true },
    { name = "is_repeatable pre_move true", run = test_is_repeatable_pre_move_true },
    { name = "is_repeatable post_action true", run = test_is_repeatable_post_action_true },
    { name = "is_repeatable unknown false", run = test_is_repeatable_unknown_false },
    { name = "finish marks phase done", run = test_finish_marks_phase_done },
    { name = "finish clears item_phase_active when matches", run = test_finish_clears_item_phase_active_when_matches },
    { name = "finish does not clear active when different phase", run = test_finish_does_not_clear_active_when_different_phase },
    { name = "build_wait_choice_next_state returns meta value", run = test_build_wait_choice_next_state_returns_meta_value },
    { name = "build_wait_choice_next_state errors on nil meta", run = test_build_wait_choice_next_state_errors_on_nil_meta },
    { name = "build_wait_choice_next_state errors on missing resume_next_state", run = test_build_wait_choice_next_state_errors_on_missing_resume_next_state },
    { name = "build_wait_choice_next_args returns meta value", run = test_build_wait_choice_next_args_returns_meta_value },
    { name = "build_wait_choice_next_args returns nil for nil meta", run = test_build_wait_choice_next_args_returns_nil_for_nil_meta },
    { name = "build_wait_choice_args returns both", run = test_build_wait_choice_args_returns_both },
    { name = "mark_active sets phase active", run = test_mark_active_sets_phase_active },
    { name = "decorate_followup sets meta fields", run = test_decorate_followup_sets_meta_fields },
    { name = "decorate_followup repeatable sets allow_cancel", run = test_decorate_followup_repeatable_sets_allow_cancel },
    { name = "decorate_followup non-repeatable no cancel", run = test_decorate_followup_non_repeatable_no_cancel },
    { name = "decorate_followup preserves existing cancel_label", run = test_decorate_followup_preserves_existing_cancel_label },
    { name = "decorate_followup non-table spec returns spec", run = test_decorate_followup_non_table_spec_returns_spec },
    { name = "decorate_followup nil meta returns spec", run = test_decorate_followup_nil_meta_returns_spec },
  },
}
