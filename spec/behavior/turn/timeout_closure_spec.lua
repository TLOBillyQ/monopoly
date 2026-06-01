-- Mutation-closure pins for src/turn/waits/timeout.lua.
-- tick_timeout_spec covers the resolve_choice happy paths and the modal-timer
-- state machine, leaving the config-fallback / type-guard / boundary survivors
-- alive. This spec drives the exported surface directly, patching timing and
-- constants config to reach the branches the architect flagged
-- (L22 _positive_numeric, L35 scoped-timeout fallback, L43 _resolve_modal_ports,
-- L81 _resolve_modal_timeout) plus the modal asserts and elapsed boundaries.
-- Routed by architect (agent_context/rules-mutation-bootstrap-debt.md).
--
-- The default-choice / default-modal opts closures (on_pending_choice,
-- is_choice_active, resolve_choice_ui_state, the choice policy getters, and the
-- _dispatch_action_with_close_choice / _resolve_modal_ports dispatch path) are
-- driven through the exported step_default_choice / step_default_modal one tick
-- with a fake gameplay_loop_ports table (architect re-measure bucket 2: these
-- are cleanly killable, not fragile — see the "驱动配方" in the debt doc).
local support = require("spec.support.shared_support")
local fixtures = require("spec.support.gameplay_fixtures")
local config_reset = require("spec.support.config_reset")
local tick_timeout = require("src.turn.waits.timeout")
local timing = require("src.config.gameplay.timing")
local constants = require("src.config.content.constants")
local runtime_state = require("src.state.runtime")
local choice_auto_policy = require("src.turn.policies.choice_auto")
local turn_dispatch = require("src.turn.actions.action_dispatcher")

local _assert_eq = support.assert_eq
local _with_patches = support.with_patches

local function _resolve_choice(game, state, choice)
  return tick_timeout.resolve_choice_timeout_seconds(game, state, choice)
end

describe("tick_timeout.resolve_choice_timeout_seconds closure", function()
  before_each(function() config_reset.reset_all() end)

  it("pulls the pending choice from runtime_state when game/choice are absent", function()
    -- third arm of the _resolve_pending_choice or-chain (state fallback).
    _with_patches({
      { target = timing, key = "scope_timeouts", value = { choice = 15.0, market_buy = 60.0 } },
      { target = runtime_state, key = "get_pending_choice", value = function() return { kind = "market_buy" } end },
    }, function()
      _assert_eq(_resolve_choice(nil, { any = true }, nil), 60.0,
        "a runtime pending market_buy choice resolves the market_buy scope")
    end)
  end)

  it("treats a zero scoped timeout as unset and falls back to the choice scope", function()
    -- _positive_numeric's `> 0` boundary: a kind whose scope value is 0 must
    -- fall through to scope_timeouts.choice rather than returning 0.
    _with_patches({
      { target = timing, key = "scope_timeouts", value = { choice = 15.0, zero_kind = 0 } },
    }, function()
      _assert_eq(_resolve_choice(nil, nil, { kind = "zero_kind" }), 15.0,
        "a 0 scoped timeout is not positive and yields the choice scope")
    end)
  end)

  it("treats a negative scoped timeout as unset", function()
    _with_patches({
      { target = timing, key = "scope_timeouts", value = { choice = 15.0, neg_kind = -5.0 } },
    }, function()
      _assert_eq(_resolve_choice(nil, nil, { kind = "neg_kind" }), 15.0,
        "a negative scoped timeout falls back to the choice scope")
    end)
  end)

  it("treats a non-numeric scoped timeout as unset", function()
    _with_patches({
      { target = timing, key = "scope_timeouts", value = { choice = 15.0, bad_kind = "soon" } },
    }, function()
      _assert_eq(_resolve_choice(nil, nil, { kind = "bad_kind" }), 15.0,
        "a non-numeric scoped timeout falls back to the choice scope")
    end)
  end)

  it("falls back to the constants base when scope_timeouts is not a table", function()
    _with_patches({
      { target = timing, key = "scope_timeouts", value = false },
      { target = constants, key = "action_timeout_seconds", value = 99.0 },
    }, function()
      _assert_eq(_resolve_choice(nil, nil, nil), 99.0,
        "a missing scope_timeouts table falls back to the constants base")
    end)
  end)

  it("falls back to 0 when neither a scoped timeout nor a constants base exist", function()
    _with_patches({
      { target = timing, key = "scope_timeouts", value = false },
      { target = constants, key = "action_timeout_seconds", value = nil },
    }, function()
      _assert_eq(_resolve_choice(nil, nil, nil), 0,
        "with no scope table and no constants base the timeout is 0")
    end)
  end)

  it("a scoped timeout of exactly 1 is positive (the > 0 boundary, not > 1)", function()
    -- kills _positive_numeric's `> 0` -> `> 1` mutant: a value of 1 must count
    -- as positive and win over the constants base.
    _with_patches({
      { target = timing, key = "scope_timeouts", value = { choice = 1.0 } },
      { target = constants, key = "action_timeout_seconds", value = 99.0 },
    }, function()
      _assert_eq(_resolve_choice(nil, nil, nil), 1.0,
        "choice=1 is positive and is chosen over the constants base 99")
    end)
  end)

  it("uses scope_timeouts.choice when the kind-specific scope is absent", function()
    -- kills the second or-arm (`or _positive_numeric(scope_timeouts.choice)` ->
    -- nil): an unmatched kind must still fall back to the choice scope, not the
    -- constants base. constants is set to a distinct value so the arms diverge.
    _with_patches({
      { target = timing, key = "scope_timeouts", value = { choice = 15.0 } },
      { target = constants, key = "action_timeout_seconds", value = 99.0 },
    }, function()
      _assert_eq(_resolve_choice(nil, nil, { kind = "no_such_kind" }), 15.0,
        "a missing kind scope resolves scope_timeouts.choice, not the constants base")
    end)
  end)
end)

describe("tick_timeout.default_policy closure", function()
  before_each(function() config_reset.reset_all() end)

  it("deep-clones the sub-policies so callers cannot share nested state", function()
    local p1 = tick_timeout.default_policy()
    local p2 = tick_timeout.default_policy()
    assert(p1.choice ~= p2.choice, "the choice sub-policy must be a fresh table per call")
    assert(p1.modal ~= p2.modal, "the modal sub-policy must be a fresh table per call")
  end)

  it("the choice min-visible reads the configured auto-decision delay", function()
    _with_patches({
      { target = timing, key = "auto_decision_delay_seconds", value = 0.7 },
    }, function()
      _assert_eq(tick_timeout.default_policy().choice.get_min_visible_seconds(), 0.7,
        "the min-visible seconds mirror the configured auto-decision delay")
    end)
  end)

  it("the choice min-visible defaults to 0 when the delay is unset", function()
    _with_patches({
      { target = timing, key = "auto_decision_delay_seconds", value = nil },
    }, function()
      _assert_eq(tick_timeout.default_policy().choice.get_min_visible_seconds(), 0,
        "an unset auto-decision delay yields 0 min-visible seconds")
    end)
  end)

  it("the choice timeout getter delegates to resolve_choice_timeout_seconds", function()
    -- kills the get_timeout_seconds closure body (the resolve_choice call -> nil):
    -- the policy getter must return the resolved scope timeout, not nil.
    _with_patches({
      { target = timing, key = "scope_timeouts", value = { choice = 22.0 } },
    }, function()
      local secs = tick_timeout.default_policy().choice.get_timeout_seconds(support.new_game(), {})
      _assert_eq(secs, 22.0,
        "the choice policy timeout getter forwards to resolve_choice_timeout_seconds")
    end)
  end)

  -- modal.on_timeout exercises _resolve_modal_ports (L43 or-guard) -----------

  local function _ctx_with_modal(modal)
    return { gameplay_loop_ports = { modal = modal } }
  end

  it("closes the popup when only close_popup is present (the or-guard)", function()
    local closed = false
    local ctx = _ctx_with_modal({ close_popup = function() closed = true end })
    tick_timeout.default_policy().modal.on_timeout(ctx)
    _assert_eq(closed, true,
      "close_popup alone resolves the modal ports (close_choice_modal OR close_popup)")
  end)

  it("does nothing when the modal ports expose only close_choice_modal", function()
    local ctx = _ctx_with_modal({ close_choice_modal = function() end })
    -- ports resolve, but on_timeout only acts when close_popup exists.
    local ok = pcall(function() tick_timeout.default_policy().modal.on_timeout(ctx) end)
    assert(ok, "on_timeout must not crash when close_popup is absent")
  end)

  it("does nothing when the modal ports are not a table", function()
    local ok = pcall(function()
      tick_timeout.default_policy().modal.on_timeout(_ctx_with_modal("not-a-table"))
    end)
    assert(ok, "a non-table modal port resolves to nil and is a no-op")
  end)

  it("does nothing when neither modal close function is present", function()
    local ok = pcall(function()
      tick_timeout.default_policy().modal.on_timeout(_ctx_with_modal({}))
    end)
    assert(ok, "modal ports without either close function resolve to nil and no-op")
  end)
end)

describe("tick_timeout.step_modal_timeout closure", function()
  before_each(function() config_reset.reset_all() end)

  -- Output-port stub: records the synced timer payloads.
  local function _output_state(start_elapsed, current_ref)
    local elapsed = start_elapsed
    local syncs = {}
    local ports = {
      get_modal_elapsed = function() return elapsed end,
      get_modal_ref = function() return current_ref end,
      sync_modal_timer = function(_, payload)
        syncs[#syncs + 1] = payload
        if payload.elapsed_seconds ~= nil then elapsed = payload.elapsed_seconds end
      end,
    }
    return { gameplay_loop_ports = { output = ports } }, syncs
  end

  local function _active_opts(extra)
    local opts = {
      is_active = function() return true end,
      get_ref = function() return "ref" end,
      on_timeout = function() end,
    }
    for k, v in pairs(extra or {}) do opts[k] = v end
    return opts
  end

  it("uses the constants base when opts carries no timeout override", function()
    local fired = false
    _with_patches({
      { target = constants, key = "action_timeout_seconds", value = 4.0 },
    }, function()
      local state = _output_state(3.0, "ref")
      tick_timeout.step_modal_timeout(state, 2.0,
        _active_opts({ on_timeout = function() fired = true end }))
      _assert_eq(fired, true, "3 + 2 >= the constants base 4 fires the timeout")
    end)
  end)

  it("a numeric override replaces the constants base", function()
    local fired = false
    _with_patches({
      { target = constants, key = "action_timeout_seconds", value = 4.0 },
    }, function()
      local state = _output_state(3.0, "ref")
      tick_timeout.step_modal_timeout(state, 2.0, _active_opts({
        get_timeout_seconds = function() return 100.0 end,
        on_timeout = function() fired = true end,
      }))
      _assert_eq(fired, false, "5 < the 100 override must not fire")
    end)
  end)

  it("a non-numeric override is ignored and the base is kept", function()
    local fired = false
    _with_patches({
      { target = constants, key = "action_timeout_seconds", value = 4.0 },
    }, function()
      local state = _output_state(3.0, "ref")
      tick_timeout.step_modal_timeout(state, 2.0, _active_opts({
        get_timeout_seconds = function() return "later" end,
        on_timeout = function() fired = true end,
      }))
      _assert_eq(fired, true, "a non-numeric override leaves the base 4 in force, so 5 >= 4 fires")
    end)
  end)

  it("fires exactly when elapsed reaches the timeout (the >= boundary)", function()
    local fired = false
    _with_patches({
      { target = constants, key = "action_timeout_seconds", value = 10.0 },
    }, function()
      local state = _output_state(8.0, "ref")
      tick_timeout.step_modal_timeout(state, 2.0,
        _active_opts({ on_timeout = function() fired = true end }))
      _assert_eq(fired, true, "8 + 2 == 10 must fire (elapsed >= timeout)")
    end)
  end)

  it("treats a nil dt as a zero increment", function()
    _with_patches({
      { target = constants, key = "action_timeout_seconds", value = 10.0 },
    }, function()
      local state, syncs = _output_state(2.0, "ref")
      tick_timeout.step_modal_timeout(state, nil, _active_opts())
      local last = syncs[#syncs]
      _assert_eq(last.elapsed_seconds, 2.0, "a nil dt adds 0 to the elapsed time")
    end)
  end)

  it("asserts when an active modal opts table is missing is_active", function()
    _with_patches({
      { target = constants, key = "action_timeout_seconds", value = 10.0 },
    }, function()
      local state = _output_state(0.0, "ref")
      local ok = pcall(function()
        tick_timeout.step_modal_timeout(state, 1.0, { get_ref = function() return "ref" end, on_timeout = function() end })
      end)
      _assert_eq(ok, false, "a positive timeout with missing opts.is_active asserts")
    end)
  end)

  it("asserts when the modal ref cannot be resolved", function()
    _with_patches({
      { target = constants, key = "action_timeout_seconds", value = 10.0 },
    }, function()
      local state = _output_state(0.0, "ref")
      local ok = pcall(function()
        tick_timeout.step_modal_timeout(state, 1.0, _active_opts({ get_ref = function() return nil end }))
      end)
      _assert_eq(ok, false, "a nil modal ref asserts 'missing modal ref'")
    end)
  end)

  it("a nil constants base resolves to a 0 timeout and short-circuits before firing", function()
    -- kills _resolve_modal_timeout's `or 0` -> `or 1` (L81) and step's `<= 0` ->
    -- `< 0` (L134): with no base the timeout is 0, so the <=0 branch syncs the
    -- empty payload and returns without ever firing on_timeout, even at huge dt.
    local fired = false
    _with_patches({
      { target = constants, key = "action_timeout_seconds", value = nil },
    }, function()
      local state, syncs = _output_state(100.0, "ref")
      tick_timeout.step_modal_timeout(state, 100.0,
        _active_opts({ on_timeout = function() fired = true end }))
      _assert_eq(fired, false, "a 0 timeout (or 0, not or 1) takes the <=0 branch before firing")
      _assert_eq(next(syncs[#syncs]), nil, "the <=0 branch syncs the empty timer payload")
    end)
  end)

  it("zeroes the elapsed time in the reset synced when the timeout fires", function()
    -- kills _handle_modal_timeout's `elapsed_seconds = 0` -> `= 1`: the fire-path
    -- reset payload (the last sync) must carry elapsed 0.
    _with_patches({
      { target = constants, key = "action_timeout_seconds", value = 4.0 },
    }, function()
      local state, syncs = _output_state(3.0, "ref")
      tick_timeout.step_modal_timeout(state, 2.0, _active_opts())
      _assert_eq(syncs[#syncs].elapsed_seconds, 0,
        "the timeout-fire reset zeroes elapsed_seconds")
    end)
  end)
end)

describe("tick_timeout.step_default_choice integration closure", function()
  before_each(function() config_reset.reset_all() end)

  -- Fake gameplay_loop_ports: build_test_ports supplies output (via the real
  -- output_state_adapter fallback) and a ui_sync table; we graft the choice
  -- callbacks onto ui_sync so the default-choice closures can delegate.
  local function _choice_state(ui_sync_extra)
    local game = support.new_game()
    local state = fixtures.build_loop_state()
    local ports = fixtures.build_test_ports()
    for key, value in pairs(ui_sync_extra or {}) do ports.ui_sync[key] = value end
    state._resolved_gameplay_loop_ports = ports
    state.gameplay_loop_ports = ports
    game.turn.pending_choice = { id = 1, kind = "test", route_key = "r" }
    return game, state, ports
  end

  it("delegates the ui-sync choice callbacks when the ports expose them", function()
    local calls = { pending = 0, active = 0, resolve = 0 }
    local game, state = _choice_state({
      on_pending_choice = function() calls.pending = calls.pending + 1 end,
      is_choice_active = function() calls.active = calls.active + 1; return true end,
      resolve_choice_ui_state = function() calls.resolve = calls.resolve + 1; return { should_warn = false } end,
    })
    tick_timeout.step_default_choice(game, state, 0.01)
    assert(calls.pending >= 1, "a fresh pending choice routes through ui_sync.on_pending_choice")
    assert(calls.active >= 1, "the active check delegates to ui_sync.is_choice_active")
    assert(calls.resolve >= 1, "the ui-gate resolve delegates to ui_sync.resolve_choice_ui_state")
  end)

  it("tolerates a ui_sync port table without the optional choice callbacks", function()
    local game = support.new_game()
    local state = fixtures.build_loop_state()
    local ports = fixtures.build_test_ports()
    ports.ui_sync = {} -- no on_pending_choice / is_choice_active / resolve_choice_ui_state
    state._resolved_gameplay_loop_ports = ports
    state.gameplay_loop_ports = ports
    game.turn.pending_choice = { id = 1, kind = "test", route_key = "r" }
    local ok = pcall(function() tick_timeout.step_default_choice(game, state, 0.01) end)
    assert(ok, "absent ui_sync callbacks fall back without crashing")
  end)

  it("dispatches the auto action through the close-choice path when modal ports exist", function()
    local dispatched
    local game, state = _choice_state({ is_choice_active = function() return true end })
    _with_patches({
      { target = timing, key = "auto_decision_delay_seconds", value = 0 }, -- force the timeout path
      { target = choice_auto_policy, key = "decide", value = function() return { type = "auto_skip", actor_role_id = 1 } end },
      { target = turn_dispatch, key = "dispatch_action", value = function(_, _, action, opts)
          dispatched = { action = action, opts = opts }
          return true
        end },
    }, function()
      tick_timeout.step_default_choice(game, state, 999.0) -- huge dt clears the min-visible gate and the timeout
    end)
    assert(dispatched ~= nil, "the decided auto action is dispatched on timeout")
    _assert_eq(dispatched.action.type, "auto_skip", "the policy's action is forwarded verbatim")
    assert(dispatched.opts ~= nil, "modal ports present -> a close-choice opts table is supplied")
  end)

  it("dispatches with no close-choice opts when modal ports are absent", function()
    local dispatched
    local game, state, ports = _choice_state({ is_choice_active = function() return true end })
    ports.modal = nil -- no modal ports to resolve
    _with_patches({
      { target = timing, key = "auto_decision_delay_seconds", value = 0 },
      { target = choice_auto_policy, key = "decide", value = function() return { type = "auto_skip", actor_role_id = 1 } end },
      { target = turn_dispatch, key = "dispatch_action", value = function(_, _, action, opts)
          dispatched = { action = action, opts = opts }
          return true
        end },
    }, function()
      tick_timeout.step_default_choice(game, state, 999.0)
    end)
    assert(dispatched ~= nil, "the action still dispatches without modal ports")
    _assert_eq(dispatched.opts, nil, "absent modal ports -> dispatch carries no close-choice opts")
  end)

  it("resolves modal ports through close_choice_modal alone and wires on_close_choice", function()
    -- kills _resolve_modal_ports' close_choice_modal arm (L43 type/==/literal x3):
    -- modal ports exposing ONLY close_choice_modal (no close_popup) must still
    -- resolve via the or-guard's first arm, so dispatch carries opts. Invoking
    -- on_close_choice must reach close_choice_modal, killing the `~=` cache guard
    -- (L53) that decides whether the closure is (re)built for this ref.
    local dispatched, closed
    local game, state, ports = _choice_state({ is_choice_active = function() return true end })
    ports.modal = { close_choice_modal = function() closed = true end }
    _with_patches({
      { target = timing, key = "auto_decision_delay_seconds", value = 0 },
      { target = choice_auto_policy, key = "decide", value = function() return { type = "auto_skip", actor_role_id = 1 } end },
      { target = turn_dispatch, key = "dispatch_action", value = function(_, _, action, opts)
          dispatched = { action = action, opts = opts }
          return true
        end },
    }, function()
      tick_timeout.step_default_choice(game, state, 999.0)
    end)
    assert(dispatched ~= nil, "the auto action dispatches")
    assert(dispatched.opts ~= nil,
      "modal ports with only close_choice_modal still resolve (the or-guard's first arm)")
    assert(type(dispatched.opts.on_close_choice) == "function",
      "a fresh modal ref wires the on_close_choice closure (the ~= cache guard)")
    dispatched.opts.on_close_choice({})
    _assert_eq(closed, true, "invoking on_close_choice routes to modal close_choice_modal")
  end)
end)

describe("tick_timeout.step_default_modal integration closure", function()
  before_each(function() config_reset.reset_all() end)

  it("fires the modal popup auto-close once the gate timeout elapses", function()
    local closed = false
    local game = support.new_game()
    local state = fixtures.build_loop_state()
    local ports = fixtures.build_test_ports()
    ports.modal.close_popup = function() closed = true end
    state._resolved_gameplay_loop_ports = ports
    state.gameplay_loop_ports = ports
    -- An active popup with a finite auto-close window drives is_active / get_ref
    -- / get_timeout_seconds in the default modal opts.
    state.ui.popup_active = true
    state.ui.popup_seq = 7
    state.ui.popup_payload = { auto_close_seconds = 5.0 }

    tick_timeout.step_default_modal(game, state, 999.0)

    _assert_eq(closed, true, "an active popup past its auto-close window closes the popup")
  end)

  it("does nothing while no popup is active", function()
    local closed = false
    local game = support.new_game()
    local state = fixtures.build_loop_state()
    local ports = fixtures.build_test_ports()
    ports.modal.close_popup = function() closed = true end
    state._resolved_gameplay_loop_ports = ports
    state.gameplay_loop_ports = ports
    state.ui.popup_active = false

    tick_timeout.step_default_modal(game, state, 999.0)

    _assert_eq(closed, false, "an inactive popup gate never fires the auto-close")
  end)
end)
