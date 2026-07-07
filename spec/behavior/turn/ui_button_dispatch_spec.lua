-- Pins for the ui_button handling that now lives inside
-- src/turn/actions/action_dispatcher.lua (auto toggle / cancel forwarding /
-- item slot chaining / next-turn cooldown lock). Driven through the public
-- dispatch_action entry with stubbed validator/runtime_state modules.
local P = require("spec.support.shared_support")
local _assert_eq = P.assert_eq

local defaults = require("src.turn.actions.defaults")

local function _build(validator_overrides)
  local deps = {
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
  }
  -- 单入口 validate 委托 stub 自身的 validate_choice_action，per-test 覆写仍生效。
  deps.validator.validate = function(action, ctx)
    ctx = ctx or {}
    return deps.validator.validate_choice_action(ctx.game, action, ctx.choice)
  end
  for k, v in pairs(validator_overrides or {}) do
    deps.validator[k] = v
  end
  local overrides = {
    ["src.turn.actions.validator"] = deps.validator,
    ["src.state.runtime"] = deps.runtime_state,
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
  return dispatcher
end

local function _game(overrides)
  local base = {
    turn = { phase = "wait_action", pending_choice = nil },
    dispatch_action = function() end,
    find_player_by_id = function() return { id = 1, auto = false } end,
    players = { { id = 1 } },
  }
  for k, v in pairs(overrides or {}) do
    base[k] = v
  end
  return base
end

local function _ctx(overrides)
  overrides = overrides or {}
  return {
    output_ports = overrides.output_ports or {
      get_pending_choice = function() return overrides.pending_choice end,
    },
    item_slot_source = overrides.item_slot_source,
    clock_ports = overrides.clock_ports or { wall_now_seconds = function() return 0 end },
  }
end

local function _ui_button(id, extra)
  local action = { type = "ui_button", id = id, actor_role_id = 1 }
  for k, v in pairs(extra or {}) do
    action[k] = v
  end
  return action
end

describe("action_dispatcher ui_button auto toggle", function()
  it("toggles player.auto when actor resolves", function()
    local player = { id = 1, auto = false }
    local game = _game({ find_player_by_id = function() return player end })
    local result = _build().dispatch_action_with_ctx(game, {}, _ui_button("auto"), nil, _ctx())
    _assert_eq(result.status, "applied", "auto toggle must apply")
    _assert_eq(player.auto, true, "auto must flip false->true")
  end)

  it("rejects when no actor resolves", function()
    local game = _game({ find_player_by_id = function() return nil end })
    local action = { type = "ui_button", id = "auto", actor_role_id = nil }
    local result = _build().dispatch_action_with_ctx(game, {}, action, nil, _ctx())
    _assert_eq(result.status, "rejected", "auto toggle without actor must reject")
  end)
end)

describe("action_dispatcher ui_button cancel", function()
  it("rejects when validate_actor_role fails", function()
    local game = _game()
    local dispatcher = _build({ validate_actor_role = function() return false end })
    local result = dispatcher.dispatch_action_with_ctx(game, {}, _ui_button("cancel"), nil, _ctx())
    _assert_eq(result.status, "rejected", "invalid actor must reject cancel")
  end)

  it("resolves pending choice from game.turn and rejects when allow_cancel is false", function()
    local game = _game({ turn = { phase = "wait_action", pending_choice = { id = "c1", allow_cancel = false } } })
    local result = _build().dispatch_action_with_ctx(game, {}, _ui_button("cancel"), nil, _ctx())
    _assert_eq(result.status, "rejected", "allow_cancel=false must reject")
  end)

  it("rejects when neither game.turn nor output_ports has a pending choice", function()
    local game = _game({ turn = { phase = "wait_action", pending_choice = nil } })
    local ctx = _ctx({ output_ports = {} })
    local result = _build().dispatch_action_with_ctx(game, {}, _ui_button("cancel"), nil, ctx)
    _assert_eq(result.status, "rejected", "no pending choice anywhere must reject")
  end)

  it("falls back to ctx.output_ports.get_pending_choice when game.turn has none", function()
    local dispatched = {}
    local game = _game({
      turn = { phase = "wait_action", pending_choice = nil },
      dispatch_action = function(_, a) dispatched[#dispatched + 1] = a end,
    })
    local ctx = _ctx({ pending_choice = { id = "c9", allow_cancel = true } })
    local action = _ui_button("cancel", { input_source = "user" })
    local result = _build().dispatch_action_with_ctx(game, {}, action, nil, ctx)
    _assert_eq(result.status, "applied", "port-resolved choice must allow cancel")
    _assert_eq(dispatched[1].type, "choice_cancel", "cancel must dispatch a choice_cancel action")
    _assert_eq(dispatched[1].choice_id, "c9", "dispatched choice_cancel must carry the resolved choice id")
  end)

  it("dispatches choice_cancel using game.turn.pending_choice when present", function()
    local dispatched = {}
    local game = _game({
      turn = { phase = "wait_action", pending_choice = { id = "c1", allow_cancel = true } },
      dispatch_action = function(_, a) dispatched[#dispatched + 1] = a end,
    })
    local action = _ui_button("cancel", { input_source = "remote" })
    local result = _build().dispatch_action_with_ctx(game, {}, action, nil, _ctx())
    _assert_eq(result.status, "applied", "cancel with valid choice must apply")
    _assert_eq(dispatched[1].choice_id, "c1", "dispatched choice_cancel must carry game.turn's choice id")
    _assert_eq(dispatched[1].input_source, "remote", "dispatched choice_cancel must preserve input_source")
  end)
end)

describe("action_dispatcher ui_button item slot and next", function()
  it("rejects when validate_actor_role fails", function()
    local game = _game()
    local dispatcher = _build({ validate_actor_role = function() return false end })
    local result = dispatcher.dispatch_action_with_ctx(game, {}, _ui_button("item_slot_1"), nil, _ctx())
    _assert_eq(result.status, "rejected", "invalid actor must reject slot action")
  end)

  it("rejects when slot_result.ok is false", function()
    local game = _game()
    local dispatcher = _build({ resolve_item_slot_action = function() return { ok = false } end })
    local result = dispatcher.dispatch_action_with_ctx(game, {}, _ui_button("item_slot_3"), nil, _ctx())
    _assert_eq(result.status, "rejected", "slot_result.ok=false must reject")
  end)

  it("dispatches the chained action when slot_result.ok is true", function()
    local dispatched = {}
    local sub_action = { type = "choice_select", choice_id = "C", actor_role_id = 1 }
    local game = _game({
      turn = { phase = "wait_action", pending_choice = { id = "C", kind = "choice" } },
      dispatch_action = function(_, a) dispatched[#dispatched + 1] = a end,
    })
    local dispatcher = _build({ resolve_item_slot_action = function() return { ok = true, action = sub_action } end })
    local result = dispatcher.dispatch_action_with_ctx(game, {}, _ui_button("item_slot_1"), nil, _ctx())
    _assert_eq(result.status, "applied", "slot chain must apply")
    _assert_eq(dispatched[1], sub_action, "chained slot action must reach dispatch_action")
  end)

  it("falls through to the next-turn handler for id=next when no slot result", function()
    local dispatched_actions = {}
    local game = _game()
    game.dispatch_action = function(_, a) dispatched_actions[#dispatched_actions + 1] = a end
    local result = _build().dispatch_action_with_ctx(game, {}, _ui_button("next"), nil, _ctx())
    _assert_eq(result.status, "applied", "next with no lock must apply")
    _assert_eq(#dispatched_actions, 1, "wait_action phase must dispatch via game:dispatch_action")
  end)

  it("rejects unrecognized ids that are neither auto/cancel/slot/next", function()
    local game = _game()
    local result = _build().dispatch_action_with_ctx(game, {}, _ui_button("some_other_id"), nil, _ctx())
    _assert_eq(result.status, "rejected", "unrecognized id must reject")
  end)

  it("next turn respects the cooldown lock via clock_ports diff", function()
    local game = _game({ turn = { phase = "wait_action" } })
    local state = {
      _turn_runtime = {
        next_turn_locked = true,
        next_turn_last_click = 0,
        next_turn_lock_phase = "wait_action",
      },
    }
    local ctx = _ctx({
      clock_ports = {
        wall_now_seconds = function() return defaults.next_turn_cooldown - 0.01 end,
        wall_diff_seconds = function(t1, t2) return t1 - t2 end,
      },
    })
    local result = _build().dispatch_action_with_ctx(game, state, _ui_button("next"), nil, ctx)
    _assert_eq(result.status, "rejected", "diff below cooldown while locked must reject")
  end)
end)
