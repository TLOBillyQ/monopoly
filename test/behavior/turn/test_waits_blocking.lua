-- waits.blocking 深模块直测:next_wait_state(等待路由,主测面) + current_block(卡在什么上)。
-- next_wait_state 的判定矩阵复刻自 land_resolve_spec(迁移零漂移的锚),
-- current_block 逐 phase kind 钉死。
local blocking = require("src.turn.waits.blocking")
local support = require("test.support.shared_support")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local lu = require("luaunit")

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

local _config_reset = require("test.support.config_reset")

TestWaitsBlocking = {}

function TestWaitsBlocking:setUp()
  _config_reset.reset_all()
end

function TestWaitsBlocking:tearDown()
  -- 用例内 _teardown 拆了共享端口基线必须装回,否则 mutate 车道窄 suite 子集会撞空端口(#217)
  support.restore_runtime_services()
end

function TestWaitsBlocking:test_no_anim_no_hold_returns_wait_choice()
  _configure_idle(true)
  local game = _make_game()
  local state, args = blocking.next_wait_state(game, "post_action", { player = {} }, false)
  _assert_eq(state, "wait_choice", "no anim/hold -> wait_choice")
  _assert_eq(args.next_state, "post_action", "next_state preserved")
  _teardown()
end

function TestWaitsBlocking:test_anim_no_hold_returns_wait_action_anim()
  _configure_idle(true)
  local game = _make_game({ turn = { action_anim = { kind = "test" } } })
  local state, args = blocking.next_wait_state(game, "move", {}, false)
  _assert_eq(state, "wait_action_anim", "has anim -> wait_action_anim")
  _assert_eq(args.next_state, "wait_choice", "next_state wait_choice via action_anim")
  _teardown()
end

function TestWaitsBlocking:test_no_anim_has_hold_returns_wait_landing_visual()
  _configure_idle(true)
  local game = _make_game({ turn = { landing_visual_hold_active = true } })
  local state = blocking.next_wait_state(game, "post_action", {}, false)
  _assert_eq(state, "wait_landing_visual", "hold -> wait_landing_visual")
  _teardown()
end

function TestWaitsBlocking:test_wait_action_anim_flag_with_no_anim_hold_returns_next_directly()
  _configure_idle(true)
  local game = _make_game()
  local state, args = blocking.next_wait_state(game, "done_state", { val = 42 }, true)
  _assert_eq(state, "done_state", "wait_action_anim=true, no anim/hold -> next_state direct")
  _assert_eq(args.val, 42, "next_args returned")
  _teardown()
end

function TestWaitsBlocking:test_wait_action_anim_flag_with_anim_returns_wait_action_anim_carrying_next()
  _configure_idle(true)
  local game = _make_game({ turn = { action_anim = { kind = "test" } } })
  local state, args = blocking.next_wait_state(game, "post_action", {}, true)
  _assert_eq(state, "wait_action_anim", "anim + wait_action_anim=true -> wait_action_anim")
  _assert_eq(args.next_state, "post_action", "next_state preserved")
  _teardown()
end

function TestWaitsBlocking:test_effects_pending_forces_wait_landing_visual_even_with_no_anim()
  _configure_idle(false)
  local game = _make_game()
  local state = blocking.next_wait_state(game, "post_action", {}, false)
  _assert_eq(state, "wait_landing_visual", "effects pending -> wait_landing_visual")
  _teardown()
end

function TestWaitsBlocking:test_queued_anim_counts_as_has_anim()
  _configure_idle(true)
  local game = _make_game({ turn = { action_anim_queue = { { kind = "queued" } } } })
  local state = blocking.next_wait_state(game, "post_action", {}, false)
  _assert_eq(state, "wait_action_anim", "queued anim -> has_anim")
  _teardown()
end

function TestWaitsBlocking:test_anim_and_hold_routes_through_landing_visual_first_chaining_action_anim()
  _configure_idle(true)
  local game = _make_game({
    turn = { action_anim = { kind = "test" }, landing_visual_hold_active = true },
  })
  local state, args = blocking.next_wait_state(game, "post_action", {}, true)
  _assert_eq(state, "wait_landing_visual", "anim+hold -> landing_visual first")
  _assert_eq(args.next_state, "wait_action_anim", "landing_visual chains into wait_action_anim")
  _teardown()
end

function TestWaitsBlocking:test_wait_move_anim_flag_with_no_anim_hold_returns_wait_move_anim()
  _configure_idle(true)
  local game = _make_game()
  local state, args = blocking.next_wait_state(game, "post_action", { val = 1 }, false, true)
  _assert_eq(state, "wait_move_anim", "wait_move_anim flag -> wait_move_anim")
  _assert_eq(args.next_state, "post_action", "move_anim_args.next_state preserved")
  _teardown()
end

function TestWaitsBlocking:test_wait_move_anim_with_pending_action_anim_routes_through_wait_action_anim_first()
  _configure_idle(true)
  local game = _make_game({ turn = { action_anim = { kind = "chance", seq = 1 } } })
  local state, args = blocking.next_wait_state(game, "move_followup", { mode = "resolve_landing" }, false, true)
  _assert_eq(state, "wait_action_anim", "pending action_anim drains first")
  _assert_eq(args.next_state, "wait_move_anim", "wrapper chains into wait_move_anim")
  _assert_eq(game.turn.move_followup_pending, true, "move_followup target sets pending eagerly")
  _teardown()
end

function TestWaitsBlocking:test_wait_move_anim_with_anim_and_hold_chains_into_action_anim_on_resume()
  local wait_callbacks = require("src.turn.waits.callback_registry")
  _configure_idle(true)
  local game = _make_game({
    turn = {
      action_anim = { kind = "chance", seq = 1 },
      landing_visual_hold_active = true,
    },
  })
  local state, args = blocking.next_wait_state(game, "move_followup", { mode = "resolve_landing" }, false, true)
  _assert_eq(state, "wait_landing_visual", "anim+hold -> landing_visual first")
  _assert_eq(args.next_state, "wait_action_anim", "landing_visual chains into wait_action_anim")
  _assert_eq(args.next_args.next_state, "wait_move_anim",
    "landing_visual 包装内的链条目标必须是 wait_move_anim(L106)")

  local resume = wait_callbacks.take(game, wait_callbacks.callback_keys.after_landing_visual)
  lu.assertEvalToTrue(type(resume) == "function", "landing_visual resume should be registered")
  local next_state, next_args = resume()
  _assert_eq(next_state, "wait_action_anim", "resume should chain into action anim wait")
  _assert_eq(next_args.next_state, "wait_move_anim", "action anim wait should chain into move anim")

  local anim_resume = wait_callbacks.take(game, wait_callbacks.callback_keys.after_action_anim)
  lu.assertEvalToTrue(type(anim_resume) == "function", "action anim resume should be registered")
  local move_state, move_args = anim_resume()
  _assert_eq(move_state, "wait_move_anim", "action anim resume should enter wait_move_anim(L102)")
  _assert_eq(move_args.next_state, "move_followup", "move anim args preserve the target state")
  _teardown()
end

function TestWaitsBlocking:test_wait_move_anim_with_hold_and_no_anim_routes_through_landing_visual()
  _configure_idle(true)
  local game = _make_game({ turn = { landing_visual_hold_active = true } })
  local state, args = blocking.next_wait_state(game, "post_action", { val = 1 }, false, true)
  _assert_eq(state, "wait_landing_visual", "hold without anim -> landing_visual first")
  _assert_eq(args.next_state, "wait_move_anim", "landing_visual chains into wait_move_anim(L114)")
  _assert_eq(args.next_args.next_state, "post_action", "move anim args preserve target")

  local wait_callbacks = require("src.turn.waits.callback_registry")
  local resume = wait_callbacks.take(game, wait_callbacks.callback_keys.after_landing_visual)
  local next_state, next_args = resume()
  _assert_eq(next_state, "wait_move_anim", "hold-only resume should enter wait_move_anim directly")
  _assert_eq(next_args.next_state, "post_action", "hold-only resume preserves target state")
  _teardown()
end

function TestWaitsBlocking:test_move_followup_next_state_sets_move_followup_pending()
  _configure_idle(true)
  local game = _make_game({ turn = { action_anim = { kind = "test" } } })
  blocking.next_wait_state(game, "move_followup", {}, true)
  _assert_eq(game.turn.move_followup_pending, true, "move_followup -> pending flag")
  _teardown()
end

-- 闭合变异: game=nil 防御路径 — _has_action_anim 与 _is_landing_visual_hold_active
-- 的 nil 守卫在 or→and / false→true 突变下被绕开,须有测试证明 nil game 仍返回 wait_choice。
function TestWaitsBlocking:test_nil_game_returns_wait_choice()
  _configure_idle(true)
  local state = blocking.next_wait_state(nil, "post_action", {}, false)
  _assert_eq(state, "wait_choice", "nil game -> wait_choice")
  _teardown()
end

-- 闭合变异: game ~= nil 但 game.turn == nil — or→and 突变会让 _has_action_anim
-- 的「not game.turn」被 and 吃掉,不进入 early return 后撞 nil.action_anim。
function TestWaitsBlocking:test_game_without_turn_returns_wait_choice()
  _configure_idle(true)
  local state = blocking.next_wait_state({}, "post_action", {}, false)
  _assert_eq(state, "wait_choice", "no turn -> wait_choice")
  _teardown()
end

-- 闭合变异: 有 anim 且 hold 活跃但不设 wait_action_anim/wait_move_anim flag,
-- 走 _route_choice_wait_state → _wait_for_choice_via_landing_visual_then_action_anim,
-- 返回 wait_landing_visual 串联 wait_action_anim。
function TestWaitsBlocking:test_anim_and_hold_via_choice_routing_chains_landing_visual_into_action_anim()
  _configure_idle(true)
  local game = _make_game({
    turn = { action_anim = { kind = "test" }, landing_visual_hold_active = true },
  })
  -- 不传 wait_action_anim / wait_move_anim,走 _route_choice_wait_state
  local state, args = blocking.next_wait_state(game, "post_action", {}, false, false)
  _assert_eq(state, "wait_landing_visual", "anim+hold via choice routing -> landing_visual first")
  _assert_eq(args.next_state, "wait_action_anim", "landing_visual chains into wait_action_anim")

  -- L95 闭包内第二段 _wait_for_choice_via_action_anim 换 nil:resume 必须仍链条进 wait_action_anim
  local wait_callbacks = require("src.turn.waits.callback_registry")
  local resume = wait_callbacks.take(game, wait_callbacks.callback_keys.after_landing_visual)
  local next_state, next_args = resume()
  _assert_eq(next_state, "wait_action_anim", "choice-routing resume should chain into action anim wait")
  _assert_eq(next_args.next_state, "wait_choice", "action anim wait should chain back into wait_choice")
  _teardown()
end

-- 闭合变异: game.landing_visual_hold_state 非 nil 且 source 非 nil 时,
-- _is_landing_visual_hold_active 走 runtime_state 路径而不是 turn flag 路径。
function TestWaitsBlocking:test_landing_visual_hold_state_with_active_source_forces_wait_landing_visual()
  _configure_idle(true)
  local runtime_state = require("src.state.runtime")
  local hold_state = {}
  -- 注入 runtime_state 桩:source 非 nil → 走 runtime_state 分支
  local orig_source = runtime_state.get_landing_visual_hold_source
  local orig_active = runtime_state.get_landing_visual_hold_active
  runtime_state.get_landing_visual_hold_source = function(state)
    return state.source
  end
  runtime_state.get_landing_visual_hold_active = function(state)
    return state.active
  end
  hold_state.source = "some_source"
  hold_state.active = true

  local game = _make_game()
  game.landing_visual_hold_state = hold_state

  local state = blocking.next_wait_state(game, "post_action", {}, false)
  _assert_eq(state, "wait_landing_visual", "active hold via runtime_state -> wait_landing_visual")

  runtime_state.get_landing_visual_hold_source = orig_source
  runtime_state.get_landing_visual_hold_active = orig_active
  _teardown()
end

function TestWaitsBlocking:test_returns_nil_when_turn_is_not_parked_in_a_wait_phase()
  _assert_eq(blocking.current_block(_make_game({ turn = { phase = "roll" } })), nil, "roll -> nil")
  _assert_eq(blocking.current_block(_make_game({ turn = {} })), nil, "no phase -> nil")
  _assert_eq(blocking.current_block(_make_game()), nil, "empty turn -> nil")
end

function TestWaitsBlocking:test_maps_wait_landing_visual_phase_to_landing_visual_kind()
  local block = blocking.current_block(_make_game({ turn = { phase = "wait_landing_visual" } }))
  _assert_eq(block and block.kind, "landing_visual", "wait_landing_visual -> landing_visual")
end

function TestWaitsBlocking:test_maps_the_anim_move_choice_action_wait_phases_to_their_kinds()
  _assert_eq(blocking.current_block(_make_game({ turn = { phase = "wait_action_anim" } })).kind, "action_anim", "action_anim")
  _assert_eq(blocking.current_block(_make_game({ turn = { phase = "wait_move_anim" } })).kind, "move_anim", "move_anim")
  _assert_eq(blocking.current_block(_make_game({ turn = { phase = "wait_choice" } })).kind, "choice", "choice")
  _assert_eq(blocking.current_block(_make_game({ turn = { phase = "wait_action" } })).kind, "action", "action")
end


return TestWaitsBlocking
