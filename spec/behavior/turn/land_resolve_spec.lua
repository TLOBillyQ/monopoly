local land_resolve = require("src.turn.phases.land")
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

describe("domain land resolve coverage", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("resolve_wait_state no anim no hold returns wait_choice", function()
    _configure_idle(true)
    local game = _make_game()
    local state, args = land_resolve.resolve_wait_state(game, "post_action", { player = {} }, false)
    _assert_eq(state, "wait_choice", "should return wait_choice with no anim/hold")
    _assert_eq(args.next_state, "post_action", "next_state should be post_action")
    _teardown()
  end)

  it("resolve_wait_state anim no hold returns wait_action_anim", function()
    _configure_idle(true)
    local game = _make_game({ turn = { action_anim = { kind = "test" } } })
    local state, args = land_resolve.resolve_wait_state(game, "move", {}, false)
    _assert_eq(state, "wait_action_anim", "has anim should return wait_action_anim state")
    _assert_eq(args.next_state, "wait_choice", "next_state should be wait_choice (via action_anim)")
    _teardown()
  end)

  it("resolve_wait_state no anim has hold returns wait_landing_visual", function()
    _configure_idle(true)
    local game = _make_game({ turn = { landing_visual_hold_active = true } })
    local state, args = land_resolve.resolve_wait_state(game, "post_action", {}, false)
    _assert_eq(state, "wait_landing_visual", "has hold should return wait_landing_visual state")
    _assert_eq(args.next_state, "wait_choice", "next_state should be wait_choice via landing_visual")
    _teardown()
  end)

  it("resolve_wait_state anim and hold returns wait_landing_visual", function()
    _configure_idle(true)
    local game = _make_game({
      turn = { action_anim = { kind = "test" }, landing_visual_hold_active = true },
    })
    local state, _ = land_resolve.resolve_wait_state(game, "post_action", {}, false)
    _assert_eq(state, "wait_landing_visual", "anim+hold should return wait_landing_visual first")
    _teardown()
  end)

  it("resolve_wait_state wait_anim no anim no hold returns next", function()
    _configure_idle(true)
    local game = _make_game()
    local state, args = land_resolve.resolve_wait_state(game, "done_state", { val = 42 }, true)
    _assert_eq(state, "done_state", "no anim+hold with wait_action_anim=true should return next_state directly")
    _assert_eq(args.val, 42, "next_args should be returned")
    _teardown()
  end)

  it("resolve_wait_state wait_anim has anim returns wait_action_anim", function()
    _configure_idle(true)
    local game = _make_game({ turn = { action_anim = { kind = "test" } } })
    local state, args = land_resolve.resolve_wait_state(game, "post_action", {}, true)
    _assert_eq(state, "wait_action_anim", "has anim with wait_action_anim=true should return wait_action_anim")
    _assert_eq(args.next_state, "post_action", "next_state should be post_action")
    _teardown()
  end)

  it("resolve_wait_state wait_anim no anim has hold returns wait_landing_visual", function()
    _configure_idle(true)
    local game = _make_game({ turn = { landing_visual_hold_active = true } })
    local state, args = land_resolve.resolve_wait_state(game, "post_action", {}, true)
    _assert_eq(state, "wait_landing_visual", "has hold with wait_action_anim=true should return wait_landing_visual")
    _assert_eq(args.next_state, "post_action", "next_state should be post_action")
    _teardown()
  end)

  it("resolve_wait_state wait_anim anim and hold returns wait_landing_visual", function()
    _configure_idle(true)
    local game = _make_game({
      turn = { action_anim = { kind = "test" }, landing_visual_hold_active = true },
    })
    local state, _ = land_resolve.resolve_wait_state(game, "post_action", {}, true)
    _assert_eq(state, "wait_landing_visual", "anim+hold with wait_action_anim=true returns wait_landing_visual first")
    _teardown()
  end)

  it("resolve_wait_state effects_pending no anim returns wait_landing_visual", function()
    _configure_idle(false)
    local game = _make_game()
    local state, _ = land_resolve.resolve_wait_state(game, "post_action", {}, false)
    _assert_eq(state, "wait_landing_visual", "effects_pending should cause wait_landing_visual")
    _teardown()
  end)

  it("resolve_wait_state effects_pending wait_anim no anim returns wait_landing_visual", function()
    _configure_idle(false)
    local game = _make_game()
    local state, _ = land_resolve.resolve_wait_state(game, "post_action", {}, true)
    _assert_eq(state, "wait_landing_visual", "effects_pending with wait_action_anim=true returns wait_landing_visual")
    _teardown()
  end)

  it("resolve_wait_state queued anim counts as has_anim", function()
    _configure_idle(true)
    local game = _make_game({
      turn = { action_anim_queue = { { kind = "queued" } } },
    })
    local state, _ = land_resolve.resolve_wait_state(game, "post_action", {}, false)
    _assert_eq(state, "wait_action_anim", "queued anim should count as has_anim")
    _teardown()
  end)

  it("resolve_wait_state move_followup next_state sets pending", function()
    _configure_idle(true)
    local game = _make_game({ turn = { action_anim = { kind = "test" } } })
    land_resolve.resolve_wait_state(game, "move_followup", {}, true)
    _assert_eq(game.turn.move_followup_pending, true, "move_followup next_state should set move_followup_pending")
    _teardown()
  end)

  it("resolve_wait_state wait_move_anim no anim no hold returns wait_move_anim", function()
    _configure_idle(true)
    local game = _make_game()
    local state, args = land_resolve.resolve_wait_state(game, "post_action", { val = 1 }, false, true)
    _assert_eq(state, "wait_move_anim", "no anim+hold with wait_move_anim=true should return wait_move_anim")
    _assert_eq(args.next_state, "post_action", "move_anim_args.next_state preserved")
    _teardown()
  end)

  it("resolve_wait_state wait_move_anim no anim has hold returns wait_landing_visual", function()
    _configure_idle(true)
    local game = _make_game({ turn = { landing_visual_hold_active = true } })
    local state, _ = land_resolve.resolve_wait_state(game, "post_action", {}, false, true)
    _assert_eq(state, "wait_landing_visual", "no anim, has hold with wait_move_anim=true should return wait_landing_visual")
    _teardown()
  end)

  it("resolve_wait_state wait_move_anim has anim no hold returns wait_action_anim and resume callback returns wait_move_anim", function()
    _configure_idle(true)
    local wait_callbacks = require("src.turn.waits.callback_registry")
    local game = _make_game({ turn = { action_anim = { kind = "test" } } })
    local state, _ = land_resolve.resolve_wait_state(game, "post_action", {}, false, true)
    _assert_eq(state, "wait_action_anim", "has anim, no hold with wait_move_anim=true should return wait_action_anim")
    local cb = wait_callbacks.peek(game, "after_action_anim")
    assert(type(cb) == "function", "should have registered after_action_anim callback")
    local cb_state, cb_args = cb()
    _assert_eq(cb_state, "wait_move_anim", "resume callback should return wait_move_anim state")
    _assert_eq(cb_args.next_state, "post_action", "resume callback move_anim_args.next_state preserved")
    _teardown()
  end)

  it("resolve_wait_state wait_move_anim has anim has hold returns wait_landing_visual", function()
    _configure_idle(true)
    local game = _make_game({
      turn = { action_anim = { kind = "test" }, landing_visual_hold_active = true },
    })
    local state, _ = land_resolve.resolve_wait_state(game, "post_action", {}, false, true)
    _assert_eq(state, "wait_landing_visual", "has anim+hold with wait_move_anim=true should return wait_landing_visual first")
    _teardown()
  end)

  it("resolve_wait_state wait_move_anim move_followup sets pending flag", function()
    _configure_idle(true)
    local game = _make_game()
    land_resolve.resolve_wait_state(game, "move_followup", {}, false, true)
    _assert_eq(game.turn.move_followup_pending, true, "wait_move_anim + move_followup next_state should set pending flag")
    _teardown()
  end)
end)
