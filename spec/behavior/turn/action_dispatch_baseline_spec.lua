local P = require("spec.support.shared_support")
local _assert_eq = P.assert_eq

local action_dispatch_mod = require("src.turn.actions.action_dispatch")
local force_resolve = require("src.turn.deadlines")

-- Build a fully-stubbed dispatcher. invalidate calls + handler calls are observable
-- through the returned `events` table; per-test overrides go via `extra_deps`.
local function _build(extra_deps)
  local events = { invalidate = {}, ui_button = {}, choice = {}, market_nav = {}, force_skip = {} }
  local deps = {
    logger = { warn = function() end, info = function() end },
    validator = {
      resolve_gate_state = function() return { allow = true } end,
      should_block_action = function() return false end,
      validate_actor_role = function() return true end,
      validate_choice_action = function() return true end,
      resolve_item_slot_action = function() return nil end,
    },
    runtime_state = {
      ensure_turn_runtime = function(state)
        state._turn_runtime = state._turn_runtime or {}
        return state._turn_runtime
      end,
    },
    market_service = {
      choice = {
        apply_navigation = function() return true end,
      },
    },
    turn_dispatch_ref = {
      step_turn = function() end,
      clear_choice = function() end,
    },
  }
  if extra_deps then
    for k, v in pairs(extra_deps) do
      if type(v) == "table" and type(deps[k]) == "table" then
        for sk, sv in pairs(v) do
          deps[k][sk] = sv
        end
      else
        deps[k] = v
      end
    end
  end
  local dispatcher = action_dispatch_mod.build(deps)
  return dispatcher, events, deps
end

local function _ctx_with_invalidate(events, overrides)
  overrides = overrides or {}
  return {
    output_ports = {
      invalidate_ui_model = function(state)
        events.invalidate[#events.invalidate + 1] = state or true
        return true
      end,
      get_pending_choice = function() return overrides.pending_choice or nil end,
      sync_pending_choice = function(_, choice)
        events.market_nav[#events.market_nav + 1] = { sync_choice = choice }
        return true
      end,
    },
    ui_sync_ports = { get_ui_state = function() return nil end },
    clock_ports = { wall_now_seconds = function() return 0 end },
    item_slot_source = nil,
  }
end

describe("action_dispatch _should_invalidate_ui dispatch table (L14-L21)", function()
  -- Each listed action.type must trigger _invalidate_ui_model exactly once.

  local function _trigger(action_type, deps_overrides)
    local dispatcher, events = _build(deps_overrides)
    local game = {
      turn = { phase = "wait_action", pending_choice = nil },
      dispatch_action = function() end,
      find_player_by_id = function() return { id = 1, auto = false } end,
      players = { { id = 1 } },
    }
    local action = { type = action_type, id = "x", actor_role_id = 1 }
    local ctx = _ctx_with_invalidate(events, { pending_choice = { kind = "market_buy", id = "c1" } })
    dispatcher.dispatch_action(game, {}, action, nil, ctx)
    return events
  end

  it("ui_button → invalidates once", function()
    local events = _trigger("ui_button")
    _assert_eq(#events.invalidate, 1, "ui_button must invalidate ui model")
  end)

  it("choice_select → invalidates once", function()
    local events = _trigger("choice_select")
    _assert_eq(#events.invalidate, 1, "choice_select must invalidate ui model")
  end)

  it("choice_cancel → invalidates once", function()
    local events = _trigger("choice_cancel")
    _assert_eq(#events.invalidate, 1, "choice_cancel must invalidate ui model")
  end)

  it("market_page_prev → invalidates once", function()
    local events = _trigger("market_page_prev")
    _assert_eq(#events.invalidate, 1, "market_page_prev must invalidate ui model")
  end)

  it("market_page_next → invalidates once", function()
    local events = _trigger("market_page_next")
    _assert_eq(#events.invalidate, 1, "market_page_next must invalidate ui model")
  end)

  it("market_tab_select → invalidates once", function()
    local events = _trigger("market_tab_select")
    _assert_eq(#events.invalidate, 1, "market_tab_select must invalidate ui model")
  end)

  it("choice_force_skip → does NOT invalidate (NOT in dispatch table)", function()
    local prev_force_skip = force_resolve.force_skip
    force_resolve.force_skip = function() end
    local events = _trigger("choice_force_skip")
    force_resolve.force_skip = prev_force_skip
    _assert_eq(#events.invalidate, 0, "choice_force_skip must NOT trigger _should_invalidate_ui table")
  end)

  it("unknown action.type → does NOT invalidate", function()
    local events = _trigger("some_unknown_action")
    _assert_eq(#events.invalidate, 0, "unknown type must NOT invalidate")
  end)
end)

describe("action_dispatch _invalidate_ui_model nil output_ports fallback (L23-L31)", function()
  it("nil output_ports → no error, no invocation", function()
    local dispatcher = _build()
    local game = {
      turn = { phase = "wait_action", pending_choice = nil },
      dispatch_action = function() end,
      find_player_by_id = function() return { id = 1, auto = false } end,
      players = { { id = 1 } },
    }
    local action = { type = "ui_button", id = "x", actor_role_id = 1 }
    -- ctx with nil output_ports — but dispatch_action still reaches _handle_ui_button which needs output_ports for sub-calls.
    -- This case targets _invalidate_ui_model's "not output_ports" guard, not full ui_button success.
    local invoked = false
    local ctx = {
      output_ports = nil,  -- triggers L24 guard
      ui_sync_ports = { get_ui_state = function() return nil end },
      clock_ports = { wall_now_seconds = function() return 0 end },
      item_slot_source = nil,
    }
    -- The handler later may crash on ctx.output_ports.get_pending_choice — guard with pcall.
    pcall(function() dispatcher.dispatch_action(game, {}, action, nil, ctx) end)
    _assert_eq(invoked, false, "no invocation expected when output_ports is nil (L24 guard)")
  end)

  it("output_ports without invalidate_ui_model function → graceful nil-return path", function()
    local dispatcher, events = _build()
    local game = {
      turn = { phase = "wait_action", pending_choice = nil },
      dispatch_action = function() end,
      find_player_by_id = function() return { id = 1, auto = false } end,
      players = { { id = 1 } },
    }
    local action = { type = "ui_button", id = "next", actor_role_id = 1 }
    local ctx = {
      output_ports = {
        get_pending_choice = function() return nil end,
        sync_pending_choice = function() end,
        -- no invalidate_ui_model field → type check at L27 fails → return false
      },
      ui_sync_ports = { get_ui_state = function() return nil end },
      clock_ports = { wall_now_seconds = function() return 0 end },
      item_slot_source = nil,
    }
    -- Should not crash even though invalidate_ui_model is absent
    local ok = pcall(function()
      dispatcher.dispatch_action(game, {}, action, nil, ctx)
    end)
    assert(ok, "missing invalidate_ui_model field must NOT crash dispatch")
    _assert_eq(#events.invalidate, 0, "no invalidate happens when function field is absent")
  end)
end)

describe("action_dispatch action.type dispatch (L156-L170)", function()
  local function _drive(action_type, overrides)
    overrides = overrides or {}
    local dispatcher, events, deps = _build()
    local handle_ui_button_called, handle_choice_called = false, false
    local force_skip_calls = {}

    deps.validator.validate_actor_role = function() return true end
    deps.validator.validate_choice_action = function() return true end
    deps.market_service.choice.apply_navigation = function() return true end

    local game = {
      turn = { phase = "wait_action", pending_choice = overrides.pending_choice },
      dispatch_action = function(_, action)
        if action.type == "ui_button" then handle_ui_button_called = true end
        if action.type == "choice_select" or action.type == "choice_cancel" then handle_choice_called = true end
      end,
      find_player_by_id = function() return { id = 1, auto = false } end,
      players = { { id = 1 } },
    }
    local action = { type = action_type, id = overrides.id or "x", actor_role_id = 1, reason = "explicit_test_reason" }
    local ctx = _ctx_with_invalidate(events, { pending_choice = overrides.pending_choice })

    local prev_force_skip = force_resolve.force_skip
    force_resolve.force_skip = function(g, s, c, reason)
      force_skip_calls[#force_skip_calls + 1] = { game = g, state = s, choice = c, reason = reason }
    end
    local result
    local ok, err = pcall(function()
      result = dispatcher.dispatch_action(game, {}, action, nil, ctx)
    end)
    force_resolve.force_skip = prev_force_skip
    if not ok then error(err) end

    return {
      result = result,
      handle_ui_button_called = handle_ui_button_called,
      handle_choice_called = handle_choice_called,
      handle_market_nav_called = #events.market_nav > 0,
      force_skip_calls = force_skip_calls,
    }
  end

  it("L156 ui_button: dispatches to _handle_ui_button", function()
    local r = _drive("ui_button", { id = "next" })
    -- "next" id with allow_next_turn (no lock + nil last_click) → applied, also dispatches via game:dispatch_action
    _assert_eq(r.result.status, "applied", "ui_button id=next must apply")
    _assert_eq(r.handle_ui_button_called, true, "game:dispatch_action invoked for ui_button next")
  end)

  it("ui_button id=cancel dispatches choice_cancel for current player's item target choice", function()
    local r = _drive("ui_button", {
      id = "cancel",
      pending_choice = {
        id = "target_1",
        kind = "item_phase_passive",
        allow_cancel = true,
      },
    })
    _assert_eq(r.result.status, "applied", "cancel ui_button must apply")
    _assert_eq(r.handle_choice_called, true, "cancel ui_button should dispatch choice_cancel")
  end)

  it("ui_button id=cancel rejects when actor is not current player", function()
    local dispatcher, events, deps = _build()
    deps.validator.validate_actor_role = function(game, action)
      return action.actor_role_id == 1
    end
    deps.validator.validate_choice_action = function() return true end

    local game = {
      turn = {
        phase = "wait_action",
        pending_choice = { id = "target_1", kind = "item_phase_passive", allow_cancel = true },
      },
      dispatch_action = function() end,
      find_player_by_id = function() return { id = 1 } end,
      players = { { id = 1 }, { id = 2 } },
    }
    local action = { type = "ui_button", id = "cancel", actor_role_id = 2 }
    local ctx = _ctx_with_invalidate(events, { pending_choice = game.turn.pending_choice })

    local result = dispatcher.dispatch_action(game, {}, action, nil, ctx)
    _assert_eq(result.status, "rejected", "cancel from non-current player must reject")
  end)

  it("L159 choice_select: dispatches to _handle_choice_action", function()
    local r = _drive("choice_select", { pending_choice = { kind = "choice", id = "c1" } })
    _assert_eq(r.result.status, "applied", "choice_select must apply when validate passes")
    _assert_eq(r.handle_choice_called, true, "game:dispatch_action invoked for choice_select")
  end)

  it("L159 choice_cancel: same handler as choice_select", function()
    local r = _drive("choice_cancel", { pending_choice = { kind = "choice", id = "c1" } })
    _assert_eq(r.result.status, "applied", "choice_cancel must apply when validate passes")
    _assert_eq(r.handle_choice_called, true, "choice_cancel uses _handle_choice_action")
  end)

  it("L162 market_page_prev: dispatches to _handle_market_navigation", function()
    local r = _drive("market_page_prev", { pending_choice = { kind = "market_buy", id = "m1" } })
    _assert_eq(r.result.status, "applied", "market_page_prev must apply")
    _assert_eq(r.handle_market_nav_called, true, "market_page_prev triggers sync_pending_choice path")
  end)

  it("L162 market_page_next: dispatches to _handle_market_navigation", function()
    local r = _drive("market_page_next", { pending_choice = { kind = "market_buy", id = "m1" } })
    _assert_eq(r.result.status, "applied", "market_page_next must apply")
    _assert_eq(r.handle_market_nav_called, true, "market_page_next triggers market nav")
  end)

  it("L162 market_tab_select: dispatches to _handle_market_navigation", function()
    local r = _drive("market_tab_select", { pending_choice = { kind = "market_buy", id = "m1" } })
    _assert_eq(r.result.status, "applied", "market_tab_select must apply")
    _assert_eq(r.handle_market_nav_called, true, "market_tab_select triggers market nav")
  end)

  it("L165 choice_force_skip: invokes force_resolve.force_skip with action.reason", function()
    local r = _drive("choice_force_skip", { pending_choice = { kind = "choice", id = "c1" } })
    _assert_eq(r.result.status, "applied", "choice_force_skip must apply")
    _assert_eq(#r.force_skip_calls, 1, "force_skip called exactly once")
    _assert_eq(r.force_skip_calls[1].reason, "explicit_test_reason", "reason from action.reason must pass")
  end)

  it("L166 choice_force_skip: choice arg surfaced (kills _resolve_pending_choice→nil mutation)", function()
    local r = _drive("choice_force_skip", { pending_choice = { kind = "choice", id = "c-fs-unique" } })
    _assert_eq(r.result.status, "applied", "choice_force_skip must apply with valid pending_choice")
    _assert_eq(#r.force_skip_calls, 1, "force_skip exactly once")
    local choice_arg = r.force_skip_calls[1].choice
    assert(choice_arg ~= nil, "L166 force_skip MUST receive non-nil choice (kills mutation that nil-returns _resolve_pending_choice)")
    _assert_eq(choice_arg.id, "c-fs-unique", "force_skip choice arg must be the actual pending_choice from _resolve_pending_choice")
    _assert_eq(choice_arg.kind, "choice", "choice arg kind preserved through L166 resolution")
  end)

  it("L167 choice_force_skip without reason: reason defaults to 'dispatch'", function()
    local dispatcher, events = _build()
    local game = {
      turn = { phase = "wait_action", pending_choice = { id = "c1" } },
      dispatch_action = function() end,
      find_player_by_id = function() return { id = 1 } end,
      players = { { id = 1 } },
    }
    local action = { type = "choice_force_skip", actor_role_id = 1 }  -- no reason
    local ctx = _ctx_with_invalidate(events, { pending_choice = { id = "c1" } })
    local force_skip_calls = {}
    local prev_force_skip = force_resolve.force_skip
    force_resolve.force_skip = function(_, _, _, reason)
      force_skip_calls[#force_skip_calls + 1] = reason
    end
    dispatcher.dispatch_action(game, {}, action, nil, ctx)
    force_resolve.force_skip = prev_force_skip
    _assert_eq(force_skip_calls[1], "dispatch", "L167 'or dispatch' fallback must yield 'dispatch'")
  end)

  it("L170 unknown action.type: rejected", function()
    local r = _drive("totally_unknown_action_type")
    _assert_eq(r.result.status, "rejected", "unknown type must return rejected")
  end)

  it("blocked action: status=blocked, no handler invoked", function()
    local dispatcher, events, deps = _build()
    deps.validator.should_block_action = function() return true end
    local game = {
      turn = { phase = "wait_action" },
      dispatch_action = function() end,
      find_player_by_id = function() return { id = 1 } end,
      players = { { id = 1 } },
    }
    local action = { type = "ui_button", id = "next", actor_role_id = 1 }
    local ctx = _ctx_with_invalidate(events)
    local result = dispatcher.dispatch_action(game, {}, action, nil, ctx)
    _assert_eq(result.status, "blocked", "should_block_action true must short-circuit to blocked")
    _assert_eq(#events.invalidate, 0, "blocked actions skip invalidate")
  end)

  it("market choice_cancel applies while input_blocked", function()
    local dispatcher, events, deps = _build()
    deps.validator.resolve_gate_state = function()
      return {
        input_blocked = true,
        choice_active = false,
        market_active = true,
        popup_active = false,
        detained_wait_active = false,
      }
    end
    deps.validator.should_block_action = function(gate)
      return gate.input_blocked == true
    end
    deps.validator.validate_choice_action = function(_, action, choice)
      return choice ~= nil
        and choice.kind == "market_buy"
        and action.choice_id == choice.id
    end

    local dispatch_called = false
    local clear_choice_called = false
    deps.turn_dispatch_ref.clear_choice = function()
      clear_choice_called = true
    end

    local game = {
      turn = {
        phase = "wait_action_anim",
        pending_choice = { id = "m1", kind = "market_buy", owner_role_id = 1 },
      },
      dispatch_action = function(self, action)
        if action.type == "choice_cancel" then
          dispatch_called = true
          self.turn.pending_choice = nil
        end
      end,
      find_player_by_id = function() return { id = 1 } end,
      players = { { id = 1 } },
    }
    local action = { type = "choice_cancel", choice_id = "m1", actor_role_id = 1 }
    local ctx = _ctx_with_invalidate(events, { pending_choice = game.turn.pending_choice })

    local result = dispatcher.dispatch_action(game, {}, action, nil, ctx)

    _assert_eq(result.status, "applied", "market close must apply even while post-purchase input is blocked")
    _assert_eq(dispatch_called, true, "choice_cancel should reach the turn runtime")
    _assert_eq(clear_choice_called, true, "closing the market should clear the visible choice")
    _assert_eq(#events.invalidate, 1, "applied market close should invalidate the UI model")
  end)

  local function _build_blocked_market_gate()
    local dispatcher, events, deps = _build()
    deps.validator.resolve_gate_state = function()
      return { input_blocked = true }
    end
    deps.validator.should_block_action = function(gate)
      return gate.input_blocked == true
    end
    deps.validator.validate_choice_action = function(_, action, choice)
      return choice ~= nil
        and choice.kind == "market_buy"
        and action.choice_id == choice.id
    end
    return dispatcher, events, deps
  end

  it("market choice_cancel while blocked resolves choice via output_ports fallback", function()
    -- turn.pending_choice is nil: _resolve_pending_choice must fall back to
    -- ctx.output_ports.get_pending_choice (L38-L40).
    local dispatcher, events = _build_blocked_market_gate()
    local game = {
      turn = { phase = "wait_action_anim", pending_choice = nil },
      dispatch_action = function() end,
      find_player_by_id = function() return { id = 1 } end,
      players = { { id = 1 } },
    }
    local action = { type = "choice_cancel", choice_id = "m1", actor_role_id = 1 }
    local ctx = _ctx_with_invalidate(events, { pending_choice = { id = "m1", kind = "market_buy" } })

    local result = dispatcher.dispatch_action(game, {}, action, nil, ctx)

    _assert_eq(result.status, "applied", "port-resolved market choice must allow cancel while blocked")
  end)

  it("choice_cancel while blocked with no pending choice anywhere stays blocked", function()
    -- Neither turn.pending_choice nor the output port has a choice:
    -- _resolve_pending_choice returns nil (L42) and the gate keeps blocking.
    local dispatcher, events = _build_blocked_market_gate()
    local game = {
      turn = { phase = "wait_action_anim", pending_choice = nil },
      dispatch_action = function() end,
      find_player_by_id = function() return { id = 1 } end,
      players = { { id = 1 } },
    }
    local action = { type = "choice_cancel", choice_id = "m1", actor_role_id = 1 }
    local ctx = _ctx_with_invalidate(events, { pending_choice = nil })

    local result = dispatcher.dispatch_action(game, {}, action, nil, ctx)

    _assert_eq(result.status, "blocked", "cancel without any pending choice must stay gated")
  end)
end)

describe("action_dispatch _handle_auto_toggle (L33-L40)", function()
  it("ui_button id=auto with actor → toggles player.auto", function()
    local dispatcher, events = _build()
    local player_state = { id = 1, auto = false }
    local game = {
      turn = { phase = "wait_action" },
      dispatch_action = function() end,
      find_player_by_id = function() return player_state end,
      players = { player_state },
    }
    local action = { type = "ui_button", id = "auto", actor_role_id = 1 }
    local ctx = _ctx_with_invalidate(events)
    local result = dispatcher.dispatch_action(game, {}, action, nil, ctx)
    _assert_eq(result.status, "applied", "auto toggle must apply")
    _assert_eq(player_state.auto, true, "auto must flip false→true")

    -- Toggle again: true→false
    dispatcher.dispatch_action(game, {}, action, nil, ctx)
    _assert_eq(player_state.auto, false, "auto must flip true→false")
  end)

  it("ui_button id=auto with no actor → rejected", function()
    local dispatcher, events = _build()
    local game = {
      turn = { phase = "wait_action" },
      dispatch_action = function() end,
      find_player_by_id = function() return nil end,
      players = {},
    }
    local action = { type = "ui_button", id = "auto", actor_role_id = nil }
    local ctx = _ctx_with_invalidate(events)
    local result = dispatcher.dispatch_action(game, {}, action, nil, ctx)
    _assert_eq(result.status, "rejected", "auto toggle without actor must reject")
  end)
end)

describe("action_dispatch input_source default (L145-L147)", function()
  it("nil input_source defaults to 'user'", function()
    local dispatcher, events = _build()
    local game = {
      turn = { phase = "wait_action" },
      dispatch_action = function() end,
      find_player_by_id = function() return { id = 1, auto = false } end,
      players = { { id = 1 } },
    }
    local action = { type = "ui_button", id = "next", actor_role_id = 1 }  -- no input_source
    local ctx = _ctx_with_invalidate(events)
    dispatcher.dispatch_action(game, {}, action, nil, ctx)
    -- action.input_source mutated in-place
    _assert_eq(action.input_source, "user", "nil input_source must default to 'user'")
  end)

  it("existing input_source preserved", function()
    local dispatcher, events = _build()
    local game = {
      turn = { phase = "wait_action" },
      dispatch_action = function() end,
      find_player_by_id = function() return { id = 1, auto = false } end,
      players = { { id = 1 } },
    }
    local action = { type = "ui_button", id = "next", actor_role_id = 1, input_source = "remote" }
    local ctx = _ctx_with_invalidate(events)
    dispatcher.dispatch_action(game, {}, action, nil, ctx)
    _assert_eq(action.input_source, "remote", "existing input_source must NOT be overwritten")
  end)
end)
