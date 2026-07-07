local validator = require("src.turn.actions.validator")
local runtime_state = require("src.state.runtime")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _make_game_with_player(role_id, current_index)
  current_index = current_index or 1
  return {
    turn = {
      current_player_index = current_index,
    },
    players = {
      [current_index] = { id = role_id },
    },
  }
end

local function _item_phase_state(choice)
  local state = {}
  runtime_state.set_pending_choice(state, choice)
  return state
end

local function _slot_source(item_id)
  return {
    resolve_slot_action = function() return item_id end,
  }
end

describe("domain validator single entry validate(action, ctx)", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  -- 表驱动：动作 + 上下文 → 放行与否 + 原因。ctx 为函数时惰性构建。
  local cases = {
    -- 入参兜底
    {
      name = "nil action is refused with missing_action",
      action = nil,
      ctx = {},
      ok = false,
      reason = "missing_action",
    },
    {
      name = "unknown action types pass through unvalidated",
      action = { type = "roll_dice" },
      ctx = {},
      ok = true,
    },
    -- 输入闸门
    {
      name = "gate_state with input_blocked refuses choice_select",
      action = { type = "choice_select", actor_role_id = 1001, choice_id = 10 },
      ctx = function()
        return { gate_state = { input_blocked = true }, choice = { id = 10, owner_role_id = 1001 } }
      end,
      ok = false,
      reason = "input_blocked",
    },
    {
      name = "gate_state without input_blocked lets a valid choice through",
      action = { type = "choice_select", actor_role_id = 1001, choice_id = 10 },
      ctx = function()
        return { gate_state = { input_blocked = false }, choice = { id = 10, owner_role_id = 1001 } }
      end,
      ok = true,
    },
    -- ui_button 行动人校验
    {
      name = "ui_button non-turn-bound action always passes",
      action = { type = "ui_button", id = "buy", actor_role_id = 1002 },
      ctx = function() return { game = _make_game_with_player(1001) } end,
      ok = true,
    },
    {
      name = "ui_button next with matching actor passes",
      action = { type = "ui_button", id = "next", actor_role_id = 1001 },
      ctx = function() return { game = _make_game_with_player(1001) } end,
      ok = true,
    },
    {
      name = "ui_button next with nil actor_role_id is refused",
      action = { type = "ui_button", id = "next", actor_role_id = nil },
      ctx = function() return { game = _make_game_with_player(1001) } end,
      ok = false,
      reason = "actor_not_current",
    },
    {
      name = "ui_button next with missing current player is refused",
      action = { type = "ui_button", id = "next", actor_role_id = 1001 },
      ctx = { game = { turn = { current_player_index = 1 }, players = {} } },
      ok = false,
      reason = "actor_not_current",
    },
    {
      name = "ui_button next with wrong actor is refused",
      action = { type = "ui_button", id = "next", actor_role_id = 1002 },
      ctx = function() return { game = _make_game_with_player(1001) } end,
      ok = false,
      reason = "actor_not_current",
    },
    -- choice 类动作校验
    {
      name = "choice action without pending choice is refused",
      action = { type = "choice_select", actor_role_id = 1001, choice_id = 10 },
      ctx = {},
      ok = false,
      reason = "missing_choice",
    },
    {
      name = "choice action against a choice without id is refused",
      action = { type = "choice_select", actor_role_id = 1001, choice_id = 10 },
      ctx = { choice = {} },
      ok = false,
      reason = "missing_choice",
    },
    {
      name = "choice action with nil actor_role_id is refused",
      action = { type = "choice_select", actor_role_id = nil, choice_id = 10 },
      ctx = { game = {}, choice = { id = 10, kind = "market_buy" } },
      ok = false,
      reason = "choice_actor_mismatch",
    },
    {
      name = "choice action with nil owner accepts any actor",
      action = { type = "choice_select", actor_role_id = 1001, choice_id = 10 },
      ctx = { game = {}, choice = { id = 10, kind = "market_buy" } },
      ok = true,
    },
    {
      name = "choice action with matching owner passes",
      action = { type = "choice_select", actor_role_id = 1001, choice_id = 10 },
      ctx = { game = {}, choice = { id = 10, kind = "market_buy", owner_role_id = 1001 } },
      ok = true,
    },
    {
      name = "choice action with wrong owner is refused",
      action = { type = "choice_cancel", actor_role_id = 1002, choice_id = 10 },
      ctx = { game = {}, choice = { id = 10, kind = "market_buy", owner_role_id = 1001 } },
      ok = false,
      reason = "choice_actor_mismatch",
    },
    {
      name = "choice action with mismatched choice_id is refused",
      action = { type = "choice_select", actor_role_id = 1001, choice_id = 10 },
      ctx = { game = {}, choice = { id = 99, kind = "market_buy" } },
      ok = false,
      reason = "choice_id_mismatch",
    },
    {
      name = "choice action with nil action.choice_id is refused",
      action = { type = "choice_select", actor_role_id = 1001, choice_id = nil },
      ctx = { game = {}, choice = { id = 10, kind = "market_buy" } },
      ok = false,
      reason = "choice_id_mismatch",
    },
    -- item_slot 按钮：经完整解析链
    {
      name = "item_slot button with matching actor and valid slot passes",
      action = { type = "ui_button", id = "item_slot_1", actor_role_id = 1001 },
      ctx = function()
        return {
          game = _make_game_with_player(1001),
          state = _item_phase_state({ id = 5, kind = "item_phase_choice", options = { "item_a" } }),
          item_slot_source = _slot_source("item_a"),
        }
      end,
      ok = true,
    },
    {
      name = "item_slot button with wrong actor is refused before slot resolution",
      action = { type = "ui_button", id = "item_slot_2", actor_role_id = 9999 },
      ctx = function() return { game = _make_game_with_player(1001) } end,
      ok = false,
      reason = "actor_not_current",
    },
    {
      name = "item_slot button without pending item phase choice is refused",
      action = { type = "ui_button", id = "item_slot_1", actor_role_id = 1001 },
      ctx = function()
        return { game = _make_game_with_player(1001), state = {} }
      end,
      ok = false,
      reason = "missing_choice",
    },
    {
      name = "item_slot button without slot mapping is refused",
      action = { type = "ui_button", id = "item_slot_1", actor_role_id = 1001 },
      ctx = function()
        return {
          game = _make_game_with_player(1001),
          state = _item_phase_state({ id = 5, kind = "item_phase_choice", options = { "item_a" } }),
          item_slot_source = _slot_source(nil),
        }
      end,
      ok = false,
      reason = "missing_item_id",
    },
    {
      name = "item_slot button whose item is not in choice options is refused",
      action = { type = "ui_button", id = "item_slot_1", actor_role_id = 1001 },
      ctx = function()
        return {
          game = _make_game_with_player(1001),
          state = _item_phase_state({ id = 5, kind = "item_phase_choice", options = { "item_a" } }),
          item_slot_source = _slot_source("item_not_in_options"),
        }
      end,
      ok = false,
      reason = "invalid_item_option",
    },
    {
      name = "item_slot button resolves the choice from game.turn when state has none",
      action = { type = "ui_button", id = "item_slot_1", actor_role_id = 1001 },
      ctx = function()
        local game = _make_game_with_player(1001)
        game.turn.pending_choice = { id = 7, kind = "item_phase_choice", options = { "item_b" } }
        return { game = game, state = {}, item_slot_source = _slot_source("item_b") }
      end,
      ok = true,
    },
  }

  for _, case in ipairs(cases) do
    it(case.name, function()
      local ctx = type(case.ctx) == "function" and case.ctx() or case.ctx
      local ok, reason = validator.validate(case.action, ctx)
      _assert_eq(ok, case.ok, case.name .. " (ok)")
      _assert_eq(reason, case.reason, case.name .. " (reason)")
    end)
  end

  it("item_slot validate allowed by availability", function()
    local state = _item_phase_state({
      id = 5,
      kind = "item_phase_choice",
      options = { "item_a" },
      meta = { phase = "pre_action" },
    })
    local avail_mod = require("src.rules.items.availability")
    local saved = avail_mod.can_offer_in_phase
    avail_mod.can_offer_in_phase = function() return true end
    local game = _make_game_with_player(1001)
    game.find_player_by_id = function(_, _) return { id = 1001 } end
    local ok, reason = validator.validate(
      { type = "ui_button", id = "item_slot_1", actor_role_id = 1001 },
      { game = game, state = state, item_slot_source = _slot_source("item_a") }
    )
    avail_mod.can_offer_in_phase = saved
    _assert_eq(ok, true, "availability allowed should validate")
    _assert_eq(reason, nil, "availability allowed should carry no reason")
  end)

  it("item_slot validate denied by availability", function()
    local state = _item_phase_state({
      id = 5,
      kind = "item_phase_choice",
      options = { "item_a" },
      meta = { phase = "items" },
    })
    local avail_mod = require("src.rules.items.availability")
    local saved = avail_mod.can_offer_in_phase
    avail_mod.can_offer_in_phase = function() return false end
    local game = _make_game_with_player(1001)
    game.find_player_by_id = function(_, _) return { id = 1001 } end
    local ok, reason = validator.validate(
      { type = "ui_button", id = "item_slot_1", actor_role_id = 1001 },
      { game = game, state = state, item_slot_source = _slot_source("item_a") }
    )
    avail_mod.can_offer_in_phase = saved
    _assert_eq(ok, false, "availability denial should refuse")
    _assert_eq(reason, "item_slot_denied_by_availability", "reason should be item_slot_denied_by_availability")
  end)
end)

describe("domain validator named surface", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("validate_choice_id nil action returns false", function()
    _assert_eq(validator.validate_choice_id(nil, { id = 10 }), false,
      "nil action should return false")
  end)

  it("validate_choice_id nil choice returns false", function()
    _assert_eq(validator.validate_choice_id({ choice_id = 10 }, nil), false,
      "nil choice should return false")
  end)

  it("validate_choice_id matching id returns true", function()
    _assert_eq(validator.validate_choice_id({ choice_id = 10 }, { id = 10 }), true,
      "matching choice_id should return true")
  end)

  it("validate_choice_action success", function()
    local choice = { id = 10, owner_role_id = 1001 }
    _assert_eq(validator.validate_choice_action({}, { actor_role_id = 1001, choice_id = 10 }, choice), true,
      "valid actor and choice_id should return true")
  end)

  it("validate_choice_action nil choice returns false", function()
    _assert_eq(validator.validate_choice_action({}, { actor_role_id = 1001, choice_id = 10 }, nil), false,
      "nil choice should return false")
  end)

  it("validate_actor_role next matching actor returns true", function()
    local game = _make_game_with_player(1001)
    _assert_eq(validator.validate_actor_role(game, { id = "next", actor_role_id = 1001 }), true,
      "'next' with matching actor should return true")
  end)

  it("resolve_item_slot_action returns nil on invalid_action", function()
    local result = validator.resolve_item_slot_action(nil, {}, { id = "buy" }, nil)
    _assert_eq(result, nil, "invalid_action should return nil")
  end)

  it("resolve_item_slot_action returns not-ok on other errors", function()
    local result = validator.resolve_item_slot_action(nil, {}, { id = "item_slot_1" }, nil)
    assert(result ~= nil, "non-invalid_action error should not return nil")
    _assert_eq(result.ok, false, "missing_choice should return {ok=false}")
  end)

  it("resolve_item_slot_action success returns the resolved choice_select action", function()
    local state = _item_phase_state({ id = 5, kind = "item_phase_choice", options = { "item_a" } })
    local result = validator.resolve_item_slot_action(
      _slot_source("item_a"), state,
      { id = "item_slot_1", actor_role_id = 1001, input_source = "touch" }, nil
    )
    _assert_eq(result.ok, true, "valid item slot action should succeed")
    assert(type(result.action) == "table", "success should include action")
    _assert_eq(result.action.type, "choice_select", "action type should be choice_select")
    _assert_eq(result.action.option_id, "item_a", "option_id should be item_a")
  end)

  it("resolve_gate_state without ports", function()
    local state = { game = { turn = { phase = "land" } } }
    local gate = validator.resolve_gate_state(state, nil)
    assert(type(gate) == "table", "should return gate table")
    _assert_eq(gate.phase, "land", "phase should be from game.turn")
    _assert_eq(gate.input_blocked, false, "input_blocked defaults to false")
    _assert_eq(gate.choice_active, false, "choice_active defaults to false")
    _assert_eq(gate.detained_wait_active, false, "detained_wait_active defaults to false")
  end)

  it("resolve_gate_state with ports", function()
    local state = {}
    local ui_sync_ports = {
      resolve_ui_gate = function(_)
        return { input_blocked = true, choice_active = true, market_active = false, popup_active = true }
      end,
    }
    local gate = validator.resolve_gate_state(state, ui_sync_ports)
    _assert_eq(gate.input_blocked, true, "input_blocked from ui_gate should be true")
    _assert_eq(gate.choice_active, true, "choice_active from ui_gate should be true")
    _assert_eq(gate.popup_active, true, "popup_active from ui_gate should be true")
  end)

  it("should_block_action blocked when input blocked", function()
    local result = validator.should_block_action(true, "choice_select")
    _assert_eq(result, true, "true gate_state should block choice_select action")
  end)

  it("should_block_action passes when not blocked", function()
    local result = validator.should_block_action(false, "choice_select")
    _assert_eq(result, false, "false gate_state should not block")
  end)
end)
