-- 原生 LuaUnit 改写：describe 拍平为 Test* 类，before_each → setUp、
-- after_each → tearDown（17 例），语句位裸 assert(cond, msg) → lu.assertEvalToTrue。
local lu = require("luaunit")
local support = require("test.support.shared_support")
local land_resolve = require("src.turn.phases.land")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local _config_reset = require("test.support.config_reset")

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

TestLandResolve = {}

function TestLandResolve:setUp()
  _config_reset.reset_all()
end

function TestLandResolve:tearDown()
  -- 各用例结尾的 _teardown() 把共享端口基线拆到未配置态,必须装回,
  -- 否则 mutate 车道窄 suite 子集会撞空端口(#217)。
  support.restore_runtime_services()
end

function TestLandResolve:test_resolve_wait_state_no_anim_no_hold_returns_wait_choice()
  _configure_idle(true)
  local game = _make_game()
  local state, args = land_resolve.resolve_wait_state(game, "post_action", { player = {} }, false)
  _assert_eq(state, "wait_choice", "should return wait_choice with no anim/hold")
  _assert_eq(args.next_state, "post_action", "next_state should be post_action")
  _teardown()
end

function TestLandResolve:test_resolve_wait_state_anim_no_hold_returns_wait_action_anim()
  _configure_idle(true)
  local game = _make_game({ turn = { action_anim = { kind = "test" } } })
  local state, args = land_resolve.resolve_wait_state(game, "move", {}, false)
  _assert_eq(state, "wait_action_anim", "has anim should return wait_action_anim state")
  _assert_eq(args.next_state, "wait_choice", "next_state should be wait_choice (via action_anim)")
  _teardown()
end

function TestLandResolve:test_resolve_wait_state_no_anim_has_hold_returns_wait_landing_visual()
  _configure_idle(true)
  local game = _make_game({ turn = { landing_visual_hold_active = true } })
  local state, args = land_resolve.resolve_wait_state(game, "post_action", {}, false)
  _assert_eq(state, "wait_landing_visual", "has hold should return wait_landing_visual state")
  _assert_eq(args.next_state, "wait_choice", "next_state should be wait_choice via landing_visual")
  _teardown()
end

function TestLandResolve:test_resolve_wait_state_anim_and_hold_returns_wait_landing_visual()
  _configure_idle(true)
  local game = _make_game({
    turn = { action_anim = { kind = "test" }, landing_visual_hold_active = true },
  })
  local state, _ = land_resolve.resolve_wait_state(game, "post_action", {}, false)
  _assert_eq(state, "wait_landing_visual", "anim+hold should return wait_landing_visual first")
  _teardown()
end

function TestLandResolve:test_resolve_wait_state_wait_anim_no_anim_no_hold_returns_next()
  _configure_idle(true)
  local game = _make_game()
  local state, args = land_resolve.resolve_wait_state(game, "done_state", { val = 42 }, true)
  _assert_eq(state, "done_state", "no anim+hold with wait_action_anim=true should return next_state directly")
  _assert_eq(args.val, 42, "next_args should be returned")
  _teardown()
end

function TestLandResolve:test_resolve_wait_state_wait_anim_has_anim_returns_wait_action_anim()
  _configure_idle(true)
  local game = _make_game({ turn = { action_anim = { kind = "test" } } })
  local state, args = land_resolve.resolve_wait_state(game, "post_action", {}, true)
  _assert_eq(state, "wait_action_anim", "has anim with wait_action_anim=true should return wait_action_anim")
  _assert_eq(args.next_state, "post_action", "next_state should be post_action")
  _teardown()
end

function TestLandResolve:test_resolve_wait_state_wait_anim_no_anim_has_hold_returns_wait_landing_visual()
  _configure_idle(true)
  local game = _make_game({ turn = { landing_visual_hold_active = true } })
  local state, args = land_resolve.resolve_wait_state(game, "post_action", {}, true)
  _assert_eq(state, "wait_landing_visual", "has hold with wait_action_anim=true should return wait_landing_visual")
  _assert_eq(args.next_state, "post_action", "next_state should be post_action")
  _teardown()
end

function TestLandResolve:test_resolve_wait_state_wait_anim_anim_and_hold_returns_wait_landing_visual()
  _configure_idle(true)
  local game = _make_game({
    turn = { action_anim = { kind = "test" }, landing_visual_hold_active = true },
  })
  local state, _ = land_resolve.resolve_wait_state(game, "post_action", {}, true)
  _assert_eq(state, "wait_landing_visual", "anim+hold with wait_action_anim=true returns wait_landing_visual first")
  _teardown()
end

function TestLandResolve:test_resolve_wait_state_effects_pending_no_anim_returns_wait_landing_visual()
  _configure_idle(false)
  local game = _make_game()
  local state, _ = land_resolve.resolve_wait_state(game, "post_action", {}, false)
  _assert_eq(state, "wait_landing_visual", "effects_pending should cause wait_landing_visual")
  _teardown()
end

function TestLandResolve:test_resolve_wait_state_effects_pending_wait_anim_no_anim_returns_wait_landing_visual()
  _configure_idle(false)
  local game = _make_game()
  local state, _ = land_resolve.resolve_wait_state(game, "post_action", {}, true)
  _assert_eq(state, "wait_landing_visual", "effects_pending with wait_action_anim=true returns wait_landing_visual")
  _teardown()
end

function TestLandResolve:test_resolve_wait_state_queued_anim_counts_as_has_anim()
  _configure_idle(true)
  local game = _make_game({
    turn = { action_anim_queue = { { kind = "queued" } } },
  })
  local state, _ = land_resolve.resolve_wait_state(game, "post_action", {}, false)
  _assert_eq(state, "wait_action_anim", "queued anim should count as has_anim")
  _teardown()
end

function TestLandResolve:test_resolve_wait_state_move_followup_next_state_sets_pending()
  _configure_idle(true)
  local game = _make_game({ turn = { action_anim = { kind = "test" } } })
  land_resolve.resolve_wait_state(game, "move_followup", {}, true)
  _assert_eq(game.turn.move_followup_pending, true, "move_followup next_state should set move_followup_pending")
  _teardown()
end

function TestLandResolve:test_resolve_wait_state_wait_move_anim_no_anim_no_hold_returns_wait_move_anim()
  _configure_idle(true)
  local game = _make_game()
  local state, args = land_resolve.resolve_wait_state(game, "post_action", { val = 1 }, false, true)
  _assert_eq(state, "wait_move_anim", "no anim+hold with wait_move_anim=true should return wait_move_anim")
  _assert_eq(args.next_state, "post_action", "move_anim_args.next_state preserved")
  _teardown()
end

function TestLandResolve:test_resolve_wait_state_wait_move_anim_no_anim_has_hold_returns_wait_landing_visual()
  _configure_idle(true)
  local game = _make_game({ turn = { landing_visual_hold_active = true } })
  local state, _ = land_resolve.resolve_wait_state(game, "post_action", {}, false, true)
  _assert_eq(state, "wait_landing_visual", "no anim, has hold with wait_move_anim=true should return wait_landing_visual")
  _teardown()
end

function TestLandResolve:test_resolve_wait_state_wait_move_anim_has_anim_no_hold_returns_wait_action_anim_and_resume_callback_returns_wait_move_anim()
  _configure_idle(true)
  local wait_callbacks = require("src.turn.waits.callback_registry")
  local game = _make_game({ turn = { action_anim = { kind = "test" } } })
  local state, _ = land_resolve.resolve_wait_state(game, "post_action", {}, false, true)
  _assert_eq(state, "wait_action_anim", "has anim, no hold with wait_move_anim=true should return wait_action_anim")
  local cb = wait_callbacks.peek(game, "after_action_anim")
  lu.assertEvalToTrue(type(cb) == "function", "should have registered after_action_anim callback")
  local cb_state, cb_args = cb()
  _assert_eq(cb_state, "wait_move_anim", "resume callback should return wait_move_anim state")
  _assert_eq(cb_args.next_state, "post_action", "resume callback move_anim_args.next_state preserved")
  _teardown()
end

function TestLandResolve:test_resolve_wait_state_wait_move_anim_has_anim_has_hold_returns_wait_landing_visual()
  _configure_idle(true)
  local game = _make_game({
    turn = { action_anim = { kind = "test" }, landing_visual_hold_active = true },
  })
  local state, _ = land_resolve.resolve_wait_state(game, "post_action", {}, false, true)
  _assert_eq(state, "wait_landing_visual", "has anim+hold with wait_move_anim=true should return wait_landing_visual first")
  _teardown()
end

function TestLandResolve:test_resolve_wait_state_wait_move_anim_move_followup_sets_pending_flag()
  _configure_idle(true)
  local game = _make_game()
  land_resolve.resolve_wait_state(game, "move_followup", {}, false, true)
  _assert_eq(game.turn.move_followup_pending, true, "wait_move_anim + move_followup next_state should set pending flag")
  _teardown()
end


return TestLandResolve
