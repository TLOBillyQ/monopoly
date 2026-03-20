local support = require("support.runtime_support")
local _assert_eq = support.assert_eq
local _with_patches = support.with_patches

local bankruptcy_feedback_port = require("src.rules.ports.bankruptcy_feedback_port")
local turn_action_port = require("src.ui.input.dispatch_turn_action_port")
local gameplay_loop_ports = require("src.turn.loop.ports")
local runtime_ports = require("src.core.ports.runtime_ports")
local turn_roll = require("src.turn.phases.roll")
local turn_move = require("src.turn.phases.move")

local function _test_turn_action_port_resolve_defaults()
  local resolved = turn_action_port.resolve({}, nil)
  local res = resolved.dispatch_action({}, {}, { type = "noop" }, {})
  _assert_eq(res.status, "rejected", "default dispatch_action should reject")
  _assert_eq(resolved.should_block_action({}, { type = "noop" }), false, "default should_block_action should be false")
end

local function _test_turn_action_port_override_precedence()
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
  _assert_eq(res.status, "override", "override port should take precedence over state port")
  _assert_eq(calls, 1, "dispatch should call override implementation once")
  _assert_eq(resolved.should_block_action({}, { type = "noop" }), true, "override should_block_action should take precedence")
end

local function _test_turn_action_port_normalize_auto_intent_contract()
  local state = {}
  local intent = { type = "ui_button", id = "auto", actor_role_id = 7 }
  _with_patches({
    { target = turn_action_port, key = "normalize_auto_intent", value = turn_action_port.normalize_auto_intent },
    { key = "UIManager", value = { client_role = nil } },
  }, function()
    local out = turn_action_port.normalize_auto_intent(state, intent)
    _assert_eq(out.type, "ui_button", "normalize should preserve type")
    _assert_eq(out.id, "auto", "normalize should preserve button id")
    _assert_eq(out.actor_role_id, 7, "normalize should preserve actor role fallback")
  end)
end

local function _test_turn_action_port_normalize_auto_intent_rejects_missing_actor()
  local state = {}
  local intent = { type = "ui_button", id = "auto" }
  _with_patches({
    { key = "UIManager", value = { client_role = nil } },
  }, function()
    local out = turn_action_port.normalize_auto_intent(state, intent)
    _assert_eq(out, nil, "normalize should reject auto intent without actor context")
  end)
end

local function _test_gameplay_loop_clock_contract_split_sources()
  runtime_ports.reset_for_tests()
  local default_ports = gameplay_loop_ports.resolve(nil)
  local default_clock = default_ports.clock
  _assert_eq(default_clock.wall_now_seconds(), 0, "default wall clock should be environment-agnostic zero fallback")
  _assert_eq(default_clock.wall_diff_seconds(9, 7), 2, "default wall diff should stay arithmetic fallback")
  _assert_eq(default_clock.cpu_now_seconds(), 0, "default cpu clock should be environment-agnostic zero fallback")
  _assert_eq(default_clock.cpu_diff_seconds(9, 7), 2, "default cpu diff should remain arithmetic")

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
  _assert_eq(clock.wall_now_seconds(), 42, "injected wall clock should be used when provided")
  _assert_eq(clock.wall_diff_seconds(9, 7), 20, "injected wall diff should preserve injected semantics")
  _assert_eq(clock.cpu_now_seconds(), 1.5, "injected cpu clock should be used when provided")
  _assert_eq(clock.cpu_diff_seconds(9, 7), 2, "injected cpu diff should remain arithmetic")
  runtime_ports.reset_for_tests()
end

local function _test_choice_contract_copies_explicit_fields_once()
  local choice_contract = require("src.core.choice.contract")
  local source = {
    route_key = "target",
    requires_confirm = true,
    owner_role_id = 8,
    confirm_title = "请确认",
    confirm_body = "你选的是：A",
    uses_item_slots = false,
    pre_confirm_before_slot_pick = false,
    uses_target_picker = true,
    target_picker_owner_role_id = 9,
    active_tab = "skin",
    page_index = 2,
    page_count = 3,
    phase = "pre_action",
    queue = { 2, 3 },
    effect_ids = { "buy_land" },
    move_result = { next_state = "wait_choice" },
  }
  local target = {}
  choice_contract.copy_explicit_fields(source, target)
  _assert_eq(target.route_key, "target", "contract should copy route_key")
  _assert_eq(target.owner_role_id, 8, "contract should copy owner_role_id")
  _assert_eq(target.target_picker_owner_role_id, 9, "contract should copy target picker owner")
  _assert_eq(target.page_count, 3, "contract should copy market paging fields")
  _assert_eq(target.phase, nil, "contract should keep phase in meta")
  _assert_eq(target.queue, nil, "contract should keep queue in meta")
  _assert_eq(target.effect_ids, nil, "contract should keep effect_ids in meta")
  _assert_eq(target.move_result, nil, "contract should keep move_result in meta")
end

local function _test_output_state_adapter_runtime_variant_stays_off_legacy_state()
  local output_state_adapter = require("src.turn.output.output_state_adapter")
  local output = output_state_adapter.build_runtime_output_ports()
  local state = {}
  local changed = output.invalidate_ui(state)
  _assert_eq(changed, true, "runtime output.invalidate_ui should still mark ui runtime dirty")
  _assert_eq(state.ui_dirty, nil, "runtime output.invalidate_ui should not write legacy ui_dirty bridge")
  _assert_eq(state.ui_runtime and state.ui_runtime.ui_dirty, true, "runtime output should write ui_runtime only")
end

local function _test_gameplay_loop_output_port_defaults_to_ui_runtime_only()
  local resolved = gameplay_loop_ports.resolve(nil)
  local state = {}
  local changed = resolved.output.invalidate_ui(state)
  _assert_eq(changed, true, "default output.invalidate_ui should mark ui_runtime dirty")
  _assert_eq(state.ui_dirty, nil, "default output.invalidate_ui should not mark legacy state.ui_dirty")
  _assert_eq(state.ui_runtime and state.ui_runtime.ui_dirty, true, "default output.invalidate_ui should write ui_runtime")
  local changed_again = resolved.output.invalidate_ui(state)
  _assert_eq(changed_again, false, "default output.invalidate_ui should be idempotent when ui_runtime already dirty")
end

local function _test_output_state_adapter_exposes_invalidate_ui_model_alias()
  local output_state_adapter = require("src.turn.output.output_state_adapter")
  local output = output_state_adapter.build_runtime_output_ports()
  local state = {}
  local changed = output.invalidate_ui_model(state)
  _assert_eq(changed, true, "runtime output.invalidate_ui_model should mark ui_runtime dirty")
  _assert_eq(state.ui_runtime and state.ui_runtime.ui_dirty, true, "invalidate_ui_model alias should share ui_runtime behavior")
end

local function _test_gameplay_loop_output_port_override_precedence()
  local calls = 0
  local resolved = gameplay_loop_ports.resolve({
    output = {
      invalidate_ui = function(state)
        calls = calls + 1
        state.override_called = true
        return true
      end,
    },
  })
  local state = {}
  local changed = resolved.output.invalidate_ui(state)
  _assert_eq(changed, true, "override output.invalidate_ui should return override result")
  _assert_eq(calls, 1, "override output.invalidate_ui should be called once")
  _assert_eq(state.override_called, true, "override output.invalidate_ui should receive state")
  _assert_eq(state.ui_dirty, nil, "override output.invalidate_ui should bypass default ui_dirty bridge")
end

local function _test_bankruptcy_feedback_port_defaults_to_no_op_port()
  local game = support.new_game({ ai = {} })
  local player = game.players[1]
  local handled = bankruptcy_feedback_port.on_tiles_cleared(game, player, { 1, 2 })
  _assert_eq(handled, false, "default bankruptcy feedback port should be a no-op false fallback")
end

local function _test_turn_roll_uses_anim_gate_port_without_ui_port()
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

  _assert_eq(next_state, "wait_action_anim", "turn_roll should use anim_gate_port when deciding action anim wait")
  _assert_eq(next_args.next_state, "roll", "turn_roll should resume into roll after action anim")
  _assert_eq(game.turn.action_anim.kind, "roll", "turn_roll should still queue roll animation")
end

local function _test_turn_move_uses_anim_gate_port_without_ui_port()
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

  _assert_eq(next_state, "wait_move_anim", "turn_move should use anim_gate_port when deciding move anim wait")
  _assert_eq(next_args.next_state, "move_followup", "turn_move should resume into move_followup after move anim")
  _assert_eq(game.turn.move_anim.player_id, player.id, "turn_move should still queue move animation")
  _assert_eq(game.last_turn.move_result, nil, "turn_move should not publish move_result before move anim completes")
end

return {
  name = "usecase_boundary_contract",
  tests = {
    { name = "turn_action_port_resolve_defaults", run = _test_turn_action_port_resolve_defaults },
    { name = "turn_action_port_override_precedence", run = _test_turn_action_port_override_precedence },
    { name = "turn_action_port_normalize_auto_intent_contract", run = _test_turn_action_port_normalize_auto_intent_contract },
    { name = "turn_action_port_normalize_auto_intent_rejects_missing_actor", run = _test_turn_action_port_normalize_auto_intent_rejects_missing_actor },
    { name = "gameplay_loop_clock_contract_split_sources", run = _test_gameplay_loop_clock_contract_split_sources },
    { name = "choice_contract_copies_explicit_fields_once", run = _test_choice_contract_copies_explicit_fields_once },
    { name = "gameplay_loop_output_port_defaults_to_ui_runtime_only", run = _test_gameplay_loop_output_port_defaults_to_ui_runtime_only },
    { name = "output_state_adapter_exposes_invalidate_ui_model_alias", run = _test_output_state_adapter_exposes_invalidate_ui_model_alias },
    { name = "gameplay_loop_output_port_override_precedence", run = _test_gameplay_loop_output_port_override_precedence },
    { name = "bankruptcy_feedback_port_defaults_to_no_op_port", run = _test_bankruptcy_feedback_port_defaults_to_no_op_port },
    { name = "turn_roll_uses_anim_gate_port_without_ui_port", run = _test_turn_roll_uses_anim_gate_port_without_ui_port },
    { name = "turn_move_uses_anim_gate_port_without_ui_port", run = _test_turn_move_uses_anim_gate_port_without_ui_port },
  },
}
