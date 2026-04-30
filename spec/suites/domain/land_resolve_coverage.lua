local land_resolve = require("src.turn.phases.land.resolve")
local runtime_ports = require("src.foundation.ports.runtime_ports")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _make_game(opts)
  opts = opts or {}
  return {
    turn = opts.turn or {},
    dirty = opts.dirty or { any = false, turn = false },
    wait_callback_runtime = opts.wait_callback_runtime,
  }
end

local function _configure_idle(idle)
  runtime_ports.configure({ is_effect_idle = function() return idle end })
end

local function _teardown()
  runtime_ports.reset_for_tests()
end

-- resolve_wait_state: no anim, no hold, effects idle, wait_action_anim=false → wait_choice

local function test_resolve_wait_state_no_anim_no_hold_returns_wait_choice()
  _configure_idle(true)
  local game = _make_game()
  local state, args = land_resolve.resolve_wait_state(game, "post_action", { player = {} }, false)
  _assert_eq(state, "wait_choice", "should return wait_choice with no anim/hold")
  _assert_eq(args.next_state, "post_action", "next_state should be post_action")
  _teardown()
end

-- resolve_wait_state: has anim, no hold, effects idle, wait_action_anim=false → wait_action_anim

local function test_resolve_wait_state_anim_no_hold_returns_wait_action_anim()
  _configure_idle(true)
  local game = _make_game({ turn = { action_anim = { kind = "test" } } })
  local state, args = land_resolve.resolve_wait_state(game, "move", {}, false)
  _assert_eq(state, "wait_action_anim", "has anim should return wait_action_anim state")
  _assert_eq(args.next_state, "wait_choice", "next_state should be wait_choice (via action_anim)")
  _teardown()
end

-- resolve_wait_state: no anim, has hold, wait_action_anim=false → wait_landing_visual

local function test_resolve_wait_state_no_anim_has_hold_returns_wait_landing_visual()
  _configure_idle(true)
  local game = _make_game({ turn = { landing_visual_hold_active = true } })
  local state, args = land_resolve.resolve_wait_state(game, "post_action", {}, false)
  _assert_eq(state, "wait_landing_visual", "has hold should return wait_landing_visual state")
  _assert_eq(args.next_state, "wait_choice", "next_state should be wait_choice via landing_visual")
  _teardown()
end

-- resolve_wait_state: has anim, has hold, wait_action_anim=false → wait_landing_visual (via landing+anim chain)

local function test_resolve_wait_state_anim_and_hold_returns_wait_landing_visual()
  _configure_idle(true)
  local game = _make_game({
    turn = { action_anim = { kind = "test" }, landing_visual_hold_active = true },
  })
  local state, _ = land_resolve.resolve_wait_state(game, "post_action", {}, false)
  _assert_eq(state, "wait_landing_visual", "anim+hold should return wait_landing_visual first")
  _teardown()
end

-- resolve_wait_state: wait_action_anim=true, no anim, no hold → returns next_state directly

local function test_resolve_wait_state_wait_anim_no_anim_no_hold_returns_next()
  _configure_idle(true)
  local game = _make_game()
  local state, args = land_resolve.resolve_wait_state(game, "done_state", { val = 42 }, true)
  _assert_eq(state, "done_state", "no anim+hold with wait_action_anim=true should return next_state directly")
  _assert_eq(args.val, 42, "next_args should be returned")
  _teardown()
end

-- resolve_wait_state: wait_action_anim=true, has anim, no hold → wait_action_anim via callback

local function test_resolve_wait_state_wait_anim_has_anim_returns_wait_action_anim()
  _configure_idle(true)
  local game = _make_game({ turn = { action_anim = { kind = "test" } } })
  local state, args = land_resolve.resolve_wait_state(game, "post_action", {}, true)
  _assert_eq(state, "wait_action_anim", "has anim with wait_action_anim=true should return wait_action_anim")
  _assert_eq(args.next_state, "post_action", "next_state should be post_action")
  _teardown()
end

-- resolve_wait_state: wait_action_anim=true, no anim, has hold → wait_landing_visual

local function test_resolve_wait_state_wait_anim_no_anim_has_hold_returns_wait_landing_visual()
  _configure_idle(true)
  local game = _make_game({ turn = { landing_visual_hold_active = true } })
  local state, args = land_resolve.resolve_wait_state(game, "post_action", {}, true)
  _assert_eq(state, "wait_landing_visual", "has hold with wait_action_anim=true should return wait_landing_visual")
  _assert_eq(args.next_state, "post_action", "next_state should be post_action")
  _teardown()
end

-- resolve_wait_state: wait_action_anim=true, has anim, has hold → wait_landing_visual then wait_action_anim

local function test_resolve_wait_state_wait_anim_anim_and_hold_returns_wait_landing_visual()
  _configure_idle(true)
  local game = _make_game({
    turn = { action_anim = { kind = "test" }, landing_visual_hold_active = true },
  })
  local state, _ = land_resolve.resolve_wait_state(game, "post_action", {}, true)
  _assert_eq(state, "wait_landing_visual", "anim+hold with wait_action_anim=true returns wait_landing_visual first")
  _teardown()
end

-- resolve_wait_state: effects_pending (not idle) + no anim → wait_landing_visual

local function test_resolve_wait_state_effects_pending_no_anim_returns_wait_landing_visual()
  _configure_idle(false)
  local game = _make_game()
  local state, _ = land_resolve.resolve_wait_state(game, "post_action", {}, false)
  _assert_eq(state, "wait_landing_visual", "effects_pending should cause wait_landing_visual")
  _teardown()
end

-- resolve_wait_state: effects_pending + wait_action_anim=true, no anim → wait_landing_visual

local function test_resolve_wait_state_effects_pending_wait_anim_no_anim_returns_wait_landing_visual()
  _configure_idle(false)
  local game = _make_game()
  local state, _ = land_resolve.resolve_wait_state(game, "post_action", {}, true)
  _assert_eq(state, "wait_landing_visual", "effects_pending with wait_action_anim=true returns wait_landing_visual")
  _teardown()
end

-- action_anim queue also counts as has_anim

local function test_resolve_wait_state_queued_anim_counts_as_has_anim()
  _configure_idle(true)
  local game = _make_game({
    turn = { action_anim_queue = { { kind = "queued" } } },
  })
  local state, _ = land_resolve.resolve_wait_state(game, "post_action", {}, false)
  _assert_eq(state, "wait_action_anim", "queued anim should count as has_anim")
  _teardown()
end

-- _register_action_anim_resume: move_followup sets pending flag

local function test_resolve_wait_state_move_followup_next_state_sets_pending()
  _configure_idle(true)
  local game = _make_game({ turn = { action_anim = { kind = "test" } } })
  land_resolve.resolve_wait_state(game, "move_followup", {}, true)
  _assert_eq(game.turn.move_followup_pending, true, "move_followup next_state should set move_followup_pending")
  _teardown()
end

return {
  name = "domain land resolve coverage",
  tests = {
    { name = "resolve_wait_state no anim no hold returns wait_choice", run = test_resolve_wait_state_no_anim_no_hold_returns_wait_choice },
    { name = "resolve_wait_state anim no hold returns wait_action_anim", run = test_resolve_wait_state_anim_no_hold_returns_wait_action_anim },
    { name = "resolve_wait_state no anim has hold returns wait_landing_visual", run = test_resolve_wait_state_no_anim_has_hold_returns_wait_landing_visual },
    { name = "resolve_wait_state anim and hold returns wait_landing_visual", run = test_resolve_wait_state_anim_and_hold_returns_wait_landing_visual },
    { name = "resolve_wait_state wait_anim no anim no hold returns next", run = test_resolve_wait_state_wait_anim_no_anim_no_hold_returns_next },
    { name = "resolve_wait_state wait_anim has anim returns wait_action_anim", run = test_resolve_wait_state_wait_anim_has_anim_returns_wait_action_anim },
    { name = "resolve_wait_state wait_anim no anim has hold returns wait_landing_visual", run = test_resolve_wait_state_wait_anim_no_anim_has_hold_returns_wait_landing_visual },
    { name = "resolve_wait_state wait_anim anim and hold returns wait_landing_visual", run = test_resolve_wait_state_wait_anim_anim_and_hold_returns_wait_landing_visual },
    { name = "resolve_wait_state effects_pending no anim returns wait_landing_visual", run = test_resolve_wait_state_effects_pending_no_anim_returns_wait_landing_visual },
    { name = "resolve_wait_state effects_pending wait_anim no anim returns wait_landing_visual", run = test_resolve_wait_state_effects_pending_wait_anim_no_anim_returns_wait_landing_visual },
    { name = "resolve_wait_state queued anim counts as has_anim", run = test_resolve_wait_state_queued_anim_counts_as_has_anim },
    { name = "resolve_wait_state move_followup next_state sets pending", run = test_resolve_wait_state_move_followup_next_state_sets_pending },
  },
}
