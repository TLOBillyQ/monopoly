-- waits.blocking 深模块直测:next_wait_state(等待路由,主测面) + current_block(卡在什么上)。
-- next_wait_state 的判定矩阵复刻自 land_resolve_spec(迁移零漂移的锚),
-- current_block 逐 phase kind 钉死。
local blocking = require("src.turn.waits.blocking")
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

describe("turn.waits.blocking", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  describe("next_wait_state", function()
    it("no anim no hold returns wait_choice", function()
      _configure_idle(true)
      local game = _make_game()
      local state, args = blocking.next_wait_state(game, "post_action", { player = {} }, false)
      _assert_eq(state, "wait_choice", "no anim/hold -> wait_choice")
      _assert_eq(args.next_state, "post_action", "next_state preserved")
      _teardown()
    end)

    it("anim no hold returns wait_action_anim", function()
      _configure_idle(true)
      local game = _make_game({ turn = { action_anim = { kind = "test" } } })
      local state, args = blocking.next_wait_state(game, "move", {}, false)
      _assert_eq(state, "wait_action_anim", "has anim -> wait_action_anim")
      _assert_eq(args.next_state, "wait_choice", "next_state wait_choice via action_anim")
      _teardown()
    end)

    it("no anim has hold returns wait_landing_visual", function()
      _configure_idle(true)
      local game = _make_game({ turn = { landing_visual_hold_active = true } })
      local state = blocking.next_wait_state(game, "post_action", {}, false)
      _assert_eq(state, "wait_landing_visual", "hold -> wait_landing_visual")
      _teardown()
    end)

    it("wait_action_anim flag with no anim/hold returns next directly", function()
      _configure_idle(true)
      local game = _make_game()
      local state, args = blocking.next_wait_state(game, "done_state", { val = 42 }, true)
      _assert_eq(state, "done_state", "wait_action_anim=true, no anim/hold -> next_state direct")
      _assert_eq(args.val, 42, "next_args returned")
      _teardown()
    end)

    it("wait_action_anim flag with anim returns wait_action_anim carrying next", function()
      _configure_idle(true)
      local game = _make_game({ turn = { action_anim = { kind = "test" } } })
      local state, args = blocking.next_wait_state(game, "post_action", {}, true)
      _assert_eq(state, "wait_action_anim", "anim + wait_action_anim=true -> wait_action_anim")
      _assert_eq(args.next_state, "post_action", "next_state preserved")
      _teardown()
    end)

    it("effects_pending forces wait_landing_visual even with no anim", function()
      _configure_idle(false)
      local game = _make_game()
      local state = blocking.next_wait_state(game, "post_action", {}, false)
      _assert_eq(state, "wait_landing_visual", "effects pending -> wait_landing_visual")
      _teardown()
    end)

    it("queued anim counts as has_anim", function()
      _configure_idle(true)
      local game = _make_game({ turn = { action_anim_queue = { { kind = "queued" } } } })
      local state = blocking.next_wait_state(game, "post_action", {}, false)
      _assert_eq(state, "wait_action_anim", "queued anim -> has_anim")
      _teardown()
    end)

    it("anim and hold routes through landing_visual first, chaining action_anim", function()
      _configure_idle(true)
      local game = _make_game({
        turn = { action_anim = { kind = "test" }, landing_visual_hold_active = true },
      })
      local state, args = blocking.next_wait_state(game, "post_action", {}, true)
      _assert_eq(state, "wait_landing_visual", "anim+hold -> landing_visual first")
      _assert_eq(args.next_state, "wait_action_anim", "landing_visual chains into wait_action_anim")
      _teardown()
    end)

    it("wait_move_anim flag with no anim/hold returns wait_move_anim", function()
      _configure_idle(true)
      local game = _make_game()
      local state, args = blocking.next_wait_state(game, "post_action", { val = 1 }, false, true)
      _assert_eq(state, "wait_move_anim", "wait_move_anim flag -> wait_move_anim")
      _assert_eq(args.next_state, "post_action", "move_anim_args.next_state preserved")
      _teardown()
    end)

    it("wait_move_anim with pending action_anim routes through wait_action_anim first", function()
      _configure_idle(true)
      local game = _make_game({ turn = { action_anim = { kind = "chance", seq = 1 } } })
      local state, args = blocking.next_wait_state(game, "move_followup", { mode = "resolve_landing" }, false, true)
      _assert_eq(state, "wait_action_anim", "pending action_anim drains first")
      _assert_eq(args.next_state, "wait_move_anim", "wrapper chains into wait_move_anim")
      _assert_eq(game.turn.move_followup_pending, true, "move_followup target sets pending eagerly")
      _teardown()
    end)

    it("move_followup next_state sets move_followup_pending", function()
      _configure_idle(true)
      local game = _make_game({ turn = { action_anim = { kind = "test" } } })
      blocking.next_wait_state(game, "move_followup", {}, true)
      _assert_eq(game.turn.move_followup_pending, true, "move_followup -> pending flag")
      _teardown()
    end)
  end)

  describe("current_block", function()
    it("returns nil when turn is not parked in a wait phase", function()
      _assert_eq(blocking.current_block(_make_game({ turn = { phase = "roll" } })), nil, "roll -> nil")
      _assert_eq(blocking.current_block(_make_game({ turn = {} })), nil, "no phase -> nil")
      _assert_eq(blocking.current_block(_make_game()), nil, "empty turn -> nil")
    end)

    it("maps wait_landing_visual phase to landing_visual kind", function()
      local block = blocking.current_block(_make_game({ turn = { phase = "wait_landing_visual" } }))
      _assert_eq(block and block.kind, "landing_visual", "wait_landing_visual -> landing_visual")
    end)

    it("maps the anim/move/choice/action wait phases to their kinds", function()
      _assert_eq(blocking.current_block(_make_game({ turn = { phase = "wait_action_anim" } })).kind, "action_anim", "action_anim")
      _assert_eq(blocking.current_block(_make_game({ turn = { phase = "wait_move_anim" } })).kind, "move_anim", "move_anim")
      _assert_eq(blocking.current_block(_make_game({ turn = { phase = "wait_choice" } })).kind, "choice", "choice")
      _assert_eq(blocking.current_block(_make_game({ turn = { phase = "wait_action" } })).kind, "action", "action")
    end)
  end)
end)
