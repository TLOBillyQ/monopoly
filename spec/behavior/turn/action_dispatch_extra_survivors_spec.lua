local P = require("spec.support.shared_support")
local _assert_eq = P.assert_eq

local defaults = require("src.turn.actions.defaults")

-- Same reload-based builder as action_dispatch_baseline_spec: swap module deps in
-- package.loaded, re-require a fresh action_dispatcher bound to the stubs, restore.
local function _build(extra_deps)
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
    market_service = { choice = { apply_navigation = function() return true end } },
  }
  if extra_deps then
    for k, v in pairs(extra_deps) do
      if type(v) == "table" and type(deps[k]) == "table" then
        for sk, sv in pairs(v) do deps[k][sk] = sv end
      else
        deps[k] = v
      end
    end
  end
  local overrides = {
    ["src.turn.actions.validator"] = deps.validator,
    ["src.state.runtime"] = deps.runtime_state,
    ["src.rules.market"] = deps.market_service,
  }
  local originals = {}
  for module_name, stub in pairs(overrides) do
    originals[module_name] = package.loaded[module_name]
    package.loaded[module_name] = stub
  end
  local original_dispatcher = package.loaded["src.turn.actions.action_dispatcher"]
  package.loaded["src.turn.actions.action_dispatcher"] = nil
  local ok, dispatcher = pcall(require, "src.turn.actions.action_dispatcher")
  package.loaded["src.turn.actions.action_dispatcher"] = original_dispatcher
  for module_name in pairs(overrides) do
    package.loaded[module_name] = originals[module_name]
  end
  if not ok then
    error(dispatcher)
  end
  dispatcher.step_turn = function() end
  dispatcher.clear_choice = function() end
  deps.turn_dispatch_ref = dispatcher
  return dispatcher, deps
end

local function _ctx(overrides)
  overrides = overrides or {}
  return {
    output_ports = {
      invalidate_ui_model = function() return true end,
      get_pending_choice = function() return overrides.pending_choice end,
      sync_pending_choice = function() return true end,
    },
    ui_sync_ports = { get_ui_state = function() return nil end },
    clock_ports = overrides.clock_ports or { wall_now_seconds = function() return 0 end },
    item_slot_source = nil,
  }
end

describe("action_dispatch _allow_next_turn boundary L53 diff >= cooldown", function()
  -- Drive ui_button id=next with preset locked state so we hit the diff branch.

  local function _drive(now_value, last_click_value)
    local dispatcher = _build()
    local game = {
      turn = { phase = "wait_action" },
      dispatch_action = function() end,
      find_player_by_id = function() return { id = 1, auto = false } end,
      players = { { id = 1 } },
    }
    local state = {
      _turn_runtime = {
        next_turn_locked = true,
        next_turn_last_click = last_click_value,
        next_turn_lock_phase = "wait_action",
      },
    }
    local action = { type = "ui_button", id = "next", actor_role_id = 1 }
    local ctx = _ctx({
      clock_ports = {
        wall_now_seconds = function() return now_value end,
        wall_diff_seconds = function(t1, t2) return t1 - t2 end,
      },
    })
    return dispatcher.dispatch_action(game, state, action, nil, ctx)
  end

  it("diff exactly == cooldown (0.4) → applied (>= edge inclusive)", function()
    local result = _drive(defaults.next_turn_cooldown, 0)
    _assert_eq(result.status, "applied", "diff == cooldown must be allowed (>= boundary)")
  end)

  it("diff just below cooldown (0.39) → rejected", function()
    local result = _drive(defaults.next_turn_cooldown - 0.01, 0)
    _assert_eq(result.status, "rejected", "diff < cooldown must reject (still locked)")
  end)

  it("diff well above cooldown → applied", function()
    local result = _drive(defaults.next_turn_cooldown + 5.0, 0)
    _assert_eq(result.status, "applied", "diff > cooldown must allow")
  end)
end)

describe("action_dispatch _allow_next_turn early-return arms L43/L46/L50", function()
  it("L43-44: not locked → applied immediately regardless of diff", function()
    local dispatcher = _build()
    local game = {
      turn = { phase = "wait_action" },
      dispatch_action = function() end,
      find_player_by_id = function() return { id = 1 } end,
      players = { { id = 1 } },
    }
    local state = {
      _turn_runtime = {
        next_turn_locked = false,
        next_turn_last_click = 100,  -- would fail diff check if locked
        next_turn_lock_phase = "wait_action",
      },
    }
    local action = { type = "ui_button", id = "next", actor_role_id = 1 }
    local ctx = _ctx({ clock_ports = { wall_now_seconds = function() return 0 end } })
    local result = dispatcher.dispatch_action(game, state, action, nil, ctx)
    _assert_eq(result.status, "applied", "not locked must short-circuit to applied")
  end)

  it("L46-47: phase changed → applied (lock_phase != current phase)", function()
    local dispatcher = _build()
    local game = {
      turn = { phase = "wait_action" },
      dispatch_action = function() end,
      find_player_by_id = function() return { id = 1 } end,
      players = { { id = 1 } },
    }
    local state = {
      _turn_runtime = {
        next_turn_locked = true,
        next_turn_last_click = 100,
        next_turn_lock_phase = "different_phase",
      },
    }
    local action = { type = "ui_button", id = "next", actor_role_id = 1 }
    local ctx = _ctx({ clock_ports = { wall_now_seconds = function() return 0 end } })
    local result = dispatcher.dispatch_action(game, state, action, nil, ctx)
    _assert_eq(result.status, "applied", "lock_phase mismatch must short-circuit to applied")
  end)

  it("L49-50: locked but last_click is nil → applied", function()
    local dispatcher = _build()
    local game = {
      turn = { phase = "wait_action" },
      dispatch_action = function() end,
      find_player_by_id = function() return { id = 1 } end,
      players = { { id = 1 } },
    }
    local state = {
      _turn_runtime = {
        next_turn_locked = true,
        next_turn_last_click = nil,
        next_turn_lock_phase = "wait_action",
      },
    }
    local action = { type = "ui_button", id = "next", actor_role_id = 1 }
    local ctx = _ctx({ clock_ports = { wall_now_seconds = function() return 0 end } })
    local result = dispatcher.dispatch_action(game, state, action, nil, ctx)
    _assert_eq(result.status, "applied", "last_click nil must short-circuit to applied")
  end)
end)

describe("action_dispatch _handle_next_turn lock side-effect L63-65", function()
  it("after applied next_turn, state._turn_runtime.next_turn_locked becomes true", function()
    local dispatcher = _build()
    local game = {
      turn = { phase = "wait_action" },
      dispatch_action = function() end,
      find_player_by_id = function() return { id = 1 } end,
      players = { { id = 1 } },
    }
    local state = {}
    local action = { type = "ui_button", id = "next", actor_role_id = 1 }
    local ctx = _ctx({ clock_ports = { wall_now_seconds = function() return 1.5 end } })
    dispatcher.dispatch_action(game, state, action, nil, ctx)
    _assert_eq(state._turn_runtime.next_turn_locked, true, "L63: lock flag set true")
    _assert_eq(state._turn_runtime.next_turn_last_click, 1.5, "L64: last_click recorded as wall_now")
    _assert_eq(state._turn_runtime.next_turn_lock_phase, "wait_action", "L65: lock_phase recorded as current phase")
  end)

  it("L66-67: phase wait_action → game:dispatch_action called", function()
    local dispatcher = _build()
    local dispatched_actions = {}
    local game = {
      turn = { phase = "wait_action" },
      dispatch_action = function(_, a) dispatched_actions[#dispatched_actions + 1] = a end,
      find_player_by_id = function() return { id = 1 } end,
      players = { { id = 1 } },
    }
    local state = {}
    local action = { type = "ui_button", id = "next", actor_role_id = 1 }
    local ctx = _ctx()
    dispatcher.dispatch_action(game, state, action, nil, ctx)
    _assert_eq(#dispatched_actions, 1, "phase wait_action must dispatch via game:dispatch_action")
    _assert_eq(dispatched_actions[1], action, "exact same action passed through")
  end)

  it("L68-70: phase NOT wait_action → turn_dispatch_ref.step_turn called", function()
    local dispatcher, deps = _build()
    local step_turn_calls = 0
    deps.turn_dispatch_ref.step_turn = function() step_turn_calls = step_turn_calls + 1 end
    local game = {
      turn = { phase = "different_phase" },
      dispatch_action = function() error("should NOT be called when phase != wait_action") end,
      find_player_by_id = function() return { id = 1 } end,
      players = { { id = 1 } },
    }
    local state = {}
    local action = { type = "ui_button", id = "next", actor_role_id = 1 }
    local ctx = _ctx()
    dispatcher.dispatch_action(game, state, action, nil, ctx)
    _assert_eq(step_turn_calls, 1, "non-wait_action phase must invoke step_turn exactly once")
  end)
end)

describe("action_dispatch _handle_ui_button rejection literals L84/L91", function()
  it("L84: slot_result.ok == false → status='rejected' literal", function()
    local dispatcher, deps = _build()
    deps.validator.resolve_item_slot_action = function() return { ok = false } end
    local game = {
      turn = { phase = "wait_action" },
      dispatch_action = function() end,
      find_player_by_id = function() return { id = 1 } end,
      players = { { id = 1 } },
    }
    local action = { type = "ui_button", id = "item_slot_3", actor_role_id = 1 }
    local result = dispatcher.dispatch_action(game, {}, action, nil, _ctx())
    _assert_eq(result.status, "rejected", "L84: 'rejected' literal must surface on slot_result not ok")
  end)

  it("L91: action.id not auto/next/slot → fallthrough rejected literal", function()
    local dispatcher = _build()
    local game = {
      turn = { phase = "wait_action" },
      dispatch_action = function() end,
      find_player_by_id = function() return { id = 1 } end,
      players = { { id = 1 } },
    }
    -- "some_other_id" is not auto / next / item_slot_N; slot_result returns nil (default)
    local action = { type = "ui_button", id = "some_other_id", actor_role_id = 1 }
    local result = dispatcher.dispatch_action(game, {}, action, nil, _ctx())
    _assert_eq(result.status, "rejected", "L91: 'rejected' literal must surface on fallthrough")
  end)

  it("L78-79: validator.validate_actor_role false → status='rejected'", function()
    local dispatcher, deps = _build()
    deps.validator.validate_actor_role = function() return false end
    local game = {
      turn = { phase = "wait_action" },
      dispatch_action = function() end,
      find_player_by_id = function() return { id = 1 } end,
      players = { { id = 1 } },
    }
    local action = { type = "ui_button", id = "next", actor_role_id = 1 }
    local result = dispatcher.dispatch_action(game, {}, action, nil, _ctx())
    _assert_eq(result.status, "rejected", "validate_actor_role false must reject")
  end)

  it("L86: slot_result.ok=true and action provided → dispatches to that action", function()
    local dispatcher, deps = _build()
    local sub_action = { type = "choice_select", choice_id = "C", actor_role_id = 1 }
    deps.validator.resolve_item_slot_action = function() return { ok = true, action = sub_action } end
    deps.validator.validate_choice_action = function() return true end
    local dispatched_actions = {}
    local game = {
      turn = { phase = "wait_action", pending_choice = { kind = "choice", id = "C" } },
      dispatch_action = function(_, a) dispatched_actions[#dispatched_actions + 1] = a end,
      find_player_by_id = function() return { id = 1 } end,
      players = { { id = 1 } },
    }
    local action = { type = "ui_button", id = "item_slot_1", actor_role_id = 1 }
    local result = dispatcher.dispatch_action(game, {}, action, nil, _ctx({
      pending_choice = { id = "C" },
    }))
    _assert_eq(result.status, "applied", "slot action chain must apply")
    _assert_eq(dispatched_actions[1], sub_action, "chained slot action must reach game:dispatch_action")
  end)
end)

describe("action_dispatch _handle_choice_action pending consistency L112-L113", function()
  -- `choice` is captured pre-dispatch via _resolve_pending_choice; `pending` is re-read
  -- post-dispatch from game.turn.pending_choice. They diverge when game:dispatch_action mutates
  -- the choice state. To exercise L113's three sub-arms, drive game:dispatch_action with mutators.

  local function _drive(initial_pending, after_dispatch_pending)
    local dispatcher, deps = _build()
    local clear_calls = 0
    deps.turn_dispatch_ref.clear_choice = function() clear_calls = clear_calls + 1 end
    local game = {
      turn = { phase = "wait_action", pending_choice = initial_pending },
      find_player_by_id = function() return { id = 1 } end,
      players = { { id = 1 } },
    }
    game.dispatch_action = function() game.turn.pending_choice = after_dispatch_pending end
    local action = { type = "choice_select", choice_id = "C", actor_role_id = 1 }
    -- ctx.output_ports.get_pending_choice is unused here because game.turn.pending_choice is non-nil pre-dispatch.
    dispatcher.dispatch_action(game, {}, action, nil, _ctx({ pending_choice = nil }))
    return clear_calls
  end

  it("choice present + post-dispatch pending nil → clear_choice called (L113 'not pending')", function()
    local clears = _drive({ id = "C", kind = "choice" }, nil)
    _assert_eq(clears, 1, "post-dispatch pending nil: clear_choice must be called")
  end)

  it("choice present + post-dispatch pending without id → clear_choice called (L113 'not pending.id')", function()
    local clears = _drive({ id = "C", kind = "choice" }, { kind = "choice" })
    _assert_eq(clears, 1, "post-dispatch pending missing id: clear_choice must be called")
  end)

  it("choice present + post-dispatch pending.id MATCHES choice.id → clear_choice NOT called", function()
    -- game:dispatch_action leaves the same pending_choice in place (unchanged)
    local clears = _drive({ id = "C", kind = "choice" }, { id = "C", kind = "choice" })
    _assert_eq(clears, 0, "matching ids: clear_choice must NOT be called")
  end)

  it("choice present + post-dispatch pending.id MISMATCHES choice.id → clear_choice called (L113 'pending.id ~= choice.id')", function()
    local clears = _drive({ id = "C", kind = "choice" }, { id = "OTHER", kind = "choice" })
    _assert_eq(clears, 1, "mismatching ids: clear_choice must be called")
  end)

  it("no choice resolved (game.turn nil + ctx returns nil) → clear_choice NOT called (L113 'choice and' guard)", function()
    -- _resolve_pending_choice: turn=nil → ctx.output_ports.get_pending_choice → nil → choice=nil
    local dispatcher, deps = _build()
    local clear_calls = 0
    deps.turn_dispatch_ref.clear_choice = function() clear_calls = clear_calls + 1 end
    local game = {
      turn = nil,
      dispatch_action = function() end,
      find_player_by_id = function() return { id = 1 } end,
      players = { { id = 1 } },
    }
    local action = { type = "choice_select", choice_id = "C", actor_role_id = 1 }
    dispatcher.dispatch_action(game, {}, action, nil, _ctx({ pending_choice = nil }))
    _assert_eq(clear_calls, 0, "no choice anywhere: clear_choice must NOT be called")
  end)
end)

describe("action_dispatch resolve_gate_state cap L149", function()
  it("gate_state result threads through to should_block_action verbatim", function()
    -- L149 mutation `→nil` makes gate_state = nil. We assert that should_block_action sees the
    -- non-nil real return when unmuted, and a different decision occurs vs nil.
    local resolve_returns = { allow = true }
    local should_block_seen_gate
    local dispatcher = _build({
      validator = {
        resolve_gate_state = function() return resolve_returns end,
        should_block_action = function(gate_state, _)
          should_block_seen_gate = gate_state
          return gate_state == nil  -- block only when nil → catches L149 mutation
        end,
      },
    })
    local game = {
      turn = { phase = "wait_action" },
      dispatch_action = function() end,
      find_player_by_id = function() return { id = 1 } end,
      players = { { id = 1 } },
    }
    local action = { type = "ui_button", id = "next", actor_role_id = 1 }
    local result = dispatcher.dispatch_action(game, {}, action, nil, _ctx())
    assert(should_block_seen_gate == resolve_returns,
      "L149: should_block_action must receive the resolve_gate_state return verbatim")
    _assert_eq(result.status, "applied",
      "gate_state truthy must NOT block; ensures L149 returned non-nil")
  end)
end)

describe("action_dispatch _handle_choice_action validate_choice_action rejection", function()
  it("L105-106: validate_choice_action false → status='rejected'", function()
    local dispatcher, deps = _build()
    deps.validator.validate_choice_action = function() return false end
    local game = {
      turn = { phase = "wait_action", pending_choice = { id = "C" } },
      dispatch_action = function() error("must not dispatch when validate fails") end,
      find_player_by_id = function() return { id = 1 } end,
      players = { { id = 1 } },
    }
    local action = { type = "choice_select", choice_id = "C", actor_role_id = 1 }
    local result = dispatcher.dispatch_action(game, {}, action, nil, _ctx({
      pending_choice = { id = "C" },
    }))
    _assert_eq(result.status, "rejected", "validate_choice_action false must reject")
  end)
end)
