-- luacheck: ignore 211
local lu = require("luaunit")
local support = require("test.support.shared_support")
local shared_support = require("test.support.shared_support")

local bankruptcy_feedback_port = require("src.rules.ports.bankruptcy_feedback")
local turn_action_port = require("src.ui.input.turn_action")
local gameplay_loop_ports = require("src.turn.loop.ports")
local gameplay_loop_runtime = require("src.turn.loop.runtime")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local turn_roll = require("src.turn.phases.roll")
local turn_move = require("src.turn.phases.move")

TestUsecaseBoundary = {}

function TestUsecaseBoundary:test_turn_action_port_resolve_defaults()
  local resolved = turn_action_port.resolve({}, nil)
  local res = resolved.dispatch_action({}, {}, { type = "noop" }, {})
  lu.assertIs(res.status, "rejected", "default dispatch_action should reject")
  lu.assertIs(resolved.should_block_action({}, { type = "noop" }), false,
    "default should_block_action should be false")
end

function TestUsecaseBoundary:test_turn_action_port_override_precedence()
  local calls = 0
  local state = {
    turn_action_port = {
      dispatch_action = function()
        calls = calls + 1
        return { status = "state" }
      end,
      should_block_action = function()
        return false
      end,
    },
  }
  local resolved = turn_action_port.resolve(state, {
    turn_action_port = {
      dispatch_action = function()
        calls = calls + 1
        return { status = "override" }
      end,
      should_block_action = function()
        return true
      end,
    },
  })
  local res = resolved.dispatch_action({}, {}, { type = "noop" }, {})
  lu.assertIs(res.status, "override", "override port should take precedence over state port")
  lu.assertIs(calls, 1, "dispatch should call override implementation once")
  lu.assertIs(resolved.should_block_action({}, { type = "noop" }), true,
    "override should_block_action should take precedence")
end

function TestUsecaseBoundary:test_turn_action_port_normalize_auto_intent_contract()
  local state = {}
  local intent = { type = "ui_button", id = "auto", actor_role_id = 7 }
  support.with_patches({
    { target = turn_action_port, key = "normalize_auto_intent", value = turn_action_port.normalize_auto_intent },
    { key = "UIManager", value = { client_role = nil } },
  }, function()
    local out = turn_action_port.normalize_auto_intent(state, intent)
    lu.assertIs(out.type, "ui_button", "normalize should preserve type")
    lu.assertIs(out.id, "auto", "normalize should preserve button id")
    lu.assertIs(out.actor_role_id, 7, "normalize should preserve actor role fallback")
  end)
end

function TestUsecaseBoundary:test_turn_action_port_normalize_auto_intent_rejects_missing_actor()
  local state = {}
  local intent = { type = "ui_button", id = "auto" }
  support.with_patches({
    { key = "UIManager", value = { client_role = nil } },
  }, function()
    local out = turn_action_port.normalize_auto_intent(state, intent)
    lu.assertIs(out, nil, "normalize should reject auto intent without actor context")
  end)
end

function TestUsecaseBoundary:test_gameplay_loop_clock_contract_split_sources()
  runtime_ports.reset_for_tests()
  local default_ports = gameplay_loop_ports.resolve(nil)
  local default_clock = default_ports.clock
  lu.assertIs(default_clock.wall_now_seconds(), 0, "default wall clock should be environment-agnostic zero fallback")
  lu.assertIs(default_clock.wall_diff_seconds(9, 7), 2, "default wall diff should stay arithmetic fallback")
  lu.assertIs(default_clock.cpu_now_seconds(), 0, "default cpu clock should be environment-agnostic zero fallback")
  lu.assertIs(default_clock.cpu_diff_seconds(9, 7), 2, "default cpu diff should remain arithmetic")

  runtime_ports.configure({
    wall_now_seconds = function() return 42 end,
    wall_diff_seconds = function(a, b) return (a - b) * 10 end,
    cpu_now_seconds = function() return 1.5 end,
    cpu_diff_seconds = function(a, b) return a - b end,
  })
  local injected_ports = gameplay_loop_ports.resolve({
    clock = {
      wall_now_seconds = function()
        return runtime_ports.wall_now_seconds()
      end,
      wall_diff_seconds = function(a, b)
        return runtime_ports.wall_diff_seconds(a, b)
      end,
      cpu_now_seconds = function()
        return runtime_ports.cpu_now_seconds()
      end,
      cpu_diff_seconds = function(a, b)
        return runtime_ports.cpu_diff_seconds(a, b)
      end,
    },
  })
  local clock = injected_ports.clock
  lu.assertIs(clock.wall_now_seconds(), 42, "injected wall clock should be used when provided")
  lu.assertIs(clock.wall_diff_seconds(9, 7), 20, "injected wall diff should preserve injected semantics")
  lu.assertIs(clock.cpu_now_seconds(), 1.5, "injected cpu clock should be used when provided")
  lu.assertIs(clock.cpu_diff_seconds(9, 7), 2, "injected cpu diff should remain arithmetic")
  runtime_ports.reset_for_tests()
end

function TestUsecaseBoundary:test_choice_contract_copies_explicit_fields_once()
  local choice_contract = require("src.config.choice.contract")
  local source = {
    route_key = "target",
    requires_confirm = true,
    pre_confirm_on_select = false,
    owner_role_id = 8,
    confirm_title = "请确认",
    confirm_body = "你选的是：A",
    uses_item_slots = false,
    pre_confirm_before_slot_pick = false,
    active_tab = "item",
    page_index = 2,
    page_count = 3,
    phase = "pre_action",
    queue = { 2, 3 },
    effect_ids = { "buy_land" },
    move_result = { next_state = "wait_choice" },
  }
  local target = {}
  choice_contract.copy_explicit_fields(source, target)
  lu.assertIs(target.route_key, "target", "contract should copy route_key")
  lu.assertIs(target.pre_confirm_on_select, false, "contract should copy select pre-confirm flag")
  lu.assertIs(target.owner_role_id, 8, "contract should copy owner_role_id")
  lu.assertIs(target.page_count, 3, "contract should copy market paging fields")
  lu.assertIs(target.phase, nil, "contract should keep phase in meta")
  lu.assertIs(target.queue, nil, "contract should keep queue in meta")
  lu.assertIs(target.effect_ids, nil, "contract should keep effect_ids in meta")
  lu.assertIs(target.move_result, nil, "contract should keep move_result in meta")
end

function TestUsecaseBoundary:test_gameplay_loop_output_port_defaults_to_ui_runtime_only()
  local resolved = gameplay_loop_ports.resolve(nil)
  local state = {}
  local changed = resolved.output.invalidate_ui_model(state)
  lu.assertIs(changed, true, "default output.invalidate_ui_model should mark ui_runtime dirty")
  lu.assertIs(state.ui_dirty, nil, "default output.invalidate_ui_model should not mark legacy state.ui_dirty")
  lu.assertIs(state.ui_runtime and state.ui_runtime.ui_dirty, true,
    "default output.invalidate_ui_model should write ui_runtime")
  local changed_again = resolved.output.invalidate_ui_model(state)
  lu.assertIs(changed_again, false,
    "default output.invalidate_ui_model should be idempotent when ui_runtime already dirty")
end

function TestUsecaseBoundary:test_output_state_adapter_exposes_invalidate_ui_model_only()
  local output_state_adapter = require("src.turn.output.state_adapter")
  local output = output_state_adapter.build_runtime_output_ports()
  local state = {}
  local changed = output.invalidate_ui_model(state)
  lu.assertIs(changed, true, "runtime output.invalidate_ui_model should mark ui_runtime dirty")
  lu.assertIs(state.ui_runtime and state.ui_runtime.ui_dirty, true,
    "invalidate_ui_model should write ui_runtime dirty state")
end

function TestUsecaseBoundary:test_gameplay_loop_output_port_override_precedence()
  local calls = 0
  local resolved = gameplay_loop_ports.resolve({
    output = {
      invalidate_ui_model = function(state)
        calls = calls + 1
        state.override_called = true
        return true
      end,
    },
  })
  local state = {}
  local changed = resolved.output.invalidate_ui_model(state)
  lu.assertIs(changed, true, "override output.invalidate_ui_model should return override result")
  lu.assertIs(calls, 1, "override output.invalidate_ui_model should be called once")
  lu.assertIs(state.override_called, true, "override output.invalidate_ui_model should receive state")
  lu.assertIs(state.ui_dirty, nil, "override output.invalidate_ui_model should bypass default ui_dirty bridge")
end

function TestUsecaseBoundary:test_gameplay_loop_output_port_override_requires_invalidate_ui_model()
  local calls = 0
  local resolved = gameplay_loop_ports.resolve({
    output = {
      invalidate_ui_model = function(state)
        calls = calls + 1
        state.override_called = true
        return true
      end,
    },
  })
  local state = {}
  local changed = resolved.output.invalidate_ui_model(state)
  lu.assertIs(changed, true, "invalidate_ui_model override should satisfy invalidate_ui_model")
  lu.assertIs(calls, 1, "invalidate_ui_model override should be called once")
  lu.assertIs(state.override_called, true, "invalidate_ui_model override should receive state")
end

function TestUsecaseBoundary:test_sync_input_blocked_does_not_invalidate_ui_model_on_unblock()
  local state = {
    ui = {
      input_blocked = true,
    },
  }
  local invalidations = 0
  local ports = {
    ui_sync = {
      get_ui_state = function()
        return state.ui
      end,
      set_input_blocked = function(_, blocked)
        state.ui.input_blocked = blocked
        return true
      end,
    },
    output = {
      invalidate_ui_model = function()
        invalidations = invalidations + 1
        return true
      end,
    },
  }

  local changed = gameplay_loop_runtime.sync_input_blocked(state, "wait_action", ports)

  lu.assertIs(changed, true, "sync_input_blocked should still report a changed gate state")
  lu.assertIs(state.ui.input_blocked, false, "sync_input_blocked should release input block outside blocked phases")
  lu.assertIs(invalidations, 0, "sync_input_blocked should not invalidate ui_model on unblock")
end

function TestUsecaseBoundary:test_bankruptcy_feedback_port_defaults_to_no_op_port()
  local game = support.new_game({ ai = {} })
  local player = game.players[1]
  local handled = bankruptcy_feedback_port.on_tiles_cleared(game, player, { 1, 2 })
  lu.assertIs(handled, false, "default bankruptcy feedback port should be a no-op false fallback")
end

function TestUsecaseBoundary:test_turn_roll_uses_anim_gate_port_without_ui_port()
  local game = support.new_game({ ai = {} })
  local player = game:current_player()
  game.ui_port = nil
  game.anim_gate_port = {
    wait_action_anim = true,
    wait_move_anim = false,
  }

  local next_state, next_args = turn_roll._phase_roll({ game = game }, {
    player = player,
    rolls = { 3 },
    raw_total = 3,
    total = 3,
  })

  lu.assertIs(next_state, "wait_action_anim", "turn_roll should use anim_gate_port when deciding action anim wait")
  lu.assertIs(next_args.next_state, "roll", "turn_roll should resume into roll after action anim")
  lu.assertIs(game.turn.action_anim.kind, "roll", "turn_roll should still queue roll animation")
end

function TestUsecaseBoundary:test_turn_move_uses_anim_gate_port_without_ui_port()
  local game = support.new_game({ ai = {} })
  local player = game:current_player()
  game.ui_port = nil
  game.last_turn = {}
  game.anim_gate_port = {
    wait_action_anim = false,
    wait_move_anim = true,
  }

  local next_state, next_args = turn_move({ game = game }, {
    player = player,
    raw_total = 1,
    total = 1,
  })

  lu.assertIs(next_state, "wait_move_anim", "turn_move should use anim_gate_port when deciding move anim wait")
  lu.assertIs(next_args.next_state, "move_followup", "turn_move should resume into move_followup after move anim")
  lu.assertIs(game.turn.move_anim.player_id, player.id, "turn_move should still queue move animation")
  lu.assertIs(game.last_turn.move_result, nil, "turn_move should not publish move_result before move anim completes")
end

function TestUsecaseBoundary:test_chance_uses_injected_rng_without_lua_api_rand()
  local game = support.new_game({ ai = {} })
  local player = game:current_player()
  local chance_idx = game.board:find_first_by_type("chance")
  lu.assertNotNil(chance_idx, "missing chance tile")
  local chance_tile = game.board:get_tile(chance_idx)
  lu.assertNotNil(chance_tile, "missing chance tile ref")
  game:update_player_position(player, chance_idx)
  game.anim_gate_port = {
    wait_action_anim = true,
    wait_move_anim = false,
  }
  game.rng = {
    next_int = function(_, min, max)
      lu.assertIs(min, 1, "chance should start rng range at 1")
      lu.assertTrue(max > 0, "chance should use a positive rng upper bound")
      return 1
    end,
  }

  local prev_lua_api = LuaAPI
  local lua_api = prev_lua_api or {}
  support.with_patches({
    { key = "LuaAPI", value = lua_api },
    { target = lua_api, key = "rand", value = function()
      error("chance should not call LuaAPI.rand when game.rng exists")
    end },
  }, function()
    shared_support.resolve_landing(game, player, chance_tile, {})
  end)

  lu.assertIs(game.turn.action_anim and game.turn.action_anim.kind, "chance",
    "chance should queue chance anim through injected rng")
  lu.assertIs(game.turn.action_anim.card_id, 3001,
    "chance should deterministically pick the first card from injected rng")
end


return TestUsecaseBoundary
