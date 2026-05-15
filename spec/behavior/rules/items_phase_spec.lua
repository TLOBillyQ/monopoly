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






-- is_repeatable





-- finish




-- _build_wait_choice_next_state / _build_wait_choice_next_args







-- mark_active


-- decorate_followup_choice_spec

describe("domain items phase coverage", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("is_enabled pre_action true", function()
    _assert_eq(phase_module.is_enabled("pre_action"), true, "pre_action should be enabled")
  end)

  it("is_enabled pre_move true", function()
    _assert_eq(phase_module.is_enabled("pre_move"), true, "pre_move should be enabled")
  end)

  it("is_enabled post_action true", function()
    _assert_eq(phase_module.is_enabled("post_action"), true, "post_action should be enabled")
  end)

  it("is_enabled unknown false", function()
    _assert_eq(phase_module.is_enabled("unknown_phase"), false, "unknown phase should not be enabled")
  end)

  it("is_enabled nil false", function()
    _assert_eq(phase_module.is_enabled(nil), false, "nil phase should not be enabled")
  end)

  it("is_repeatable pre_action true", function()
    _assert_eq(phase_module.is_repeatable("pre_action"), true, "pre_action should be repeatable")
  end)

  it("is_repeatable pre_move true", function()
    _assert_eq(phase_module.is_repeatable("pre_move"), true, "pre_move should be repeatable")
  end)

  it("is_repeatable post_action true", function()
    _assert_eq(phase_module.is_repeatable("post_action"), true, "post_action should be repeatable")
  end)

  it("is_repeatable unknown false", function()
    _assert_eq(phase_module.is_repeatable("other"), false, "unknown phase should not be repeatable")
  end)

  it("finish marks phase done", function()
    local game = _make_game()
    phase_module.finish(game, "pre_action")
    assert(game.turn.item_phase, "item_phase should be initialized")
    _assert_eq(game.turn.item_phase.pre_action.done, true, "done should be true")
    _assert_eq(game.dirty.turn, true, "dirty.turn should be set")
    _assert_eq(game.dirty.any, true, "dirty.any should be set")
  end)

  it("finish clears item_phase_active when matches", function()
    local game = _make_game()
    game.turn.item_phase_active = "pre_action"
    phase_module.finish(game, "pre_action")
    _assert_eq(game.turn.item_phase_active, "", "item_phase_active should be cleared when phase matches")
  end)

  it("finish does not clear active when different phase", function()
    local game = _make_game()
    game.turn.item_phase_active = "pre_move"
    phase_module.finish(game, "pre_action")
    _assert_eq(game.turn.item_phase_active, "pre_move", "item_phase_active should not be cleared when phase differs")
  end)

  it("build_wait_choice_args extracts next_state from meta", function()
    local meta = { resume_next_state = "move", resume_next_args = { x = 1 } }
    local result = phase_module.build_wait_choice_args(meta)
    _assert_eq(result.next_state, "move", "should return resume_next_state")
  end)

  it("build_wait_choice_args errors on nil meta", function()
    local ok = pcall(function() phase_module.build_wait_choice_args(nil) end)
    _assert_eq(ok, false, "nil meta should error")
  end)

  it("build_wait_choice_args errors on missing resume_next_state", function()
    local ok = pcall(function() phase_module.build_wait_choice_args({}) end)
    _assert_eq(ok, false, "missing resume_next_state should error")
  end)

  it("build_wait_choice_args extracts next_args from meta", function()
    local meta = { resume_next_state = "move", resume_next_args = { player = 1 } }
    local result = phase_module.build_wait_choice_args(meta)
    assert(result.next_args ~= nil and result.next_args.player == 1, "should return resume_next_args with player=1")
  end)

  it("build_wait_choice_args returns nil next_args for nil meta resume_next_args", function()
    local meta = { resume_next_state = "move" }
    local result = phase_module.build_wait_choice_args(meta)
    _assert_eq(result.next_args, nil, "missing resume_next_args should return nil")
  end)

  it("build_wait_choice_args returns both", function()
    local meta = { resume_next_state = "land", resume_next_args = { y = 2 } }
    local result = phase_module.build_wait_choice_args(meta)
    _assert_eq(result.next_state, "land", "next_state should match resume_next_state")
    _assert_eq(result.next_args.y, 2, "next_args should match resume_next_args")
  end)

  it("mark_active sets phase active", function()
    local game = _make_game()
    phase_module.mark_active(game, "pre_move")
    assert(game.turn.item_phase, "item_phase should exist")
    _assert_eq(game.turn.item_phase.pre_move.active, true, "active should be true")
    _assert_eq(game.turn.item_phase_active, "pre_move", "item_phase_active should be set")
    _assert_eq(game.dirty.turn, true, "dirty.turn should be set")
  end)

  it("decorate_followup sets meta fields", function()
    local spec = {}
    local meta = { phase = "pre_action", resume_next_state = "move", resume_next_args = { a = 1 } }
    phase_module.decorate_followup_choice_spec(spec, meta)
    _assert_eq(spec.meta.phase, "pre_action", "meta.phase should be set")
    _assert_eq(spec.meta.resume_next_state, "move", "meta.resume_next_state should be set")
    _assert_eq(spec.meta.resume_next_args.a, 1, "meta.resume_next_args should be set")
  end)

  it("decorate_followup repeatable sets allow_cancel", function()
    local spec = {}
    local meta = { phase = "pre_action", resume_next_state = "move", resume_next_args = nil }
    phase_module.decorate_followup_choice_spec(spec, meta)
    _assert_eq(spec.allow_cancel, true, "repeatable phase should set allow_cancel=true")
    _assert_eq(spec.cancel_label, "返回", "cancel_label should be 返回 when not already set")
  end)

  it("decorate_followup non-repeatable no cancel", function()
    local spec = {}
    local meta = { phase = "unknown_non_repeatable", resume_next_state = "x", resume_next_args = nil }
    phase_module.decorate_followup_choice_spec(spec, meta)
    _assert_eq(spec.allow_cancel, nil, "non-repeatable phase should not set allow_cancel")
  end)

  it("decorate_followup preserves existing cancel_label", function()
    local spec = { cancel_label = "custom" }
    local meta = { phase = "pre_move", resume_next_state = "x", resume_next_args = nil }
    phase_module.decorate_followup_choice_spec(spec, meta)
    _assert_eq(spec.cancel_label, "custom", "existing cancel_label should be preserved")
  end)

  it("decorate_followup non-table spec returns spec", function()
    local result = phase_module.decorate_followup_choice_spec("not_a_table", {})
    _assert_eq(result, "not_a_table", "non-table spec should be returned unchanged")
  end)

  it("decorate_followup nil meta returns spec", function()
    local spec = { data = true }
    local result = phase_module.decorate_followup_choice_spec(spec, nil)
    _assert_eq(result, spec, "nil meta should return spec unchanged")
  end)
end)
