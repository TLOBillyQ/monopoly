local P = require("spec.support.shared_support")
local _assert_eq = P.assert_eq

local ui_button_dispatch = require("src.turn.actions.ui_button_dispatch")
local defaults = require("src.turn.actions.defaults")

local function _validator(overrides)
  local base = {
    validate_actor_role = function() return true end,
    resolve_item_slot_action = function() return nil end,
  }
  for k, v in pairs(overrides or {}) do
    base[k] = v
  end
  return base
end

local function _runtime_state()
  return {
    ensure_turn_runtime = function(state)
      state._turn_runtime = state._turn_runtime or {}
      return state._turn_runtime
    end,
  }
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

describe("ui_button_dispatch.handle auto toggle", function()
  it("toggles player.auto when actor resolves", function()
    local player = { id = 1, auto = false }
    local game = _game({ find_player_by_id = function() return player end })
    local action = { id = "auto", actor_role_id = 1 }
    local result = ui_button_dispatch.handle(game, {}, action, nil, _ctx(), _validator(), _runtime_state(), {}, function() end)
    _assert_eq(result.status, "applied", "auto toggle must apply")
    _assert_eq(player.auto, true, "auto must flip false->true")
  end)

  it("rejects when no actor resolves", function()
    local game = _game({ find_player_by_id = function() return nil end })
    local action = { id = "auto", actor_role_id = nil }
    local result = ui_button_dispatch.handle(game, {}, action, nil, _ctx(), _validator(), _runtime_state(), {}, function() end)
    _assert_eq(result.status, "rejected", "auto toggle without actor must reject")
  end)
end)

describe("ui_button_dispatch.handle cancel", function()
  it("rejects when validate_actor_role fails", function()
    local game = _game()
    local action = { id = "cancel", actor_role_id = 1 }
    local validator = _validator({ validate_actor_role = function() return false end })
    local result = ui_button_dispatch.handle(game, {}, action, nil, _ctx(), validator, _runtime_state(), {}, function() end)
    _assert_eq(result.status, "rejected", "invalid actor must reject cancel")
  end)

  it("resolves pending choice from game.turn and rejects when allow_cancel is false", function()
    local game = _game({ turn = { phase = "wait_action", pending_choice = { id = "c1", allow_cancel = false } } })
    local action = { id = "cancel", actor_role_id = 1 }
    local result = ui_button_dispatch.handle(game, {}, action, nil, _ctx(), _validator(), _runtime_state(), {}, function() end)
    _assert_eq(result.status, "rejected", "allow_cancel=false must reject")
  end)

  it("rejects when neither game.turn nor output_ports has a pending choice", function()
    local game = _game({ turn = { phase = "wait_action", pending_choice = nil } })
    local action = { id = "cancel", actor_role_id = 1 }
    local ctx = _ctx({ output_ports = {} })
    local result = ui_button_dispatch.handle(game, {}, action, nil, ctx, _validator(), _runtime_state(), {}, function() end)
    _assert_eq(result.status, "rejected", "no pending choice anywhere must reject")
  end)

  it("falls back to ctx.output_ports.get_pending_choice when game.turn has none", function()
    local game = _game({ turn = { phase = "wait_action", pending_choice = nil } })
    local action = { id = "cancel", actor_role_id = 1, input_source = "user" }
    local ctx = _ctx({ pending_choice = { id = "c9", allow_cancel = true } })
    local dispatched = {}
    local result = ui_button_dispatch.handle(game, {}, action, nil, ctx, _validator(), _runtime_state(), {}, function(_, _, a)
      dispatched[#dispatched + 1] = a
      return { status = "applied" }
    end)
    _assert_eq(result.status, "applied", "port-resolved choice must allow cancel")
    _assert_eq(dispatched[1].type, "choice_cancel", "cancel must dispatch a choice_cancel action")
    _assert_eq(dispatched[1].choice_id, "c9", "dispatched choice_cancel must carry the resolved choice id")
  end)

  it("dispatches choice_cancel using game.turn.pending_choice when present", function()
    local game = _game({ turn = { phase = "wait_action", pending_choice = { id = "c1", allow_cancel = true } } })
    local action = { id = "cancel", actor_role_id = 1, input_source = "remote" }
    local dispatched = {}
    local result = ui_button_dispatch.handle(game, {}, action, nil, _ctx(), _validator(), _runtime_state(), {}, function(_, _, a)
      dispatched[#dispatched + 1] = a
      return { status = "applied" }
    end)
    _assert_eq(result.status, "applied", "cancel with valid choice must apply")
    _assert_eq(dispatched[1].choice_id, "c1", "dispatched choice_cancel must carry game.turn's choice id")
    _assert_eq(dispatched[1].input_source, "remote", "dispatched choice_cancel must preserve input_source")
  end)
end)

describe("ui_button_dispatch.handle item slot and next", function()
  it("rejects when validate_actor_role fails", function()
    local game = _game()
    local action = { id = "item_slot_1", actor_role_id = 1 }
    local validator = _validator({ validate_actor_role = function() return false end })
    local result = ui_button_dispatch.handle(game, {}, action, nil, _ctx(), validator, _runtime_state(), {}, function() end)
    _assert_eq(result.status, "rejected", "invalid actor must reject slot action")
  end)

  it("rejects when slot_result.ok is false", function()
    local game = _game()
    local action = { id = "item_slot_3", actor_role_id = 1 }
    local validator = _validator({ resolve_item_slot_action = function() return { ok = false } end })
    local result = ui_button_dispatch.handle(game, {}, action, nil, _ctx(), validator, _runtime_state(), {}, function() end)
    _assert_eq(result.status, "rejected", "slot_result.ok=false must reject")
  end)

  it("dispatches the chained action when slot_result.ok is true", function()
    local game = _game()
    local sub_action = { type = "choice_select", choice_id = "C", actor_role_id = 1 }
    local validator = _validator({ resolve_item_slot_action = function() return { ok = true, action = sub_action } end })
    local dispatched = {}
    local result = ui_button_dispatch.handle(game, {}, { id = "item_slot_1", actor_role_id = 1 }, nil, _ctx(), validator, _runtime_state(), {}, function(_, _, a)
      dispatched[#dispatched + 1] = a
      return { status = "applied" }
    end)
    _assert_eq(result.status, "applied", "slot chain must apply")
    _assert_eq(dispatched[1], sub_action, "chained slot action must reach dispatch_action")
  end)

  it("falls through to _handle_next_turn for id=next when no slot result", function()
    local game = _game()
    local action = { id = "next", actor_role_id = 1 }
    local dispatched_actions = {}
    game.dispatch_action = function(_, a) dispatched_actions[#dispatched_actions + 1] = a end
    local result = ui_button_dispatch.handle(game, {}, action, nil, _ctx(), _validator(), _runtime_state(), { step_turn = function() end }, function() end)
    _assert_eq(result.status, "applied", "next with no lock must apply")
    _assert_eq(#dispatched_actions, 1, "wait_action phase must dispatch via game:dispatch_action")
  end)

  it("rejects unrecognized ids that are neither auto/cancel/slot/next", function()
    local game = _game()
    local action = { id = "some_other_id", actor_role_id = 1 }
    local result = ui_button_dispatch.handle(game, {}, action, nil, _ctx(), _validator(), _runtime_state(), {}, function() end)
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
    local action = { id = "next", actor_role_id = 1 }
    local ctx = _ctx({
      clock_ports = {
        wall_now_seconds = function() return defaults.next_turn_cooldown - 0.01 end,
        wall_diff_seconds = function(t1, t2) return t1 - t2 end,
      },
    })
    local result = ui_button_dispatch.handle(game, state, action, nil, ctx, _validator(), _runtime_state(), { step_turn = function() end }, function() end)
    _assert_eq(result.status, "rejected", "diff below cooldown while locked must reject")
  end)
end)
