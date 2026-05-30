local runtime_ports = require("src.foundation.ports.runtime_ports")
local timing = require("src.config.gameplay.timing")
local wait_callbacks = require("src.turn.waits.callback_registry")

local function _eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _reload_await()
  package.loaded["src.turn.waits.await"] = nil
  return require("src.turn.waits.await")
end

local function _make_session(opts)
  opts = opts or {}
  local s = {
    game = opts.game,
    choice_elapsed_seconds = opts.choice_elapsed_seconds,
    _seconds_wait = opts._seconds_wait or {},
    _phase = nil,
    _cleared = false,
    _pending_actions = opts.pending_actions or {},
    _peek_override = opts.peek_override,
    _idx = 0,
  }
  function s:mark_phase(p) self._phase = p end
  function s:clear_pending_action()
    self._cleared = true
    self._pending_actions = {}
    self._idx = 0
  end
  function s:peek_pending_action()
    if self._peek_override ~= nil then return self._peek_override end
    return self._pending_actions[self._idx + 1]
  end
  function s:take_pending_action()
    self._idx = self._idx + 1
    return self._pending_actions[self._idx]
  end
  return s
end

local function _make_game(turn_overrides)
  return {
    turn = turn_overrides or {},
    dirty = { any = false, turn = false, players = false },
    current_player = function(self)
      return self._current_player or { id = 1, name = "P1", eliminated = false }
    end,
  }
end

local function _reset_runtime_ports()
  if type(runtime_ports.reset_for_tests) == "function" then
    runtime_ports.reset_for_tests()
  else
    runtime_ports.configure(nil)
  end
end

local function _with_runtime(opts, body)
  runtime_ports.configure(opts)
  local ok, err = pcall(body)
  _reset_runtime_ports()
  if not ok then error(err) end
end

describe("await action_anim + _resolve_action_anim_wait + _is_anim_timed_out + _next_action_anim", function()
  it("pre-existing anim short-circuits without calling _next_action_anim", function()
    local game = _make_game({
      action_anim = { kind = "explode", started_at = 0.0, duration = 2.0 },
      action_anim_queue = { { kind = "should_not_dequeue" } },
    })
    local session = _make_session({ game = game, pending_actions = { { type = "unrelated" } } })
    _with_runtime({
      wall_now_seconds = function() return 0.0 end,
      wall_diff_seconds = function(a, b) return a - b end,
    }, function()
      local await = _reload_await()
      local res = await.action_anim(session, {})
      _eq(res.wait, true, "non-matching action with pre-existing anim should return WAIT")
      _eq(game.turn.action_anim.kind, "explode", "pre-existing anim must not be replaced")
      _eq(#game.turn.action_anim_queue, 1, "queue must not be popped when anim exists")
    end)
  end)

  it("_is_anim_timed_out fires at elapsed == timeout boundary (>= edge)", function()
    -- timeout = duration + anim_done_timeout_seconds (10.0). With duration=1.0, timeout=11.0.
    -- Drive elapsed exactly equal to timeout → must be considered timed out (>= edge).
    local anim = { kind = "boom", started_at = 100.0, duration = 1.0 }
    local game = _make_game({ action_anim = anim, action_anim_queue = {} })
    local session = _make_session({ game = game, pending_actions = { { type = "unrelated_done_action" } } })
    _with_runtime({
      wall_now_seconds = function() return 111.0 end,
      wall_diff_seconds = function(a, b) return a - b end,
    }, function()
      local await = _reload_await()
      local res = await.action_anim(session, { next_state = "after_timeout" })
      _eq(res.next_state, "after_timeout", "boundary elapsed==timeout should clear and proceed")
      _eq(game.turn.action_anim, nil, "anim should be cleared on timeout-equal boundary")
    end)
  end)

  it("_is_anim_timed_out NOT fired one tick before boundary (strict less)", function()
    local anim = { kind = "boom", started_at = 100.0, duration = 1.0 }
    local game = _make_game({ action_anim = anim, action_anim_queue = {} })
    local session = _make_session({ game = game, pending_actions = { { type = "unrelated_done_action" } } })
    _with_runtime({
      wall_now_seconds = function() return 110.999 end,
      wall_diff_seconds = function(a, b) return a - b end,
    }, function()
      local await = _reload_await()
      local res = await.action_anim(session, {})
      _eq(res.wait, true, "elapsed just below timeout should NOT be considered timed out")
      _eq(game.turn.action_anim, anim, "anim should remain when not timed out")
    end)
  end)

  it("_next_action_anim sets anim.started_at from wall_now_seconds", function()
    local game = _make_game({
      action_anim = nil,
      action_anim_queue = { { kind = "fresh" } },
    })
    local session = _make_session({ game = game, pending_actions = { { type = "unrelated" } } })
    _with_runtime({
      wall_now_seconds = function() return 42.5 end,
      wall_diff_seconds = function(a, b) return a - b end,
    }, function()
      local await = _reload_await()
      await.action_anim(session, {})
      assert(game.turn.action_anim ~= nil, "dequeued anim should be installed")
      _eq(game.turn.action_anim.started_at, 42.5, "started_at must equal wall_now_seconds")
    end)
  end)
end)

describe("await.landing_visual _landing_visual L194/L204/L220/L222/L225", function()
  local _original_hold_seconds = timing.landing_visual_hold_seconds

  before_each(function()
    timing.landing_visual_hold_seconds = _original_hold_seconds
  end)
  after_each(function()
    timing.landing_visual_hold_seconds = _original_hold_seconds
  end)

  it("L194: does NOT register own after_landing_visual when one is already registered", function()
    local game = _make_game({})
    local sentinel_call_count = 0
    local function sentinel_cb()
      sentinel_call_count = sentinel_call_count + 1
      return "from_sentinel", { sentinel = true }
    end
    wait_callbacks.register(game, wait_callbacks.callback_keys.after_landing_visual, sentinel_cb)
    local session = _make_session({ game = game })
    local scheduled = {}
    _with_runtime({
      schedule = function(delay, fn) scheduled[#scheduled + 1] = { delay = delay, fn = fn } end,
    }, function()
      local await = _reload_await()
      local res = await.landing_visual(session, { next_state = "should_not_take_effect" })
      _eq(res.wait, true, "first call should return WAIT")
      -- sentinel should still be the registered callback (await did not replace it)
      assert(wait_callbacks.peek(game, wait_callbacks.callback_keys.after_landing_visual) == sentinel_cb,
        "L194: pre-registered after_landing_visual must be preserved (no overwrite)")
    end)
  end)

  it("L204: schedule delay = timing.landing_visual_hold_seconds (real value)", function()
    timing.landing_visual_hold_seconds = 0.75
    local game = _make_game({})
    local session = _make_session({ game = game })
    local scheduled = {}
    _with_runtime({
      schedule = function(delay, fn) scheduled[#scheduled + 1] = { delay = delay, fn = fn } end,
    }, function()
      local await = _reload_await()
      await.landing_visual(session, {})
      _eq(#scheduled, 1, "schedule should be called once")
      _eq(scheduled[1].delay, 0.75, "schedule delay should equal timing.landing_visual_hold_seconds")
    end)
  end)

  it("L204: schedule delay = 0 fallback when timing.landing_visual_hold_seconds is nil", function()
    timing.landing_visual_hold_seconds = nil
    local game = _make_game({})
    local session = _make_session({ game = game })
    local scheduled = {}
    _with_runtime({
      schedule = function(delay, fn) scheduled[#scheduled + 1] = { delay = delay, fn = fn } end,
    }, function()
      local await = _reload_await()
      await.landing_visual(session, {})
      _eq(#scheduled, 1, "schedule should be called once")
      _eq(scheduled[1].delay, 0, "nil hold seconds should fall back to 0")
    end)
  end)

  it("L220+L222: when continuation registered and wait ready, continuation result wins over args", function()
    timing.landing_visual_hold_seconds = 0
    local game = _make_game({})
    local session = _make_session({ game = game })
    local scheduled = {}
    _with_runtime({
      schedule = function(delay, fn) scheduled[#scheduled + 1] = { delay = delay, fn = fn } end,
    }, function()
      local await = _reload_await()
      -- first call: register own continuation closure (captures args.next_state="cb_initial")
      local res1 = await.landing_visual(session, { next_state = "cb_initial", next_args = { from = "cb" } })
      _eq(res1.wait, true, "first call returns WAIT")
      _eq(#scheduled, 1, "scheduler should be triggered once")
      -- simulate the scheduler firing
      scheduled[1].fn()
      -- second call: take continuation and use its return values, ignoring later args
      local res2 = await.landing_visual(session, { next_state = "later_args_should_lose", next_args = { from = "later" } })
      _eq(res2.next_state, "cb_initial", "L222 continuation branch: continuation return must win")
      _eq(res2.next_args.from, "cb", "L222 continuation branch: continuation next_args must win")
    end)
  end)

  it("L225: when continuation has been cleared, fallback to _unpack_next(args)", function()
    timing.landing_visual_hold_seconds = 0
    local game = _make_game({})
    local session = _make_session({ game = game })
    local scheduled = {}
    _with_runtime({
      schedule = function(delay, fn) scheduled[#scheduled + 1] = { delay = delay, fn = fn } end,
    }, function()
      local await = _reload_await()
      await.landing_visual(session, { next_state = "cb_initial" })
      scheduled[1].fn()
      -- externally clear the after_landing_visual callback so take() returns nil
      wait_callbacks.clear(game, wait_callbacks.callback_keys.after_landing_visual)
      local res = await.landing_visual(session, { next_state = "fallback_args_state", next_args = { from = "fallback" } })
      _eq(res.next_state, "fallback_args_state", "L225 fallback branch: args.next_state must win when continuation absent")
      _eq(res.next_args.from, "fallback", "L225 fallback branch: args.next_args must win when continuation absent")
    end)
  end)
end)

describe("await.action + _is_choice_action + _CHOICE_ACTION_TYPES + _build_action_next", function()
  local function _with_auto(value, body)
    local prev = package.loaded["src.rules.ports.auto_play"]
    package.loaded["src.rules.ports.auto_play"] = { is_auto_player = function() return value end }
    package.loaded["src.turn.waits.await"] = nil
    local ok, err = pcall(body)
    package.loaded["src.rules.ports.auto_play"] = prev
    package.loaded["src.turn.waits.await"] = nil
    if not ok then error(err) end
  end

  it("_CHOICE_ACTION_TYPES: each of the three values triggers _is_choice_action true", function()
    _with_auto(false, function()
      local await = require("src.turn.waits.await")
      for _, t in ipairs({ "choice_select", "choice_cancel", "choice_force_skip" }) do
        local session = _make_session({
          game = _make_game(),
          pending_actions = { { type = t } },
        })
        local res = await.action(session, { next_state = "post_choice" })
        _eq(res.next_state, "post_choice",
          "_CHOICE_ACTION_TYPES[" .. t .. "] must dispatch via _is_choice_action true → _build_action_next")
        _eq(res.wait, nil, "choice peeked type " .. t .. " must NOT wait")
      end
    end)
  end)

  it("_is_choice_action returns false for non-choice peeked types (take path)", function()
    _with_auto(false, function()
      local await = require("src.turn.waits.await")
      local session = _make_session({
        game = _make_game(),
        pending_actions = { { type = "ui_button", id = "next" } },
      })
      local res = await.action(session, { next_state = "after_take" })
      _eq(res.next_state, "after_take", "non-choice peek should fall through, take, then return next")
      _eq(res.wait, nil, "non-choice peek with action taken should not wait")
    end)
  end)

  it("_action L291/L292: no pending action returns WAIT", function()
    _with_auto(false, function()
      local await = require("src.turn.waits.await")
      local session = _make_session({ game = _make_game(), pending_actions = {} })
      local res = await.action(session, {})
      _eq(res.wait, true, "no peeked action and no taken action must return WAIT")
    end)
  end)

  it("_build_action_next L278: nil next_args falls back to { player = player }", function()
    _with_auto(true, function()
      local await = require("src.turn.waits.await")
      local game = _make_game()
      local specific_player = { id = 7, name = "SpecificPlayer" }
      game.current_player = function() return specific_player end
      local session = _make_session({ game = game })
      local res = await.action(session, { next_state = "x" })
      assert(res.next_args ~= nil, "next_args must not be nil")
      _eq(res.next_args.player, specific_player,
        "L278 fallback: next_args.player must be the resolved current player when args.next_args is nil")
    end)
  end)

  it("_build_action_next: explicit args.next_args passes through unchanged", function()
    _with_auto(true, function()
      local await = require("src.turn.waits.await")
      local session = _make_session({ game = _make_game() })
      local supplied = { custom_key = "custom_value" }
      local res = await.action(session, { next_state = "y", next_args = supplied })
      _eq(res.next_args, supplied, "supplied next_args must be returned verbatim")
      _eq(res.next_args.custom_key, "custom_value", "supplied next_args fields must survive")
    end)
  end)

  it("_build_action_next: nil args falls back to next_state='roll'", function()
    _with_auto(true, function()
      local await = require("src.turn.waits.await")
      local session = _make_session({ game = _make_game() })
      local res = await.action(session, nil)
      _eq(res.next_state, "roll", "nil args must fall back to 'roll' default next_state")
    end)
  end)
end)

describe("await.choice _clear_choice_wait + _finish_choice_wait + _resolve_choice_result + _resolve_choice_action + _validate_choice_action", function()
  local function _with_mocks(mocks, body)
    local saved = {}
    for path, value in pairs(mocks) do
      saved[path] = package.loaded[path]
      package.loaded[path] = value
    end
    package.loaded["src.turn.waits.await"] = nil
    local ok, err = pcall(body)
    for path, prev in pairs(saved) do
      package.loaded[path] = prev
    end
    package.loaded["src.turn.waits.await"] = nil
    if not ok then error(err) end
  end

  it("_clear_choice_wait L313: pending_choice nil resets session.choice_elapsed_seconds to 0", function()
    local game = _make_game({ pending_choice = nil })
    local session = _make_session({ game = game, choice_elapsed_seconds = 9.5 })
    _with_mocks({}, function()
      local await = require("src.turn.waits.await")
      local res = await.choice(session, { next_state = "after_clear", next_args = { x = 1 } })
      _eq(session.choice_elapsed_seconds, 0, "L313 reset: choice_elapsed_seconds must be set to 0")
      _eq(session._cleared, true, "clear_pending_action must run")
      _eq(res.next_state, "after_clear", "_unpack_next must return args.next_state")
      _eq(res.next_args.x, 1, "_unpack_next must return args.next_args")
    end)
  end)

  it("_resolve_choice_action L358: force_skip_pending branch returns action with choice.id", function()
    _with_mocks({
      ["src.turn.waits.decision"] = {
        decide_choice_action = function() error("should not be called when force_skip_pending is set") end,
        resolve_choice = function() return {} end,
      },
      ["src.turn.actions.validator"] = {
        validate_choice_id = function() return true end,
      },
    }, function()
      local await = require("src.turn.waits.await")
      local game = _make_game({
        pending_choice = { id = "choice_X" },
        _choice_force_skip_pending = true,
      })
      local session = _make_session({ game = game })
      local res = await.choice(session, { next_state = "after_skip" })
      -- force_skip clears pending_choice via _resolve_choice_result L331 dirty branch
      _eq(game.turn.pending_choice, nil, "L331: pending_choice should be cleared on force_skip")
      _eq(game.dirty.turn, true, "L331: dirty should be marked on force_skip")
      _eq(game.turn._choice_force_skip_pending, nil, "_choice_force_skip_pending must be consumed")
      _eq(res.next_state, "after_skip", "after force_skip should advance via args.next_state")
    end)
  end)

  it("_resolve_choice_action L360: session.choice_elapsed_seconds passed to decide_choice_action opts", function()
    local captured_opts
    _with_mocks({
      ["src.turn.waits.decision"] = {
        decide_choice_action = function(_, _, _, opts)
          captured_opts = { elapsed_seconds = opts.elapsed_seconds }
          return nil  -- forces resolved=false → WAIT
        end,
        resolve_choice = function() return {} end,
      },
      ["src.turn.actions.validator"] = {
        validate_choice_id = function() return true end,
      },
    }, function()
      local await = require("src.turn.waits.await")
      local game = _make_game({ pending_choice = { id = "C1" } })
      local session = _make_session({ game = game, choice_elapsed_seconds = 4.25 })
      await.choice(session, {})
      _eq(captured_opts.elapsed_seconds, 4.25, "L360: must pass session.choice_elapsed_seconds")
    end)
    -- second sub-case: nil session.choice_elapsed_seconds defaults to 0
    captured_opts = nil
    _with_mocks({
      ["src.turn.waits.decision"] = {
        decide_choice_action = function(_, _, _, opts)
          captured_opts = { elapsed_seconds = opts.elapsed_seconds }
          return nil
        end,
        resolve_choice = function() return {} end,
      },
      ["src.turn.actions.validator"] = {
        validate_choice_id = function() return true end,
      },
    }, function()
      local await = require("src.turn.waits.await")
      local game = _make_game({ pending_choice = { id = "C2" } })
      local session = _make_session({ game = game, choice_elapsed_seconds = nil })
      await.choice(session, {})
      _eq(captured_opts.elapsed_seconds, 0, "L360 fallback: nil must coerce to 0")
    end)
  end)

  it("_resolve_choice_result L325/L328: nil action returns nil,false → WAIT; failed validate returns nil,false → WAIT", function()
    _with_mocks({
      ["src.turn.waits.decision"] = {
        decide_choice_action = function() return nil end,
        resolve_choice = function() return {} end,
      },
      ["src.turn.actions.validator"] = { validate_choice_id = function() return true end },
    }, function()
      local await = require("src.turn.waits.await")
      local game = _make_game({ pending_choice = { id = "C1" } })
      local session = _make_session({ game = game })
      local res = await.choice(session, { next_state = "should_not_reach" })
      _eq(res.wait, true, "nil action from decide should yield WAIT")
    end)
    _with_mocks({
      ["src.turn.waits.decision"] = {
        decide_choice_action = function()
          return { type = "choice_select", choice_id = "bogus" }
        end,
        resolve_choice = function() return {} end,
      },
      ["src.turn.actions.validator"] = {
        validate_choice_id = function() return false end,
      },
    }, function()
      local await = require("src.turn.waits.await")
      local game = _make_game({ pending_choice = { id = "C1" } })
      local session = _make_session({ game = game })
      local res = await.choice(session, { next_state = "should_not_reach" })
      _eq(res.wait, true, "L328: failed validate should yield WAIT")
    end)
  end)

  it("_validate_choice_action L365: choice_force_skip action.type bypasses validator and returns true", function()
    local validator_called = false
    _with_mocks({
      ["src.turn.waits.decision"] = {
        decide_choice_action = function() return { type = "choice_force_skip" } end,
        resolve_choice = function() return {} end,
      },
      ["src.turn.actions.validator"] = {
        validate_choice_id = function() validator_called = true; return false end,
      },
    }, function()
      local await = require("src.turn.waits.await")
      local game = _make_game({ pending_choice = { id = "C1" } })
      local session = _make_session({ game = game })
      local res = await.choice(session, { next_state = "post_force_skip" })
      _eq(validator_called, false, "L365: validator must NOT be called for choice_force_skip")
      _eq(game.turn.pending_choice, nil, "L331: pending_choice cleared on force_skip path")
      _eq(res.next_state, "post_force_skip", "force_skip should advance to args.next_state")
    end)
  end)

  it("_validate_choice_action L368/L369: non-select-non-cancel action.type returns true without calling validator", function()
    local validator_called = false
    _with_mocks({
      ["src.turn.waits.decision"] = {
        decide_choice_action = function() return { type = "some_other_action_type" } end,
        resolve_choice = function() return { kind = "resolved" } end,
      },
      ["src.turn.actions.validator"] = {
        validate_choice_id = function() validator_called = true; return false end,
      },
    }, function()
      local await = require("src.turn.waits.await")
      local game = _make_game({ pending_choice = { id = "C1" } })
      local session = _make_session({ game = game })
      local res = await.choice(session, { next_state = "post_other" })
      _eq(validator_called, false, "L368: validator must NOT be called for non-select/non-cancel")
      _eq(res.next_state, "post_other", "L369 return true: should advance after resolve_choice")
    end)
  end)

  it("_validate_choice_action: choice_select path calls validator (validator true → proceeds)", function()
    local validator_called = false
    _with_mocks({
      ["src.turn.waits.decision"] = {
        decide_choice_action = function()
          return { type = "choice_select", choice_id = "good" }
        end,
        resolve_choice = function() return { kind = "selected" } end,
      },
      ["src.turn.actions.validator"] = {
        validate_choice_id = function(action, choice)
          validator_called = true
          return action.choice_id == choice.id
        end,
      },
    }, function()
      local await = _reload_await()
      local game = _make_game({ pending_choice = { id = "good" } })
      local session = _make_session({ game = game })
      local res = await.choice(session, { next_state = "post_select" })
      _eq(validator_called, true, "validator MUST be called for choice_select")
      _eq(res.next_state, "post_select", "valid selection should advance")
    end)
  end)

  it("_finish_choice_wait L344: choice_elapsed_seconds reset to 0 after successful resolution", function()
    _with_mocks({
      ["src.turn.waits.decision"] = {
        decide_choice_action = function()
          return { type = "choice_select", choice_id = "good" }
        end,
        resolve_choice = function() return {} end,
      },
      ["src.turn.actions.validator"] = {
        validate_choice_id = function() return true end,
      },
    }, function()
      local await = _reload_await()
      local game = _make_game({ pending_choice = { id = "good" } })
      local session = _make_session({ game = game, choice_elapsed_seconds = 11.0 })
      await.choice(session, {})
      _eq(session.choice_elapsed_seconds, 0, "L344: choice_elapsed_seconds must reset to 0 after resolve")
    end)
  end)

  it("_finish_choice_wait: res.stay returns WAIT without resetting elapsed", function()
    _with_mocks({
      ["src.turn.waits.decision"] = {
        decide_choice_action = function()
          return { type = "choice_select", choice_id = "good" }
        end,
        resolve_choice = function() return { stay = true } end,
      },
      ["src.turn.actions.validator"] = {
        validate_choice_id = function() return true end,
      },
    }, function()
      local await = _reload_await()
      local game = _make_game({ pending_choice = { id = "good" } })
      local session = _make_session({ game = game, choice_elapsed_seconds = 3.0 })
      local res = await.choice(session, {})
      _eq(res.wait, true, "res.stay=true should return WAIT")
      _eq(session.choice_elapsed_seconds, 3.0, "stay path must NOT reset elapsed_seconds")
    end)
  end)
end)

describe("await.seconds + _seconds + _await_seconds_step + _resolve_seconds_now + _resolve_seconds_key", function()
  it("_seconds L453: nil sec falls through to wait_sec=0 → _DONE", function()
    local await = _reload_await()
    local session = _make_session()
    local res = await.seconds(session, nil)
    _eq(res.done, true, "nil sec must produce DONE")
  end)

  it("_seconds L454: sec=0 (non-positive boundary) → _DONE", function()
    local await = _reload_await()
    local session = _make_session()
    local res = await.seconds(session, 0)
    _eq(res.done, true, "sec=0 must produce DONE (<=0 boundary)")
  end)

  it("_seconds L454: sec=-1 (negative) → _DONE", function()
    local await = _reload_await()
    local session = _make_session()
    local res = await.seconds(session, -1)
    _eq(res.done, true, "negative sec must produce DONE")
  end)

  it("_resolve_seconds_now L421 a: non-function now_fn → nil → _DONE short-circuit", function()
    local await = _reload_await()
    local session = _make_session()
    local res = await.seconds(session, 5, { now_fn = "not_a_function" })
    _eq(res.done, true, "non-function now_fn must short-circuit to DONE")
  end)

  it("_resolve_seconds_now L421 b: now_fn throws → ok=false → nil → DONE", function()
    local await = _reload_await()
    local session = _make_session()
    local res = await.seconds(session, 5, { now_fn = function() error("boom_now_fn") end })
    _eq(res.done, true, "throwing now_fn must short-circuit to DONE")
  end)

  it("_resolve_seconds_now L421 c: now_fn returns non-numeric → nil → DONE (or guard arm)", function()
    local await = _reload_await()
    local session = _make_session()
    local res = await.seconds(session, 5, { now_fn = function() return "stringy" end })
    _eq(res.done, true, "non-numeric now must short-circuit to DONE — kills `or` → `and` mutation")
  end)

  it("_resolve_seconds_key + _await_seconds_step: started_now=true returns WAIT, default key", function()
    local await = _reload_await()
    local session = _make_session()
    local now_value = 10.0
    local res = await.seconds(session, 1, { now_fn = function() return now_value end })
    _eq(res.wait, true, "first call with valid now_fn must return WAIT")
    _eq(session._seconds_wait["__default__"], 10.0, "L429: default key '__default__' must be used when opts.key absent")
  end)

  it("_resolve_seconds_key: opts.key='foo' uses that key in _seconds_wait", function()
    local await = _reload_await()
    local session = _make_session()
    await.seconds(session, 1, { now_fn = function() return 5.0 end, key = "foo" })
    _eq(session._seconds_wait["foo"], 5.0, "explicit opts.key must be used")
    _eq(session._seconds_wait["__default__"], nil, "default key must NOT be touched when explicit key given")
  end)

  it("_resolve_seconds_key: opts.key=nil falls back to '__default__'", function()
    local await = _reload_await()
    local session = _make_session()
    await.seconds(session, 1, { now_fn = function() return 5.0 end, key = nil })
    _eq(session._seconds_wait["__default__"], 5.0, "opts.key=nil must fall back to default key")
  end)

  it("_await_seconds_step L444: now - started == wait_sec boundary → DONE (not WAIT)", function()
    local await = _reload_await()
    local session = _make_session()
    local current = 100.0
    -- prime: started=100, started_now=true → WAIT
    await.seconds(session, 1, { now_fn = function() return current end })
    -- advance now to exactly wait_sec later → boundary case
    current = 101.0
    local res = await.seconds(session, 1, { now_fn = function() return current end })
    _eq(res.done, true, "L444 boundary: now-started == wait_sec must yield DONE (kills < → <=)")
    _eq(session._seconds_wait["__default__"], nil, "DONE path must clear session._seconds_wait key")
  end)

  it("_await_seconds_step: now - started < wait_sec still WAIT", function()
    local await = _reload_await()
    local session = _make_session()
    local current = 50.0
    await.seconds(session, 2, { now_fn = function() return current end })
    current = 51.5  -- elapsed=1.5 < 2
    local res = await.seconds(session, 2, { now_fn = function() return current end })
    _eq(res.wait, true, "below boundary still WAIT")
    assert(session._seconds_wait["__default__"] == 50.0, "started must be preserved while waiting")
  end)

  it("_await_seconds_step: now - started > wait_sec → DONE", function()
    local await = _reload_await()
    local session = _make_session()
    local current = 0.0
    await.seconds(session, 1, { now_fn = function() return current end })
    current = 5.0
    local res = await.seconds(session, 1, { now_fn = function() return current end })
    _eq(res.done, true, "elapsed greater than wait_sec must be DONE")
  end)
end)
