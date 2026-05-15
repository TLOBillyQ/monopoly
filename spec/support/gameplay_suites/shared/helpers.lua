---@diagnostic disable
-- luacheck: ignore 211
local support = require("support.gameplay_support")
local _new_game = support.new_game
local _build_ui_port = support.build_ui_port
local _bind_ui_runtime = support.bind_ui_runtime
local _resolve_landing = support.resolve_landing
local _resolve_landing_with_choices = support.resolve_landing_with_choices
local _resolve_choice_first = support.resolve_choice_first
local _get_choice = support.get_choice
local _first_land_tile = support.first_land_tile
local _first_tile_by_type = support.first_tile_by_type
local _tile_state = support.tile_state
local runtime_state = support.runtime_state
local landing_visual_hold = support.landing_visual_hold
local movement = support.movement
local inventory = support.inventory
local steal = support.steal
local choice_resolver = support.choice_resolver
local app = support.app
local map_cfg = support.map_cfg
local tiles_cfg = support.tiles_cfg
local gameplay_loop = support.gameplay_loop
local gameplay_loop_ports = require("src.turn.loop.ports")
local tick_timeout = support.tick_timeout
local constants = support.constants
local bankruptcy = support.bankruptcy
local turn_move = support.turn_move
local turn_dispatch = require("src.turn.actions.action_dispatcher")
local item_ids = require("src.config.gameplay.item_ids")
local timing = require("src.config.gameplay.timing")
local mine_effect = require("src.rules.effects.mine")
local runtime_context = require("src.host.context")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local global_aliases = require("src.host.global_aliases")
local dispatch_validator = require("src.turn.actions.validator")
local tick_ui_sync = require("src.turn.waits.ui_sync")
local tick_choice_timeout = require("src.turn.waits.choice_timeout")
local choice_auto_policy = require("src.turn.policies.choice_auto")
local turn_timer_policy = require("src.turn.policies.timer")
local turn_role_control_policy = require("src.turn.policies.role_control")
local turn_camera_policy = require("src.turn.policies.camera")
local gameplay_loop_runtime = require("src.turn.loop.runtime")
local tick_flow = require("src.turn.loop.tick_flow")
local move_followup = require("src.turn.phases.move_followup")
local intent_dispatcher = require("src.turn.output.intent_dispatcher")
local startup_roster = require("src.app.roster")
local state_factory = require("src.app.state_factory")
local game_startup_event_bridge = require("src.app.event_bridge")
local monopoly_event = require("src.foundation.events")
local number_utils = require("src.foundation.number")
local logger = require("src.foundation.log")
local tip_queue = require("src.foundation.tips")
local market_service = require("src.rules.market")
local phase_registry = require("src.turn.phases.registry")
local turn_decision = require("src.turn.waits.decision")
local item_effects = require("src.rules.items.post_effects")
local item_strategy = require("src.rules.items.strategy")
local facing_policy = require("src.rules.board.facing_policy")
local turn_start = require("src.turn.phases.start")
local turn_script = require("src.turn.timing.session_script")
local roll = require("src.turn.phases.roll")
local item_slot_data = require("src.turn.actions.item_slot_data")
local default_ports = require("src.turn.output.default_ports")
local _t2_cases_module = require("spec.support.gameplay_suites.shared.t2_cases")
local _t2_case_groups = _t2_cases_module.case_groups
local _with_reloaded_move_module = _t2_cases_module.with_reloaded_move_module
local function _build_startup_state(get_current_game, profile_name)
  return state_factory.build_state({
    profile_name = profile_name,
    get_current_game = get_current_game,
    build_game_factory = function(state)
      return startup_roster.build_game_factory(state, {
        profile_name = profile_name,
      })
    end,
    auto_runner = startup_roster.build_auto_runner(),
  })
end

local function _mock_lua_api(send_custom_event)
  return {
    call_delay_time = function() end,
    global_register_custom_event = function() end,
    global_register_trigger_event = function() end,
    unit_register_custom_event = function() end,
    unit_register_trigger_event = function() end,
    global_send_custom_event = send_custom_event or function() end,
  }
end

local function _with_runtime_context_globals(fn)
  support.with_patches({
    { key = "GameAPI", value = nil },
    { key = "LuaAPI", value = nil },
     { key = "SetTimeOut", value = nil },
     { key = "RegisterCustomEvent", value = nil },
     { key = "RegisterTriggerEvent", value = nil },
     { key = "UnitCustomEvent", value = nil },
     { key = "UnitTriggerEvent", value = nil },
     { key = "TriggerCustomEvent", value = nil },
     { key = "camera_helper", value = nil },
     { key = "all_roles", value = nil },
     { key = "ALLROLES", value = nil },
  }, fn)
end

local function _install_global_aliases(ctx)
  runtime_context.install_environment(ctx)
  global_aliases.install(ctx.env)
end

local function _build_test_ports(overrides)
  overrides = overrides or {}
  return {
    modal = {
      close_choice_modal = overrides.close_choice_modal or function() end,
      open_choice_modal = overrides.open_choice_modal or function() end,
      close_popup = overrides.close_popup or function() end,
    },
    anim = {
      play_move_anim = overrides.play_move_anim or function() return 0 end,
      play_action_anim = overrides.play_action_anim or function() return 0 end,
      reset_status_3d = overrides.reset_status_3d or function() end,
      sync_status_3d = overrides.sync_status_3d or function() end,
    },
    ui_sync = {
      apply_input_lock = overrides.apply_input_lock or function() end,
      step_choice_timeout = overrides.step_choice_timeout or function() end,
      step_modal_timeout = overrides.step_modal_timeout or function() end,
      update_countdown = overrides.update_countdown or function() end,
      build_model = overrides.build_model or function() return nil end,
      refresh_from_dirty = overrides.refresh_from_dirty or function() return false end,
      follow_camera = overrides.follow_camera or function() return false end,
      get_ui_state = overrides.get_ui_state or function(state) return state and state.ui or nil end,
      is_input_blocked = overrides.is_input_blocked or function(state)
        local ui = state and state.ui or nil
        return ui and ui.input_blocked == true or false
      end,
      is_popup_active = overrides.is_popup_active or function(state)
        local ui = state and state.ui or nil
        return ui and ui.popup_active == true or false
      end,
      is_choice_active = overrides.is_choice_active or function(state)
        local ui = state and state.ui or nil
        return ui and ui.choice_active == true or false
      end,
      is_market_active = overrides.is_market_active or function(state)
        local ui = state and state.ui or nil
        return ui and ui.market_active == true or false
      end,
      get_popup_owner_index = overrides.get_popup_owner_index or function(state)
        local ui = state and state.ui or nil
        return ui and ui.popup_owner_index or nil
      end,
      resolve_ui_gate = overrides.resolve_ui_gate or function(state)
        local ui = state and state.ui or nil
        local popup = ui and ui.popup_payload or nil
        return {
          input_blocked = ui and ui.input_blocked == true or false,
          choice_active = ui and ui.choice_active == true or false,
          market_active = ui and ui.market_active == true or false,
          popup_active = ui and ui.popup_active == true or false,
          popup_seq = ui and ui.popup_seq or nil,
          popup_auto_close_seconds = popup and popup.auto_close_seconds or nil,
          popup_owner_index = ui and ui.popup_owner_index or nil,
        }
      end,
      set_input_blocked = overrides.set_input_blocked or function(state, blocked)
        local ui = state and state.ui or nil
        if not ui then
          return false
        end
        if ui.input_blocked == blocked then
          return false
        end
        ui.input_blocked = blocked
        return true
      end,
    },
    debug = {
      log_status = overrides.log_status or function() end,
      sync_event_log = overrides.sync_event_log or function() end,
      resolve_event_log_enabled = overrides.resolve_event_log_enabled or function() return false end,
    },
    clock = {
      wall_now_seconds = overrides.wall_now_seconds or function()
        if GameAPI and type(GameAPI.get_timestamp) == "function" then
          return GameAPI.get_timestamp()
        end
        return 0
      end,
      wall_diff_seconds = overrides.wall_diff_seconds or function(timestamp_1, timestamp_2)
        if GameAPI and type(GameAPI.get_timestamp_diff) == "function" then
          return GameAPI.get_timestamp_diff(timestamp_1, timestamp_2)
        end
        return (timestamp_1 or 0) - (timestamp_2 or 0)
      end,
      cpu_now_seconds = overrides.cpu_now_seconds or function()
        return 0
      end,
      cpu_diff_seconds = overrides.cpu_diff_seconds or function(timestamp_1, timestamp_2)
        return (timestamp_1 or 0) - (timestamp_2 or 0)
      end,
    },
    state = {
      apply_role_control_lock = overrides.apply_role_control_lock or function() end,
      install_event_handlers = overrides.install_event_handlers or function() end,
      on_bankruptcy_tiles_cleared = overrides.on_bankruptcy_tiles_cleared or function() end,
    },
  }
end

local function _build_loop_state()
  local auto_runner = require("src.turn.policies.auto_runner")
  local ui_port = _build_ui_port()
  local state = {
    gameplay_loop_ports = _build_test_ports({
      refresh_from_dirty = function() return false end,
      build_model = function() return nil end,
      sync_status_3d = function() end,
      reset_status_3d = function() end,
      update_countdown = function() end,
      log_status = function() end,
      sync_event_log = function() end,
    }),
    ui = ui_port.ui,
    ui_refs = ui_port.ui_refs,
    ui_model = nil,
    set_label = ui_port.set_label,
    set_visible = ui_port.set_visible,
    set_touch_enabled = ui_port.set_touch_enabled,
    query_node = ui_port.query_node,
    auto_runner = auto_runner:new({ interval = 0.01 }),
    pending_choice = nil,
    pending_choice_elapsed = 0,
    pending_choice_id = nil,
    turn_runtime = {
      next_turn_locked = false,
      next_turn_last_click = nil,
      next_turn_lock_phase = nil,
      role_control_lock_active = false,
      role_control_lock_suppress = 0,
    },
    debug_runtime = {
      log_once = {},
    },
  }
  _bind_ui_runtime(state)
  state.auto_runner:set_enabled(true)
  return state
end

local function _with_timestamp_stub(fn)
  local now = 0
  local game_api = GameAPI or {}
  return support.with_patches({
    { key = "GameAPI", value = game_api },
    { target = game_api, key = "get_timestamp", value = function()
      now = now + 1
      return now
    end },
    { target = game_api, key = "get_timestamp_diff", value = function(a, b)
      return a - b
    end },
  }, fn)
end

local function _extra_cases()
  return {
    _test_roll_dice_with_override_uses_provided_values = _t2_case_groups.roll_dice_tests[1],
    _test_roll_dice_with_partial_override_uses_last_for_remaining = _t2_case_groups.roll_dice_tests[2],
    _test_roll_dice_with_rng_only = _t2_case_groups.roll_dice_extended_tests[1],
    _test_roll_dice_zero_count = _t2_case_groups.roll_dice_extended_tests[2],
    _test_roll_dice_truncates_extra_overrides = _t2_case_groups.roll_dice_extended_tests[3],
    _test_roll_dice_exact_override_match = _t2_case_groups.roll_dice_extended_tests[4],
    _test_apply_dice_multiplier_applies_and_resets = _t2_case_groups.apply_dice_multiplier_tests[1],
    _test_apply_dice_multiplier_skips_when_total_changed = _t2_case_groups.apply_dice_multiplier_tests[2],
    _test_apply_dice_multiplier_skips_when_raw_total_nil = _t2_case_groups.apply_dice_multiplier_tests[3],
    _test_move_phase_wait_move_anim_records_anim_data_and_resume_args = function()
      local player = {
        id = 7,
        position = 5,
        status = {},
      }
      local move_result = {
        visited = { 2, 3, 4, 5 },
        steps = { "a", "b" },
        stopped_on_roadblock = true,
        market_interrupt = true,
      }
      local turn_mgr = {
        game = {
          turn = { move_anim_seq = 0 },
          dirty = {},
          players = { player },
          anim_gate_port = { wait_move_anim = true },
        },
      }

      local result, args = _with_reloaded_move_module({
        move = function()
          player.position = 9
          return move_result
        end,
      }, {
        run = function()
          error("wait_move_anim path should not call move_followup.run")
        end,
      }, function(move_module)
        return move_module(turn_mgr, {
          player = player,
          total = 4,
          raw_total = 4,
        })
      end)

      assert(result == "wait_move_anim", "move phase should wait for move animation")
      assert(args.next_state == "move_followup", "wait_move_anim should resume move_followup")
      assert(args.next_args.mode == "resume_turn_move", "resume args should keep resume_turn_move mode")
      assert(args.next_args.player == player, "resume args should preserve player")
      assert(args.next_args.raw_total == 4, "resume args should preserve raw_total")
      assert(args.next_args.move_result == move_result, "resume args should preserve move_result")

      local anim_data = turn_mgr.game.turn.move_anim
      assert(anim_data ~= nil, "move animation data should be queued")
      assert(anim_data.seq == 1, "move animation seq should increment from current sequence")
      assert(anim_data.player_id == 7, "move animation should preserve player id")
      assert(anim_data.from_index == 5, "move animation should preserve start index")
      assert(anim_data.to_index == 9, "move animation should use moved player position")
      assert(anim_data.visited == move_result.visited, "move animation should preserve visited path")
      assert(anim_data.steps == move_result.steps, "move animation should preserve steps")
      assert(anim_data.stopped_on_roadblock == true, "move animation should preserve roadblock flag")
      assert(anim_data.market_interrupt == true, "move animation should preserve market interrupt flag")
      assert(turn_mgr.game.dirty.turn == true and turn_mgr.game.dirty.any == true, "queueing anim should mark game dirty")
    end,
    _test_move_phase_continue_interrupt_passes_direction_and_branch_parity = function()
      local player = {
        id = 8,
        position = 12,
        status = {},
      }
      local captured_total = nil
      local captured_opts = nil
      local captured_followup_args = nil
      local move_result = {
        visited = { 12, 13 },
        steps = { "move" },
      }
      local turn_mgr = {
        game = {
          turn = { move_anim_seq = 0 },
          dirty = {},
          players = { player },
          anim_gate_port = { wait_move_anim = false },
        },
      }

      local result = _with_reloaded_move_module({
        move = function(_, _, total, opts)
          captured_total = total
          captured_opts = opts
          return move_result
        end,
      }, {
        run = function(_, args)
          captured_followup_args = args
          return "followup_ok"
        end,
      }, function(move_module)
        return move_module(turn_mgr, {
          player = player,
          total = 99,
          raw_total = 6,
          continue_from_market = true,
          remaining_steps = 2,
          facing = "left",
          branch_parity = 11,
          entered_inner = true,
        })
      end)

      assert(result == "followup_ok", "continue-from-market path should finish through move_followup")
      assert(captured_total == 2, "move phase should use remaining_steps when resuming from interrupt")
      assert(captured_opts.direction == "left", "move opts should preserve interrupt facing")
      assert(captured_opts.branch_parity == 11, "move opts should preserve branch parity")
      assert(captured_opts.entered_inner == true, "move opts should preserve entered_inner")
      assert(captured_followup_args.mode == "resume_turn_move", "followup should use resume_turn_move mode")
      assert(captured_followup_args.player == player, "followup should preserve player")
      assert(captured_followup_args.raw_total == 11, "followup should pass branch_parity as raw_total")
      assert(captured_followup_args.move_result == move_result, "followup should preserve move_result")
    end,
    _test_resolve_phase_wait_result_with_wait_action_anim = function()
    local player = { id = 1, name = "P1" }
    local phase_res = { next_state = "move", next_args = { player = player, total = 10 }, wait_action_anim = true }
    local state, args = roll._resolve_phase_wait_result(phase_res, player, 10, 5)
    assert(state == "wait_action_anim", "should return wait_action_anim state")
    assert(args.next_state == "move", "should preserve next_state")
    assert(args.next_args.total == 10, "should preserve total in next_args")
  end,
    _test_resolve_phase_wait_result_without_wait_action_anim = function()
    local player = { id = 1, name = "P1" }
    local phase_res = { next_state = "land", next_args = { player = player, total = 8 }, wait_action_anim = false }
    local state, args = roll._resolve_phase_wait_result(phase_res, player, 8, 4)
    assert(state == "wait_choice", "should return wait_choice state when no anim wait")
    assert(args.next_state == "land", "should preserve next_state")
  end,
    _test_resolve_phase_wait_result_defaults = function()
    local player = { id = 1, name = "P1" }
    local phase_res = {}
    local state, args = roll._resolve_phase_wait_result(phase_res, player, 6, 3)
    assert(state == "wait_choice", "should default to wait_choice")
    assert(args.next_state == "move", "should default next_state to move")
    assert(args.next_args.player == player, "should include player in default next_args")
    assert(args.next_args.total == 6, "should include total in default next_args")
    assert(args.next_args.raw_total == 3, "should include raw_total in default next_args")
  end,
    _test_validate_choice_actor_match = function()
    local g = _new_game()
    local p1 = g.players[1]
    local choice = { id = 1, owner_role_id = p1.id }
    local action = { type = "choice_select", actor_role_id = p1.id }
    local result = dispatch_validator.validate_choice_actor(g, action, choice)
    assert(result == true, "should return true when actor matches owner")
  end,
    _test_validate_choice_actor_mismatch = function()
    local g = _new_game()
    local p1 = g.players[1]
    local p2 = g.players[2]
    local choice = { id = 1, owner_role_id = p1.id }
    local action = { type = "choice_select", actor_role_id = p2.id }
    local result = dispatch_validator.validate_choice_actor(g, action, choice)
    assert(result == false, "should return false when actor does not match owner")
  end,
    _test_validate_choice_actor_no_owner = function()
    local g = _new_game()
    local p1 = g.players[1]
    local choice = { id = 1 }
    local action = { type = "choice_select", actor_role_id = p1.id }
    local result = dispatch_validator.validate_choice_actor(g, action, choice)
    assert(result == true, "should return true when choice has no owner")
  end,
    _test_validate_choice_actor_no_actor_id = function()
    local g = _new_game()
    local p1 = g.players[1]
    local choice = { id = 1, owner_role_id = p1.id }
    local action = { type = "choice_select" }
    local result = dispatch_validator.validate_choice_actor(g, action, choice)
    assert(result == false, "should return false when action has no actor_role_id")
  end,
    _test_log_missing_auto_choice_action_logs_once = function()
    local g = _new_game()
    local state = _build_loop_state()
    runtime_state.ensure_debug_runtime(state)
    local ctx = { pending_choice = { id = 123, kind = "test_choice" }, current_player_auto = true }
    gameplay_loop._log_missing_auto_choice_action(state, ctx)
    gameplay_loop._log_missing_auto_choice_action(state, ctx)
    assert(state.debug_runtime.log_once["auto_runner_choice_no_action_123"] == true, "should mark log_once key")
  end,
    _test_log_missing_auto_choice_action_skips_when_waiting = function()
    local g = _new_game()
    local state = _build_loop_state()
    runtime_state.ensure_debug_runtime(state)
    state.auto_runner.waiting_for_interval = true
    local ctx = { pending_choice = { id = 123, kind = "test_choice" }, current_player_auto = true }
    gameplay_loop._log_missing_auto_choice_action(state, ctx)
    assert(state.debug_runtime.log_once["auto_runner_choice_no_action_123"] == nil, "should not log when waiting for interval")
  end,
    _test_log_missing_auto_choice_action_skips_when_not_auto = function()
    local g = _new_game()
    local state = _build_loop_state()
    runtime_state.ensure_debug_runtime(state)
    local ctx = { pending_choice = { id = 123, kind = "test_choice" }, current_player_auto = false }
    gameplay_loop._log_missing_auto_choice_action(state, ctx)
    assert(state.debug_runtime.log_once["auto_runner_choice_no_action_123"] == nil, "should not log when not auto")
  end,
    _test_resolve_choice_owner_id_fallback_current = _t2_case_groups.resolve_choice_owner_id_tests[1],
    _test_resolve_choice_owner_id_out_of_range = _t2_case_groups.resolve_choice_owner_id_tests[2],
    _test_resolve_choice_owner_missing_find_player = _t2_case_groups.resolve_choice_owner_id_tests[3],
    _test_resolve_choice_owner_no_players = _t2_case_groups.resolve_choice_owner_id_tests[4],
    _test_resolve_follow_player_id_skip_nil_id = _t2_case_groups.resolve_follow_player_id_tests[1],
    _test_resolve_follow_player_id_wrap_around = _t2_case_groups.resolve_follow_player_id_tests[2],
    _test_resolve_follow_player_id_all_eliminated = _t2_case_groups.resolve_follow_player_id_tests[3],
    _test_resolve_follow_player_id_nil_turn = _t2_case_groups.resolve_follow_player_id_tests[4],
    _test_resolve_follow_player_id_empty_players = _t2_case_groups.resolve_follow_player_id_tests[5],
    _test_resolve_wait_state_prefers_wait_action_anim = _t2_case_groups.resolve_wait_state_tests[1],
    _test_resolve_wait_state_without_anim_returns_wait_choice = _t2_case_groups.resolve_wait_state_tests[2],
    _test_resolve_wait_state_wraps_move_effect_queue = _t2_case_groups.resolve_wait_state_tests[3],
    _test_fill_ui_sync_defaults_fills_all = _t2_case_groups.fill_ui_sync_defaults_tests[1],
    _test_fill_ui_sync_defaults_preserves_custom = _t2_case_groups.fill_ui_sync_defaults_tests[2],
    _test_fill_ui_sync_defaults_resolve_ui_gate = _t2_case_groups.fill_ui_sync_defaults_tests[3],
    _test_fill_ui_sync_defaults_set_input_blocked = _t2_case_groups.fill_ui_sync_defaults_tests[4],
    _test_fill_ui_sync_defaults_gate_nil_state = _t2_case_groups.fill_ui_sync_defaults_tests[5],
    _test_update_countdown_pending_choice = _t2_case_groups.update_countdown_tests[1],
    _test_update_countdown_detained_wait = _t2_case_groups.update_countdown_tests[2],
    _test_update_countdown_action_button = _t2_case_groups.update_countdown_tests[3],
    _test_update_countdown_popup_zero_timeout = _t2_case_groups.update_countdown_tests[4],
    _test_is_action_button_wait_active_pending_choice = _t2_case_groups.is_action_button_wait_active_tests[1],
    _test_is_action_button_wait_active_input_blocked = _t2_case_groups.is_action_button_wait_active_tests[2],
    _test_is_action_button_wait_active_popup = _t2_case_groups.is_action_button_wait_active_tests[3],
    _test_is_action_button_wait_active_finished_game = _t2_case_groups.is_action_button_wait_active_tests[4],
  }
end

local _helpers = {
  support = support,
  _new_game = _new_game,
  _build_ui_port = _build_ui_port,
  _bind_ui_runtime = _bind_ui_runtime,
  _resolve_landing = _resolve_landing,
  _resolve_landing_with_choices = _resolve_landing_with_choices,
  _resolve_choice_first = _resolve_choice_first,
  _get_choice = _get_choice,
  _first_land_tile = _first_land_tile,
  _first_tile_by_type = _first_tile_by_type,
  _tile_state = _tile_state,
  runtime_state = runtime_state,
  landing_visual_hold = landing_visual_hold,
  movement = movement,
  inventory = inventory,
  steal = steal,
  choice_resolver = choice_resolver,
  app = app,
  map_cfg = map_cfg,
  tiles_cfg = tiles_cfg,
  gameplay_loop = gameplay_loop,
  gameplay_loop_ports = gameplay_loop_ports,
  tick_timeout = tick_timeout,
  constants = constants,
  bankruptcy = bankruptcy,
  turn_move = turn_move,
  turn_dispatch = turn_dispatch,
  item_ids = item_ids,
  timing = timing,
  mine_effect = mine_effect,
  runtime_context = runtime_context,
  runtime_ports = runtime_ports,
  global_aliases = global_aliases,
  dispatch_validator = dispatch_validator,
  tick_ui_sync = tick_ui_sync,
  tick_choice_timeout = tick_choice_timeout,
  choice_auto_policy = choice_auto_policy,
  turn_timer_policy = turn_timer_policy,
  turn_role_control_policy = turn_role_control_policy,
  turn_camera_policy = turn_camera_policy,
  gameplay_loop_runtime = gameplay_loop_runtime,
  tick_flow = tick_flow,
  move_followup = move_followup,
  intent_dispatcher = intent_dispatcher,
  startup_roster = startup_roster,
  state_factory = state_factory,
  game_startup_event_bridge = game_startup_event_bridge,
  monopoly_event = monopoly_event,
  number_utils = number_utils,
  logger = logger,
  tip_queue = tip_queue,
  market_service = market_service,
  phase_registry = phase_registry,
  turn_decision = turn_decision,
  item_effects = item_effects,
  item_strategy = item_strategy,
  facing_policy = facing_policy,
  turn_start = turn_start,
  turn_script = turn_script,
  roll = roll,
  item_slot_data = item_slot_data,
  default_ports = default_ports,
  _t2_cases_module = _t2_cases_module,
  _t2_case_groups = _t2_case_groups,
  _with_reloaded_move_module = _with_reloaded_move_module,
  _build_startup_state = _build_startup_state,
  _mock_lua_api = _mock_lua_api,
  _with_runtime_context_globals = _with_runtime_context_globals,
  _install_global_aliases = _install_global_aliases,
  _build_test_ports = _build_test_ports,
  _build_loop_state = _build_loop_state,
  _with_timestamp_stub = _with_timestamp_stub,
  extra_cases = _extra_cases,
}

return setmetatable(_helpers, { __index = _G })
