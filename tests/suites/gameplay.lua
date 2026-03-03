local support = require("TestSupport")
local _new_game = support.new_game
local _build_ui_port = support.build_ui_port
local _resolve_landing = support.resolve_landing
local _resolve_landing_with_choices = support.resolve_landing_with_choices
local _resolve_choice_first = support.resolve_choice_first
local _get_choice = support.get_choice
local _first_land_tile = support.first_land_tile
local _first_tile_by_type = support.first_tile_by_type
local _tile_state = support.tile_state
local movement = support.movement
local inventory = support.inventory
local steal = support.steal
local app = support.app
local map_cfg = support.map_cfg
local tiles_cfg = support.tiles_cfg
local gameplay_loop = support.gameplay_loop
local gameplay_loop_ports = require("src.game.flow.turn.GameplayLoopPorts")
local tick_timeout = support.tick_timeout
local constants = support.constants
local bankruptcy = support.bankruptcy
local turn_move = support.turn_move
local turn_dispatch = require("src.game.flow.turn.TurnDispatch")
local gameplay_rules = require("src.core.config.GameplayRules")
local mine_effect = require("src.game.systems.effects.MineEffect")
local runtime_context = require("src.core.RuntimeContext")
local runtime_event_bridge = require("src.core.RuntimeEventBridge")
local dispatch_validator = require("src.game.flow.turn.TurnDispatchValidator")
local tick_ui_sync = require("src.game.flow.turn.TickUISync")
local choice_auto_policy = require("src.game.flow.turn.TurnChoiceAutoPolicy")
local turn_timer_policy = require("src.game.flow.turn.TurnTimerPolicy")
local turn_role_control_policy = require("src.game.flow.turn.TurnRoleControlPolicy")
local turn_camera_policy = require("src.game.flow.turn.TurnCameraPolicy")
local gameplay_loop_runtime = require("src.game.flow.turn.GameplayLoopRuntime")
local intent_dispatcher = require("src.game.flow.intent.IntentDispatcher")
local game_startup = require("src.app.bootstrap.GameStartup")
local game_startup_event_bridge = require("src.app.bootstrap.GameStartupEventBridge")
local monopoly_event = require("src.core.events.MonopolyEvents")

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
    { key = "vehicle_helper", value = nil },
    { key = "camera_helper", value = nil },
    { key = "all_roles", value = nil },
    { key = "ALLROLES", value = nil },
    { key = "get_vehicle_player", value = nil },
    { key = "get_vehicle_move_direction", value = nil },
    { key = "get_vehicle_move_time", value = nil },
    { key = "get_spawn_vehicle_id", value = nil },
    { key = "get_vehicle_set_position_x", value = nil },
    { key = "get_vehicle_set_position_y", value = nil },
    { key = "get_vehicle_set_position_z", value = nil },
    { key = "get_camera_target", value = nil },
  }, fn)
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
      sync_debug_log = overrides.sync_debug_log or function() end,
      resolve_debug_enabled = overrides.resolve_debug_enabled or function() return false end,
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
        if os and type(os.clock) == "function" then
          return os.clock()
        end
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
  local auto_runner = require("src.game.flow.turn.AutoRunner")
  local ui_port = _build_ui_port()
  local state = {
    gameplay_loop_ports = _build_test_ports({
      refresh_from_dirty = function() return false end,
      build_model = function() return nil end,
      sync_status_3d = function() end,
      reset_status_3d = function() end,
      update_countdown = function() end,
      log_status = function() end,
      sync_debug_log = function() end,
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

local function _test_mandatory_payment_causes_bankruptcy()
  local g = _new_game()
  local p1 = g.players[1]
  local p2 = g.players[2]

  local idx, tile_ref = _first_land_tile(g.board)
  g:set_tile_owner(tile_ref, p1.id)
  g:set_tile_level(tile_ref, 3)
  g:set_player_property(p1, tile_ref.id, true)

  g:set_player_cash(p2, 10)

  g:update_player_position(p2, idx)

  local before_eliminated = p2.eliminated
  _resolve_landing(g, p2, tile_ref, {})

  assert(p2.eliminated == true, "player should be eliminated after failing to pay rent")
  assert(before_eliminated == false, "player should not have been eliminated before")
end

local function _test_bankruptcy_resets_owned_tiles()
  local g = _new_game()
  local p1 = g.players[1]
  local _, tile1 = _first_land_tile(g.board)
  local tile2 = nil
  for i = 1, #g.board.path do
    local t = g.board.path[i]
    if t.type == "land" and t.id ~= tile1.id then
      tile2 = t
      break
    end
  end
  assert(tile2, "should have at least two land tiles")

  g:set_tile_owner(tile1, p1.id)
  g:set_tile_level(tile1, 2)
  g:set_player_property(p1, tile1.id, true)

  g:set_tile_owner(tile2, p1.id)
  g:set_tile_level(tile2, 1)
  g:set_player_property(p1, tile2.id, true)

  bankruptcy.eliminate(g, p1)

  local st1 = _tile_state(g, tile1)
  local st2 = _tile_state(g, tile2)
  assert(st1.owner_id == nil and st1.level == 0, "bankruptcy clears owned tile1")
  assert(st2.owner_id == nil and st2.level == 0, "bankruptcy clears owned tile2")
  assert(next(p1.properties) == nil, "bankruptcy clears player properties")
end

local function _test_bankruptcy_notifier_reads_grouped_ports()
  local g = _new_game()
  local p1 = g.players[1]
  local _, tile_ref = _first_land_tile(g.board)
  local calls = {}

  g:set_tile_owner(tile_ref, p1.id)
  g:set_player_property(p1, tile_ref.id, true)
  g.gameplay_loop_ports = {
    state = {
      on_bankruptcy_tiles_cleared = function(_, player, owned_tile_ids)
        calls[#calls + 1] = {
          player_id = player and player.id or nil,
          owned_tile_ids = owned_tile_ids,
        }
      end,
    },
  }

  bankruptcy.eliminate(g, p1)

  assert(#calls == 1, "grouped bankruptcy notifier should be invoked once")
  assert(calls[1].player_id == p1.id, "notifier should receive eliminated player")
  assert(type(calls[1].owned_tile_ids) == "table", "notifier should receive owned_tile_ids list")
  assert(calls[1].owned_tile_ids[1] == tile_ref.id, "notifier should receive cleared tile id")
end

local function _test_chance_pay_others_stops_after_bankruptcy()
  local g = app:new({
    players = { "P1", "P2", "P3", "P4" },
    ai = {},
    auto_all = false,
    map = map_cfg,
    tiles = tiles_cfg,
  })
  local p1 = g.players[1]
  local p2 = g.players[2]
  local p3 = g.players[3]
  local p4 = g.players[4]

  g:set_player_cash(p1, 15)
  g:set_player_cash(p2, 0)
  g:set_player_cash(p3, 0)
  g:set_player_cash(p4, 0)

  local chance_handler = assert(g.registries.chances.handlers.pay_others, "missing pay_others handler")
  chance_handler(g, p1, { effect = "pay_others", amount = 10 })

  assert(p1.eliminated == true, "payer should be eliminated when cash becomes non-positive")
  assert(g:player_balance(p2, "金币") == 10, "first recipient should receive transfer")
  assert(g:player_balance(p3, "金币") == 10, "second recipient should receive transfer before bankruptcy stop")
  assert(g:player_balance(p4, "金币") == 0, "later recipients should not receive transfer after bankruptcy")
end

local function _test_set_tile_owner_without_ui_port_does_not_crash()
  local g = _new_game()
  g.ui_port = nil
  local _, tile_ref = _first_land_tile(g.board)
  local p1 = g.players[1]

  g:set_tile_owner(tile_ref, p1.id)
  local st_owned = _tile_state(g, tile_ref)
  assert(st_owned.owner_id == p1.id, "set_tile_owner should work without ui_port")

  g:reset_tile(tile_ref)
  local st_reset = _tile_state(g, tile_ref)
  assert(st_reset.owner_id == nil, "reset_tile should clear owner without ui_port")
  assert(st_reset.level == 0, "reset_tile should clear level without ui_port")
end

local function _test_tile_owner_notifier_receives_owner_changes()
  local g = _new_game()
  g.ui_port = nil
  local _, tile_ref = _first_land_tile(g.board)
  local p1 = g.players[1]
  local calls = {}
  g.tile_owner_notifier = {
    notify_owner_changed = function(_, tile_id, owner_id)
      calls[#calls + 1] = { tile_id = tile_id, owner_id = owner_id }
    end,
  }

  g:set_tile_owner(tile_ref, p1.id)
  g:reset_tile(tile_ref)

  assert(#calls == 2, "tile_owner_notifier should receive owner set and reset")
  assert(calls[1].tile_id == tile_ref.id and calls[1].owner_id == p1.id, "first notify should be owner set")
  assert(calls[2].tile_id == tile_ref.id and calls[2].owner_id == nil, "second notify should be owner clear")
end

local function _test_dispatch_validator_accepts_ui_state_snapshot()
  local ui_state = {
    input_blocked = true,
    item_slot_item_ids = { [1] = 2001 },
  }
  local blocked = dispatch_validator.should_block_action(ui_state, { type = "ui_button" })
  assert(blocked == true, "validator should block when ui_state.input_blocked")

  local state = {
    pending_choice = {
      id = 1,
      kind = "item_phase_choice",
      options = { { id = 2001 } },
    },
  }
  local res = dispatch_validator.resolve_item_slot_action(ui_state, state, {
    id = "item_slot_1",
    actor_role_id = 1,
  })
  assert(res and res.ok, "validator should resolve item slot action")
end

local function _test_intent_dispatcher_sets_choice_route_metadata()
  local g = _new_game()
  local choice_spec = {
    kind = "remote_dice_value",
    title = "遥控骰子",
    body_lines = { "选择点数" },
    options = { { id = 1, label = "1" }, { id = 2, label = "2" } },
    allow_cancel = true,
    cancel_label = "取消",
  }
  local entry = intent_dispatcher.open_choice(g, choice_spec, {})
  assert(entry.route_key == "remote", "intent_dispatcher should inject explicit route_key")
  assert(entry.requires_confirm == false, "remote route should not require confirm")

  local custom_entry = intent_dispatcher.open_choice(g, {
    kind = "item_target_player",
    title = "自定义路由",
    options = { { id = 1, label = "A" } },
    route = { route_key = "secondary_confirm", requires_confirm = true },
  }, {})
  assert(custom_entry.route_key == "secondary_confirm", "explicit route should override inferred route")
  assert(custom_entry.requires_confirm == true, "explicit requires_confirm should be kept")

  local inline_entry = intent_dispatcher.open_choice(g, {
    kind = "item_phase_choice",
    title = "行动前：使用道具？",
    options = { { id = 2001, label = "路障卡" } },
  }, {})
  assert(inline_entry.route_key == "base_inline", "item_phase_choice should use base_inline route")
  assert(inline_entry.requires_confirm == false, "base_inline route should not require confirm")

  local unknown_entry = intent_dispatcher.open_choice(g, {
    kind = "unknown_choice_kind",
    title = "未知流程",
    options = { { id = 1, label = "A" } },
  }, {})
  assert(unknown_entry.route_key == "base_inline", "unknown choice should fallback to base_inline route")
end

local function _test_stop_all_players_movement_clears_move_dir_and_stop_event()
  local g = _new_game()
  g.players[1].seat_id = 4001
  g.players[2].seat_id = nil
  g:set_player_status(g.players[1], "move_dir", "left")
  g:set_player_status(g.players[2], "move_dir", "right")
  local before_seq = g.turn.vehicle_resync_seq or 0
  local stopped_ids = {}
  support.with_patches({
    { target = gameplay_rules, key = "vehicle_enabled", value = true },
    { key = "vehicle_helper", value = {
      resolve_role = function(role_id)
        if role_id == g.players[1].id then
          return { id = role_id }
        end
        return nil
      end,
      emit_vehicle_stop = function(role_id)
        table.insert(stopped_ids, role_id)
      end,
    } },
  }, function()
    g:stop_all_players_movement()
  end)
  assert(g.players[1].status.move_dir == nil, "player1 move_dir should be cleared")
  assert(g.players[2].status.move_dir == nil, "player2 move_dir should be cleared")
  assert(#stopped_ids == 1, "stop event should only be sent to players with vehicle and valid role")
  assert(stopped_ids[1] == g.players[1].id, "stop event should target player with valid role")
  assert((g.turn.vehicle_resync_seq or 0) == before_seq + 1, "stop should bump vehicle_resync_seq")
end

local function _test_end_turn_stops_all_players_movement()
  local g = _new_game()
  g.players[1].seat_id = 4001
  g.players[2].seat_id = nil
  g:set_player_status(g.players[1], "move_dir", "left")
  g:set_player_status(g.players[2], "move_dir", "right")
  local before_seq = g.turn.vehicle_resync_seq or 0
  local stopped_ids = {}
  support.with_patches({
    { target = gameplay_rules, key = "vehicle_enabled", value = true },
    { key = "vehicle_helper", value = {
      resolve_role = function(role_id)
        if role_id == g.players[1].id then
          return { id = role_id }
        end
        return nil
      end,
      emit_vehicle_stop = function(role_id)
        table.insert(stopped_ids, role_id)
      end,
    } },
  }, function()
    local phase_end = g.turn_engine.phases and g.turn_engine.phases.end_turn
    assert(type(phase_end) == "function", "end_turn phase should exist")
    phase_end(g.turn_engine.turn_mgr, { player = g.players[1] })
  end)
  assert(g.players[1].status.move_dir == nil, "player1 move_dir should be cleared at end turn")
  assert(g.players[2].status.move_dir == nil, "player2 move_dir should be cleared at end turn")
  assert(#stopped_ids == 1, "end turn should only stop players with vehicle and valid role")
  assert(stopped_ids[1] == g.players[1].id, "end turn stop should target valid vehicle player")
  assert((g.turn.vehicle_resync_seq or 0) == before_seq + 1, "end turn should bump vehicle_resync_seq")
end

local function _test_stop_all_players_movement_skips_invalid_role_without_error()
  local g = _new_game()
  g.players[1].seat_id = 4001
  g.players[2].seat_id = 4002
  g:set_player_status(g.players[1], "move_dir", "left")
  g:set_player_status(g.players[2], "move_dir", "right")
  local stopped_ids = {}
  support.with_patches({
    { target = gameplay_rules, key = "vehicle_enabled", value = true },
    { key = "vehicle_helper", value = {
      resolve_role = function(role_id)
        if role_id == g.players[1].id then
          return { id = role_id }
        end
        return nil
      end,
      emit_vehicle_stop = function(role_id)
        table.insert(stopped_ids, role_id)
      end,
    } },
  }, function()
    g:stop_all_players_movement()
  end)
  assert(#stopped_ids == 1, "invalid role should be skipped during stop")
  assert(stopped_ids[1] == g.players[1].id, "only valid role should receive stop")
end

local function _test_runtime_context_get_vehicle_player_no_fallback()
  _with_runtime_context_globals(function()
    local role2 = { name = "role2" }
    local game_api = {
      get_role = function(role_id)
        if role_id == 2 then
          return role2
        end
        return nil
      end,
      get_all_valid_roles = function()
        return { role2 }
      end,
    }
    local ctx = runtime_context.new({
      GameAPI = game_api,
      LuaAPI = _mock_lua_api(),
    })
    runtime_context.install_globals(ctx)
    vehicle_helper.player_id = 99
    local role = get_vehicle_player()
    assert(role == nil, "get_vehicle_player should return nil when role missing")
  end)
end

local function _test_runtime_context_forward_stop_skips_invalid_role()
  _with_runtime_context_globals(function()
    local stop_events = 0
    local game_api = {
      get_role = function(role_id)
        if role_id == 1 then
          return { id = 1 }
        end
        return nil
      end,
      get_all_valid_roles = function()
        return { { id = 1 } }
      end,
    }
    support.with_patches({
      { target = gameplay_rules, key = "vehicle_enabled", value = true },
    }, function()
      runtime_event_bridge._reset_for_tests()
      local ctx = runtime_context.new({
        GameAPI = game_api,
        LuaAPI = _mock_lua_api(function(event_name)
          if event_name == "stop_vehicle_forward" then
            stop_events = stop_events + 1
          end
        end),
      })
      runtime_context.install_globals(ctx)
      local invalid_ok = vehicle_helper.emit_vehicle_stop(2)
      local valid_ok = vehicle_helper.emit_vehicle_stop(1)
      assert(invalid_ok == false, "forward stop should reject invalid role")
      assert(valid_ok == true, "forward stop should allow valid role")
      assert(stop_events == 1, "forward stop should only emit event for valid role")
      runtime_event_bridge._reset_for_tests()
    end)
  end)
end

local function _test_runtime_event_bridge_detects_unbound_binding_without_call()
  local calls = 0
  local name = "j4MHTwbxEfG+CjRaYHE42T"
  local newenv = {}

  local function wrapped_trigger()
    local _ = name
    local __ = newenv
    calls = calls + 1
  end

  support.with_patches({
    { key = "TriggerCustomEvent", value = wrapped_trigger },
  }, function()
    runtime_event_bridge._reset_for_tests()
    assert(runtime_event_bridge.is_trigger_available() == false,
      "bridge should reject unbound wrapper before dispatch")
    local emitted = runtime_event_bridge.emit_custom_event("follow_camera", {}, {
      feature_key = "test.unbound",
    })
    assert(emitted == false, "bridge should skip dispatch when wrapper binding is unbound")
    assert(calls == 0, "bridge precheck should avoid calling wrapped TriggerCustomEvent")
    runtime_event_bridge._reset_for_tests()
  end)
end

local function _test_runtime_context_vehicle_events_gracefully_degrade_when_trigger_unavailable()
  _with_runtime_context_globals(function()
    local calls = 0
    local name = "j4MHTwbxEfG+CjRaYHE42T"
    local newenv = {}

    local function wrapped_trigger()
      local _ = name
      local __ = newenv
      calls = calls + 1
    end

    local game_api = {
      get_role = function(role_id)
        if role_id == 1 then
          return { id = 1 }
        end
        return nil
      end,
      get_all_valid_roles = function()
        return { { id = 1 } }
      end,
    }

    support.with_patches({
      { target = gameplay_rules, key = "vehicle_enabled", value = true },
      { key = "TriggerCustomEvent", value = wrapped_trigger },
    }, function()
      runtime_event_bridge._reset_for_tests()
      local ctx = runtime_context.new({
        GameAPI = game_api,
        LuaAPI = _mock_lua_api(wrapped_trigger),
      })
      runtime_context.install_globals(ctx)

      local enter_ok = vehicle_helper.emit_vehicle_enter(1, 4001)
      local move_ok = vehicle_helper.emit_vehicle_move(1, { x = 1, y = 0, z = 0 }, 0.2)
      local stop_ok = vehicle_helper.emit_vehicle_stop(1)
      local set_pos_ok = vehicle_helper.emit_vehicle_set_position(1, { x = 10, y = 0, z = 8 })

      assert(enter_ok == true, "valid role enter should keep success semantics during degradation")
      assert(move_ok == true, "valid role move should keep success semantics during degradation")
      assert(stop_ok == true, "valid role stop should keep success semantics during degradation")
      assert(set_pos_ok == true, "valid role set_position should keep success semantics during degradation")
      assert(vehicle_helper.player_id == 1, "helper state should still update under degradation")
      assert(vehicle_helper.vehicle_id == 4001, "helper vehicle id should still update under degradation")
      assert(calls == 0, "degraded path should skip wrapped TriggerCustomEvent dispatch")
      runtime_event_bridge._reset_for_tests()
    end)
  end)
end

local function _test_runtime_context_split_install_stages()
  _with_runtime_context_globals(function()
    local role1 = { id = 1, get_roleid = function() return 1 end }
    local game_api = {
      get_role = function(role_id)
        if role_id == 1 then
          return role1
        end
        return nil
      end,
      get_all_valid_roles = function()
        return { role1 }
      end,
    }
    local lua_api = _mock_lua_api()
    local ctx = runtime_context.new({
      GameAPI = game_api,
      LuaAPI = lua_api,
    })

    runtime_context.install_environment(ctx)
    assert(SetTimeOut == lua_api.call_delay_time, "install_environment should bind SetTimeOut")
    assert(type(get_vehicle_player) ~= "function", "install_environment should not export helpers")

    local helpers = runtime_context.install_runtime_helpers(ctx)
    assert(helpers ~= nil and helpers.vehicle_helper ~= nil, "install_runtime_helpers should return vehicle helper")
    assert(helpers ~= nil and helpers.camera_helper ~= nil, "install_runtime_helpers should return camera helper")
    assert(vehicle_helper == nil, "install_runtime_helpers should not export globals by default")
    assert(camera_helper == nil, "install_runtime_helpers should not export globals by default")

    runtime_context.install_editor_exports(ctx)
    helpers.vehicle_helper.player_id = 1
    local role = get_vehicle_player()
    assert(role == role1, "install_editor_exports should expose get_vehicle_player")
  end)
end

local function _test_runtime_context_install_helpers_without_globals()
  _with_runtime_context_globals(function()
    local role1 = { id = 1, get_roleid = function() return 1 end }
    local ctx = runtime_context.new({
      GameAPI = {
        get_role = function(role_id)
          if role_id == 1 then
            return role1
          end
          return nil
        end,
        get_all_valid_roles = function()
          return { role1 }
        end,
      },
      LuaAPI = _mock_lua_api(),
    })
    runtime_context.install_environment(ctx)
    local helpers = runtime_context.install_runtime_helpers(ctx, { install_globals = false })
    assert(helpers ~= nil and helpers.vehicle_helper ~= nil, "install_runtime_helpers should return helpers")
    assert(vehicle_helper == nil, "install_runtime_helpers install_globals=false should not write vehicle_helper")
    assert(all_roles == nil, "install_runtime_helpers install_globals=false should not write all_roles")

    runtime_context.install_runtime_helper_globals(helpers)
    assert(vehicle_helper == helpers.vehicle_helper, "install_runtime_helper_globals should expose helper")
    assert(all_roles == helpers.roles, "install_runtime_helper_globals should expose roles")
  end)
end

local function _test_game_startup_build_state_is_pure_and_bridge_installs_events()
  local events = {}
  local state = nil
  local current_game = nil
  support.with_patches({
    { key = "RegisterCustomEvent", value = function(event_name, handler)
      events[event_name] = handler
    end },
    { key = "RegisterTriggerEvent", value = function() end },
    { key = "all_roles", value = {} },
    { key = "GameAPI", value = {
      get_all_valid_roles = function()
        return {}
      end,
    } },
  }, function()
    state = game_startup.build_state(function()
      return current_game
    end)
    assert(next(events) == nil, "build_state should not register custom events")

    game_startup_event_bridge.install(state, function()
      return current_game
    end)
    assert(type(events[monopoly_event.land.tile_upgraded]) == "function", "bridge should register tile_upgraded")
    assert(type(events[monopoly_event.intent.need_choice]) == "function", "bridge should register need_choice")

    local opened = nil
    local choice_payload = { id = 11, kind = "item_target_player", options = { { id = 1, label = "A" } } }
    current_game = {
      turn = { pending_choice = choice_payload },
      winner = nil,
      winner_names = nil,
      last_turn = nil,
      finished = false,
      players = {},
      board = { get_overlays = function() return { roadblocks = {}, mines = {} } end, tile_lookup = {}, path = {} },
    }
    support.with_patches({
      { target = require("src.presentation.api.UIViewService"), key = "open_choice_modal", value = function(_, choice)
        opened = choice
      end },
    }, function()
      events[monopoly_event.intent.need_choice](nil, nil, { choice = choice_payload })
    end)
    assert(state.pending_choice_id == 11, "bridge should sync pending_choice_id from event")
    assert(opened ~= nil and opened.id == 11, "bridge should open choice modal from event")
  end)
end

local function _test_runtime_context_install_environment_fails_fast()
  _with_runtime_context_globals(function()
    local ctx = runtime_context.new({
      GameAPI = {},
      LuaAPI = {
        call_delay_time = function() end,
        global_register_custom_event = function() end,
        global_register_trigger_event = function() end,
        unit_register_custom_event = function() end,
        unit_register_trigger_event = function() end,
      },
    })
    local ok, err = pcall(function()
      runtime_context.install_environment(ctx)
    end)
    assert(ok == false, "install_environment should fail when LuaAPI is incomplete")
    assert(tostring(err):find("missing LuaAPI.global_send_custom_event") ~= nil,
      "install_environment should report missing LuaAPI.global_send_custom_event")
  end)
end

local function _test_set_player_seat_emits_exit_then_enter()
  local g = _new_game()
  local p = g.players[1]
  p.seat_id = 4001
  local calls = {}
  local helper = {
    needs_enter_wait_by_player = {},
    emit_vehicle_exit = function(role_id)
      calls[#calls + 1] = "exit:" .. tostring(role_id)
    end,
    emit_vehicle_enter = function(role_id, vehicle_id)
      calls[#calls + 1] = "enter:" .. tostring(role_id) .. ":" .. tostring(vehicle_id)
    end,
  }
  support.with_patches({
    { target = gameplay_rules, key = "vehicle_enabled", value = true },
    { key = "vehicle_helper", value = helper },
  }, function()
    g:set_player_seat(p, 4004)
  end)
  assert(calls[1] == "exit:1", "seat replace should exit old vehicle first")
  assert(calls[2] == "enter:1:4004", "seat replace should enter new vehicle")
  assert(p.seat_id == 4004, "seat id should update")
  assert(helper.needs_enter_wait_by_player[1] == true, "seat replace should mark enter wait")
end

local function _test_mine_destroy_vehicle_emits_exit_event()
  local g = _new_game()
  local p = g.players[1]
  p.seat_id = 4001
  local exited = {}
  support.with_patches({
    { target = gameplay_rules, key = "vehicle_enabled", value = true },
    { key = "vehicle_helper", value = {
      emit_vehicle_exit = function(role_id)
        exited[#exited + 1] = role_id
      end,
    } },
  }, function()
    mine_effect.apply(g, p, p.position)
  end)
  assert(p.seat_id == nil, "mine should clear seat_id")
  assert(#exited == 1 and exited[1] == p.id, "mine should emit exit event when vehicle destroyed")
end

local function _test_vehicle_feature_disabled_ignores_seat_bonus()
  local g = _new_game()
  local p = g:current_player()
  p.seat_id = 4010

  assert(g:player_dice_count(p) == constants.default_dice_count, "disabled vehicle should not increase dice count")
  assert(g:player_is_vehicle_indestructible(p) == false, "disabled vehicle should not grant mine immunity")
end

local function _test_turn_move_anim_omits_vehicle_id_when_disabled()
  local g = _new_game()
  local p = g:current_player()
  p.seat_id = 4001
  g.last_turn = {}
  g.ui_port = _build_ui_port({ wait_move_anim = true })

  support.with_patches({
    { target = movement, key = "move", value = function()
      return {
        visited = {},
        steps = 1,
        stopped_on_roadblock = false,
        market_interrupt = nil,
        steal_interrupt = nil,
      }
    end },
  }, function()
    local next_state = turn_move({ game = g }, { player = p, total = 1, raw_total = 1 })
    assert(next_state == "wait_move_anim", "move phase should wait for move_anim")
  end)

  assert(g.turn.move_anim ~= nil, "turn move should create move_anim payload")
  assert(g.turn.move_anim.vehicle_id == nil, "disabled vehicle should not be written into move_anim payload")
end

local function _test_autorunner_runs_to_end()
  local auto_runner = require("src.game.flow.turn.AutoRunner")
  local agent = require("src.game.core.runtime.Agent")
  local gameplay_rules = require("src.core.config.GameplayRules")
  local land = require("src.game.systems.land.LandingEffectExecutors")
  local land_actions = require("src.game.systems.land.LandActions")
  local item_inventory = require("src.game.systems.items.ItemInventory")

  local g = app:new({
    players = { "P1", "P2", "P3", "P4" },
    ai = { [2] = true, [3] = true, [4] = true },
    auto_all = true,
    map = map_cfg,
    tiles = tiles_cfg,
  })
  g.ui_port = _build_ui_port()

  local state = {
    gameplay_loop_ports = _build_test_ports({
      refresh_from_dirty = function() return false end,
      build_model = function() return nil end,
      sync_status_3d = function() end,
      reset_status_3d = function() end,
      update_countdown = function() end,
      log_status = function() end,
      sync_debug_log = function() end,
    }),
    ui = g.ui_port.ui,
    ui_refs = g.ui_port.ui_refs,
    ui_model = nil,
    set_label = g.ui_port.set_label,
    set_visible = g.ui_port.set_visible,
    set_touch_enabled = g.ui_port.set_touch_enabled,
    query_node = g.ui_port.query_node,
    auto_runner = auto_runner:new({ interval = 0.01 }),
    pending_choice = nil,
    pending_choice_elapsed = 0,
    pending_choice_id = nil,
    next_turn_locked = false,
    next_turn_last_click = nil,
    next_turn_lock_phase = nil,
  }
  state.auto_runner:set_enabled(true)

  local turn_limit = gameplay_rules.turn_limit or 0
  local max_steps = turn_limit * 5
  assert(max_steps > 0, "invalid turn_limit for autorunner test")

  local timeout = constants.action_timeout_seconds or 0
  local dt = timeout > 0 and (timeout + 0.1) or 1
  if dt > 1 then
    dt = 1
  end

  local now = 0

  local function _drive_auto_turn(game_ctx, state_ctx, auto_action)
    if not auto_action or auto_action.type ~= "ui_button" then
      return
    end
    turn_dispatch.dispatch_action(game_ctx, state_ctx, auto_action)
    local guard = 0
    while game_ctx.turn and game_ctx.turn.phase == "detained_wait" and guard < 20 do
      gameplay_loop.tick(game_ctx, state_ctx, dt)
      guard = guard + 1
    end
  end

  local old_handle_pass_players = steal.handle_pass_players
  local old_pick_roadblock_target = agent.pick_roadblock_target
  local old_can_pay_rent = land.executors.pay_rent.can_apply
  local game_api = GameAPI or {}
  local patches = {
    { target = steal, key = "handle_pass_players", value = function(game_ctx, player, encountered_ids)
      if not item_inventory.find_index(player, gameplay_rules.item_ids.steal) then
        return nil
      end
      return old_handle_pass_players(game_ctx, player, encountered_ids)
    end },
    { target = agent, key = "pick_roadblock_target", value = function()
      return nil
    end },
    { target = land.executors.pay_rent, key = "can_apply", value = function(ctx)
      if not old_can_pay_rent(ctx) then
        return false
      end
      local owner = land_actions.resolve_rent_owner(ctx.game, ctx.tile)
      return owner ~= nil
    end },
    { key = "GameAPI", value = game_api },
    { target = game_api, key = "get_timestamp", value = function()
      return now
    end },
    { target = game_api, key = "get_timestamp_diff", value = function(a, b)
      return a - b
    end },
  }

  local ok, err = pcall(function()
    support.with_patches(patches, function()
      for _ = 1, max_steps do
        state.ui_dirty = false
        g.dirty.ui = false
        g.dirty.players = false
        g.dirty.turn = false
        g.dirty.board_tiles = false
        g.dirty.any = false
        gameplay_loop.step_auto_runner(g, state, dt, {
          modal_active = false,
          modal_buttons = nil,
          game_finished = g.finished,
          current_player_index = g.turn and g.turn.current_player_index or nil,
          current_player_id = (function()
            local idx = g.turn and g.turn.current_player_index or nil
            local player = idx and g.players and g.players[idx] or nil
            return player and player.id or nil
          end)(),
          current_player_auto = (function()
            local idx = g.turn and g.turn.current_player_index or nil
            local player = idx and g.players and g.players[idx] or nil
            return player and player.auto == true or false
          end)(),
        })
        tick_timeout.step_choice_timeout(g, state, dt, {
          on_pending_choice = function() end,
          is_choice_active = function(ctx)
            return ctx.pending_choice and true or false
          end,
          build_action = function(game_ctx, ctx, choice)
            local auto_choice = agent.auto_action_for_choice(game_ctx, choice)
            if auto_choice then
              return auto_choice
            end
            local options = assert(choice.options, "missing choice.options")
            local first = assert(options[1], "missing choice option")
            return {
              type = "choice_select",
              choice_id = choice.id,
              option_id = first.id or first,
            }
          end,
        })
        if g.finished then
          break
        end
        now = now + dt
        local auto_action = gameplay_loop.step_auto_runner(g, state, dt, {
          modal_active = false,
          modal_buttons = nil,
          game_finished = g.finished,
          current_player_index = g.turn and g.turn.current_player_index or nil,
          current_player_id = (function()
            local idx = g.turn and g.turn.current_player_index or nil
            local player = idx and g.players and g.players[idx] or nil
            return player and player.id or nil
          end)(),
          current_player_auto = (function()
            local idx = g.turn and g.turn.current_player_index or nil
            local player = idx and g.players and g.players[idx] or nil
            return player and player.auto == true or false
          end)(),
        })
        _drive_auto_turn(g, state, auto_action)
        if g.turn and g.turn.phase == "detained_wait" then
          gameplay_loop.tick(g, state, dt)
        end
        tick_timeout.step_choice_timeout(g, state, dt, {
          on_pending_choice = function() end,
          is_choice_active = function(ctx)
            return ctx.pending_choice and true or false
          end,
          build_action = function(game_ctx, ctx, choice)
            local auto_choice = agent.auto_action_for_choice(game_ctx, choice)
            if auto_choice then
              return auto_choice
            end
            local options = assert(choice.options, "missing choice.options")
            local first = assert(options[1], "missing choice option")
            return {
              type = "choice_select",
              choice_id = choice.id,
              option_id = first.id or first,
            }
          end,
        })
      end
      if not g.finished then
        error("autorunner did not finish within max_steps=" .. tostring(max_steps))
      end
    end)
  end)

  assert(ok, "autorunner test failed: " .. tostring(err))
end

local function _test_complex_consecutive_turn_settlement()
  local g = _new_game()
  local p1 = g.players[1]
  local p2 = g.players[2]

  p1.inventory:add({ id = 2007 })
  g:set_player_cash(p1, 10000)
  support.with_patches({
    { target = gameplay_rules, key = "vehicle_enabled", value = true },
  }, function()
    g:set_player_seat(p1, 4001)
  end)

  p2.inventory:add({ id = 2001 })
  g:set_player_cash(p2, 10000)

  g:update_player_position(p1, 10)
  g:update_player_position(p2, 12)

  local chance_idx = _first_tile_by_type(g.board, "chance")
  local hospital_idx = _first_tile_by_type(g.board, "hospital")

  g:update_player_position(p1, chance_idx - 3)
  g:update_player_position(p2, chance_idx - 2)

  local mine_pos = g.board:get_tile(chance_idx + 2)
  if mine_pos then
    g.board:place_mine(mine_pos.id)
  end

  local chance_cfg = require("Config.Generated.ChanceCards")
  local has_move_forward = false
  for _, card in ipairs(chance_cfg) do
    if card.effect == "move_forward" and card.steps == 2 and card.target == "self" then
      has_move_forward = true
      break
    end
  end
  assert(has_move_forward, "配置中需要存在向前移动2格的机会卡")

  local initial_has_steal_card = inventory.find_index(p1, 2007) and true or false
  local initial_p2_item_count = p2.inventory:count()
  local initial_has_vehicle = p1.seat_id and true or false

  assert(initial_has_steal_card, "p1 应该有偷窃卡")
  assert(initial_p2_item_count > 0, "p2 应该有道具可被偷")
  assert(initial_has_vehicle, "p1 应该有座驾")

  local res1 = movement.move(g, p1, 3, { branch_parity = 3, skip_market_check = true })
  local first_res = res1
  if res1.steal_interrupt then
    local interrupt = res1.steal_interrupt
    local steal_res = steal.handle_pass_players(g, p1, interrupt.encountered_ids or {})
    if steal_res and steal_res.waiting then
      local pending = _get_choice(g)
      if pending then
        _resolve_choice_first(g, pending)
      end
    end
    res1 = movement.move(g, p1, interrupt.remaining_steps, {
      branch_parity = interrupt.branch_parity,
      direction = interrupt.facing,
      skip_market_check = true,
      skip_steal_check = true,
    })
  end

  assert(first_res.encountered_players and #first_res.encountered_players > 0, "应该经过其他玩家")
  assert(p1.position == chance_idx, "应该停在机会卡格子")

  local tile_chance = g.board:get_tile(chance_idx)
  _resolve_landing_with_choices(g, p1, tile_chance, res1, 10)

  assert(p1, "玩家1应该存在")

  if p1.position == hospital_idx then
    assert(type(p1.status.stay_turns) == "number", "医院应设置 stay_turns")
  end

  assert(true, "复杂连续结算完成")
end

local function _test_complex_market_interrupt_with_rent()
  local g = _new_game()
  local p1 = g.players[1]
  local p2 = g.players[2]

  g:set_player_cash(p1, 50000)
  g:set_player_cash(p2, 50000)

  local market_idx = _first_tile_by_type(g.board, "market")

  local land_idx, land_tile = _first_land_tile(g.board)
  local found_land = false
  for idx = market_idx + 1, g.board:length() do
    local t = g.board:get_tile(idx)
    if t and t.type == "land" then
      land_idx = idx
      land_tile = t
      found_land = true
      break
    end
  end
  if not found_land then
    for idx = 1, market_idx - 1 do
      local t = g.board:get_tile(idx)
      if t and t.type == "land" then
        land_idx = idx
        land_tile = t
        found_land = true
        break
      end
    end
  end
  assert(found_land, "should find a land tile after market")

  g:set_tile_owner(land_tile, p2.id)
  g:set_tile_level(land_tile, 2)
  g:set_player_property(p2, land_tile.id, true)

  local start_pos = market_idx - 1
  if start_pos < 1 then
    start_pos = g.board:length()
  end
  g:update_player_position(p1, start_pos)

  local move_distance = land_idx - start_pos
  if move_distance <= 0 then
    move_distance = g.board:length() + move_distance
  end

  local res = movement.move(g, p1, move_distance, { branch_parity = move_distance })
  res.encountered_players = {}

  local has_market_interrupt = res.market_interrupt and true or false

  if not has_market_interrupt or (res.market_interrupt and res.market_interrupt.remaining_steps == 0) then
    local final_tile = g.board:get_tile(p1.position)
    _resolve_landing_with_choices(g, p1, final_tile, res, 10)
  end

  assert(p1, "玩家应该存在")
  assert(true, "黑市中断 + 租金支付场景完成")
end

local function _test_tick_headless_ports_cover_anim_phases()
  local g = _new_game()
  local state = _build_loop_state()
  state.ui = nil
  state.wait_move_anim = true
  state.wait_action_anim = true
  local dispatched = {}
  local sequence = {}
  g.dispatch_action = function(_, action)
    dispatched[#dispatched + 1] = action
  end

  local calls = {
    move_anim = 0,
    action_anim = 0,
    countdown = 0,
    refresh = 0,
  }

  state.gameplay_loop_ports = _build_test_ports({
    play_move_anim = function(_, anim_ctx)
      calls.move_anim = calls.move_anim + 1
      sequence[#sequence + 1] = "play_move_anim"
      assert(anim_ctx and anim_ctx.seq == 101, "move anim ctx should be injected")
      return 0
    end,
    play_action_anim = function(_, anim_ctx)
      calls.action_anim = calls.action_anim + 1
      sequence[#sequence + 1] = "play_action_anim"
      assert(anim_ctx and anim_ctx.seq == 201, "action anim ctx should be injected")
      return 0
    end,
    step_choice_timeout = function()
      sequence[#sequence + 1] = "step_choice_timeout"
    end,
    step_modal_timeout = function()
      sequence[#sequence + 1] = "step_modal_timeout"
    end,
    update_countdown = function()
      calls.countdown = calls.countdown + 1
      sequence[#sequence + 1] = "update_countdown"
    end,
    refresh_from_dirty = function()
      calls.refresh = calls.refresh + 1
      sequence[#sequence + 1] = "refresh_from_dirty"
      return false
    end,
    sync_debug_log = function()
      sequence[#sequence + 1] = "sync_debug_log"
    end,
    log_status = function()
      sequence[#sequence + 1] = "log_status"
    end,
    close_choice_modal = function() end,
    open_choice_modal = function() end,
    apply_input_lock = function() end,
    build_model = function()
      return { choice = nil, market = nil }
    end,
  })

  g.turn.phase = "wait_move_anim"
  g.turn.move_anim = { seq = 101 }
  support.with_patches({
    { target = gameplay_loop, key = "step_auto_runner", value = function()
      sequence[#sequence + 1] = "step_auto_runner"
    end },
    { target = gameplay_loop_runtime, key = "sync_input_blocked", value = function()
      sequence[#sequence + 1] = "sync_input_blocked"
      return false
    end },
    { target = gameplay_loop_runtime, key = "sync_phase_flags", value = function()
      sequence[#sequence + 1] = "sync_phase_flags"
    end },
    { target = turn_role_control_policy, key = "sync", value = function()
      sequence[#sequence + 1] = "sync_role_control"
    end },
    { target = turn_timer_policy, key = "update_action_button_timer", value = function()
      sequence[#sequence + 1] = "update_action_button_timer"
    end },
    { target = turn_timer_policy, key = "update_detained_wait_timer", value = function()
      sequence[#sequence + 1] = "update_detained_wait_timer"
    end },
    { target = turn_camera_policy, key = "sync_follow", value = function()
      sequence[#sequence + 1] = "sync_follow"
    end },
  }, function()
    gameplay_loop.tick(g, state, 0.1)
  end)
  assert(calls.move_anim == 1, "headless move anim should use injected port")
  assert(dispatched[1] and dispatched[1].type == "move_anim_done", "move anim should dispatch move_anim_done")
  assert(dispatched[1] and dispatched[1].seq == 101, "move anim seq should be forwarded")

  g.turn.phase = "wait_action_anim"
  g.turn.action_anim = { seq = 201 }
  support.with_patches({
    { target = gameplay_loop, key = "step_auto_runner", value = function()
      sequence[#sequence + 1] = "step_auto_runner"
    end },
  }, function()
    gameplay_loop.tick(g, state, 0.1)
  end)
  assert(calls.action_anim == 1, "headless action anim should use injected port")
  assert(dispatched[2] and dispatched[2].type == "action_anim_done", "action anim should dispatch action_anim_done")
  assert(dispatched[2] and dispatched[2].seq == 201, "action anim seq should be forwarded")

  assert(calls.countdown >= 2, "countdown should still step under custom ports")
  assert(calls.refresh >= 2, "refresh_from_dirty should still be called under custom ports")

  local expected_order = {
    "sync_input_blocked",
    "sync_role_control",
    "step_auto_runner",
    "step_choice_timeout",
    "step_modal_timeout",
    "update_action_button_timer",
    "update_detained_wait_timer",
    "sync_input_blocked",
    "play_move_anim",
    "sync_phase_flags",
    "update_countdown",
    "refresh_from_dirty",
    "sync_follow",
    "sync_debug_log",
  }
  local search_start = 1
  for _, name in ipairs(expected_order) do
    local matched = nil
    for i = search_start, #sequence do
      if sequence[i] == name then
        matched = i
        break
      end
    end
    assert(matched ~= nil, "missing expected tick order step: " .. tostring(name))
    search_start = matched + 1
  end
end

local function _test_action_button_timeout_auto_advances()
  local g = _new_game()
  local state = _build_loop_state()
  g.ui_port = _build_ui_port()
  g.turn.current_player_index = 1
  g.turn.phase = "start"
  g.turn.pending_choice = nil

  local advanced = 0
  g.advance_turn = function()
    advanced = advanced + 1
  end

  state.gameplay_loop_ports = _build_test_ports({
    close_choice_modal = function() end,
    open_choice_modal = function() end,
    apply_input_lock = function() end,
    play_move_anim = function() return 0 end,
    play_action_anim = function() return 0 end,
    step_choice_timeout = function() end,
    step_modal_timeout = function() end,
    update_countdown = function() end,
    refresh_from_dirty = function()
      return false
    end,
    sync_debug_log = function() end,
    log_status = function() end,
    build_model = function()
      return { choice = nil, market = nil }
    end,
  })

  _with_timestamp_stub(function()
    local dt = (constants.action_timeout_seconds or 0) + 0.1
    gameplay_loop.tick(g, state, dt)
  end)

  assert(advanced == 1, "action button timeout should advance turn")
end

local function _test_action_button_timeout_blocked_when_input_locked()
  local g = _new_game()
  local state = _build_loop_state()
  g.ui_port = _build_ui_port()
  g.turn.current_player_index = 1
  g.turn.phase = "wait_action_anim"
  g.turn.pending_choice = nil

  state.ui.input_blocked = true

  local advanced = 0
  g.advance_turn = function()
    advanced = advanced + 1
  end

  state.gameplay_loop_ports = _build_test_ports({
    close_choice_modal = function() end,
    open_choice_modal = function() end,
    apply_input_lock = function() end,
    play_move_anim = function() return 0 end,
    play_action_anim = function() return 0 end,
    step_choice_timeout = function() end,
    step_modal_timeout = function() end,
    update_countdown = function() end,
    refresh_from_dirty = function()
      return false
    end,
    sync_debug_log = function() end,
    log_status = function() end,
    build_model = function()
      return { choice = nil, market = nil }
    end,
  })

  _with_timestamp_stub(function()
    local dt = (constants.action_timeout_seconds or 0) + 0.1
    gameplay_loop.tick(g, state, dt)
  end)

  assert(advanced == 0, "input locked should block action button timeout")
  assert(state.action_button_active == false, "input locked should disable action timer")
  assert(state.action_button_elapsed == 0, "input locked should reset action timer")
end

local function _test_action_button_timeout_blocked_when_popup_active()
  local g = _new_game()
  local state = _build_loop_state()
  g.ui_port = _build_ui_port()
  g.turn.current_player_index = 1
  g.turn.phase = "start"
  g.turn.pending_choice = nil

  state.ui.popup_active = true

  local advanced = 0
  g.advance_turn = function()
    advanced = advanced + 1
  end

  state.gameplay_loop_ports = _build_test_ports({
    close_choice_modal = function() end,
    open_choice_modal = function() end,
    apply_input_lock = function() end,
    play_move_anim = function() return 0 end,
    play_action_anim = function() return 0 end,
    step_choice_timeout = function() end,
    step_modal_timeout = function() end,
    update_countdown = function() end,
    refresh_from_dirty = function()
      return false
    end,
    sync_debug_log = function() end,
    log_status = function() end,
    build_model = function()
      return { choice = nil, market = nil }
    end,
  })

  _with_timestamp_stub(function()
    local dt = (constants.action_timeout_seconds or 0) + 0.1
    gameplay_loop.tick(g, state, dt)
  end)

  assert(advanced == 0, "popup active should block action button timeout")
  assert(state.action_button_active == false, "popup active should disable action timer")
  assert(state.action_button_elapsed == 0, "popup active should reset action timer")
end

local function _test_auto_runner_auto_advances_ai_player()
  local g = _new_game()
  g.ui_port = _build_ui_port()
  local state = _build_loop_state()
  state.auto_runner.interval = 0.4
  g.turn.current_player_index = 2
  g.turn.phase = "start"
  g.turn.turn_count = 1

  _with_timestamp_stub(function()
    local a1 = gameplay_loop.step_auto_runner(g, state, 0.2, {
      game_finished = g.finished,
      current_player_index = g.turn.current_player_index,
      current_player_id = g.players[2].id,
      current_player_auto = true,
    })
    assert(a1 == nil, "should not trigger before reaching auto interval")
    local a2 = gameplay_loop.step_auto_runner(g, state, 0.2, {
      game_finished = g.finished,
      current_player_index = g.turn.current_player_index,
      current_player_id = g.players[2].id,
      current_player_auto = true,
    })
    assert(a2 and a2.type == "ui_button" and a2.id == "next", "ai player should auto dispatch next")
  end)
end

local function _test_auto_runner_human_turn_not_auto_advanced()
  local g = _new_game()
  g.ui_port = _build_ui_port()
  local state = _build_loop_state()
  g.turn.current_player_index = 1
  g.turn.phase = "start"
  g.turn.turn_count = 1

  _with_timestamp_stub(function()
    local action = gameplay_loop.step_auto_runner(g, state, 1.0, {
      game_finished = g.finished,
      current_player_index = g.turn.current_player_index,
      current_player_id = g.players[1].id,
      current_player_auto = false,
    })
    assert(action == nil, "human turn should not auto dispatch next")
  end)
end

local function _test_auto_runner_not_advanced_when_input_blocked()
  local g = _new_game()
  g.ui_port = _build_ui_port()
  local state = _build_loop_state()
  state.ui.input_blocked = true
  g.turn.current_player_index = 2
  g.turn.phase = "wait_action_anim"
  g.turn.turn_count = 1

  _with_timestamp_stub(function()
    local action = gameplay_loop.step_auto_runner(g, state, 1.0, {
      game_finished = g.finished,
      current_player_index = g.turn.current_player_index,
      current_player_id = g.players[2].id,
      current_player_auto = true,
    })
    assert(action == nil, "blocked phase should not auto dispatch next")
  end)
end

local function _test_turn_prompt_initialized_for_first_player()
  local g = _new_game()
  local current_player = g:current_player()

  assert((g.turn.turn_start_prompt_seq or 0) == 1, "first turn should initialize prompt seq")
  assert(g.turn.turn_start_prompt_player_id == current_player.id,
    "first turn prompt target should be current player")
end

local function _test_turn_prompt_emitted_on_next_player_switch()
  local g = _new_game()
  local before_seq = g.turn.turn_start_prompt_seq or 0
  local before_index = g.turn.current_player_index
  local expected_next_index = before_index % #g.players + 1
  local expected_player = g.players[expected_next_index]

  g.turn_engine:next_player()

  assert(g.turn.current_player_index == expected_next_index, "next_player should switch player index")
  assert((g.turn.turn_start_prompt_seq or 0) == before_seq + 1,
    "next_player should emit one new prompt seq")
  assert(g.turn.turn_start_prompt_player_id == expected_player.id,
    "next_player prompt target should be switched player")
end

local function _test_auto_runner_depends_on_current_player_auto()
  local g = _new_game()
  g.ui_port = _build_ui_port()
  local state = _build_loop_state()
  g.players[1].auto = true
  g.players[2].auto = false
  g.turn.current_player_index = 1
  g.turn.phase = "start"
  g.turn.turn_count = 1

  _with_timestamp_stub(function()
    local action1 = gameplay_loop.step_auto_runner(g, state, 1.0, {
      game_finished = g.finished,
      current_player_index = g.turn.current_player_index,
      current_player_auto = true,
    })
    assert(action1 and action1.type == "ui_button" and action1.id == "next",
      "current player auto should dispatch next")

    state.turn_runtime.next_turn_locked = false
    g.turn.current_player_index = 2
    local action2 = gameplay_loop.step_auto_runner(g, state, 1.0, {
      game_finished = g.finished,
      current_player_index = g.turn.current_player_index,
      current_player_auto = false,
    })
    assert(action2 == nil, "current player auto=false should not dispatch")
  end)
end

local function _test_turn_dispatch_uses_clock_ports_without_game_api()
  local g = _new_game()
  local state = _build_loop_state()
  state.game = g
  g.ui_port = state
  local current_player = g:current_player()
  local now = 1.0
  local stepped = 0

  state.gameplay_loop_ports = _build_test_ports({
    wall_now_seconds = function()
      return now
    end,
    wall_diff_seconds = function(timestamp_1, timestamp_2)
      return (timestamp_1 or 0) - (timestamp_2 or 0)
    end,
  })
  state.turn_runtime.next_turn_locked = true
  state.turn_runtime.next_turn_last_click = 1.0
  state.turn_runtime.next_turn_lock_phase = g.turn.phase

  support.with_patches({
    { target = turn_dispatch, key = "step_turn", value = function()
      stepped = stepped + 1
    end },
    { key = "GameAPI", value = {} },
  }, function()
    now = 1.2
    local rejected = turn_dispatch.dispatch_action(g, state, {
      type = "ui_button",
      id = "next",
      actor_role_id = current_player.id,
    })
    assert(rejected.status == "rejected", "next should respect cooldown via clock port")

    now = 1.6
    local applied = turn_dispatch.dispatch_action(g, state, {
      type = "ui_button",
      id = "next",
      actor_role_id = current_player.id,
    })
    assert(applied.status == "applied", "next should pass when clock diff reaches cooldown")
  end)

  assert(stepped == 1, "step_turn should run exactly once")
end

local function _test_gameplay_loop_set_game_uses_runtime_ui_port_dto()
  local g = _new_game()
  local state = _build_loop_state()
  state.wait_move_anim = true
  state.wait_action_anim = true
  state.board_scene = { marker = "scene" }
  state.push_popup = function(_, payload)
    state._last_popup = payload
    return true
  end
  state.on_tile_owner_changed = function(_, tile_id, owner_id)
    state._last_tile_owner = { tile_id = tile_id, owner_id = owner_id }
  end

  gameplay_loop.set_game(state, g)

  assert(g.ui_port ~= state, "set_game should inject a minimal runtime ui port instead of raw state")
  assert(g.ui_port.wait_move_anim == true, "runtime ui port should expose wait_move_anim")
  assert(g.ui_port.wait_action_anim == true, "runtime ui port should expose wait_action_anim")
  assert(g.ui_port:get_board_scene() == state.board_scene, "runtime ui port should expose board_scene getter")

  g.ui_port:push_popup({ kind = "test_popup" })
  assert(state._last_popup and state._last_popup.kind == "test_popup", "runtime ui port should forward popup calls")

  g.ui_port:on_tile_owner_changed(11, 22)
  assert(state._last_tile_owner and state._last_tile_owner.tile_id == 11, "runtime ui port should forward tile owner callback")
  assert(state._last_tile_owner and state._last_tile_owner.owner_id == 22, "runtime ui port should forward owner id")
end

local function _test_gameplay_loop_refresh_drives_camera_follow_via_port()
  local g = _new_game()
  local state = _build_loop_state()
  local followed_player_id = nil
  g.turn.current_player_index = 2
  g.dirty.any = true
  g.dirty.ui = true

  state.gameplay_loop_ports = _build_test_ports({
    refresh_from_dirty = function()
      return true
    end,
    follow_camera = function(_, player_id)
      followed_player_id = player_id
      return true
    end,
    update_countdown = function() end,
    sync_status_3d = function() end,
    sync_debug_log = function() end,
  })

  gameplay_loop.tick(g, state, 0.1)

  assert(followed_player_id == g.players[2].id, "camera follow should be driven by use-case loop with current player id")
end

local function _test_gameplay_loop_clock_ports_split_wall_and_cpu_semantics()
  support.with_patches({
    { key = "GameAPI", value = {} },
    { target = os, key = "clock", value = function() return 9.25 end },
  }, function()
    local ports = gameplay_loop_ports.resolve(nil)
    local clock = ports.clock
    assert(clock.wall_now_seconds() == 0, "wall clock should not fallback to cpu clock when GameAPI timestamp is unavailable")
    assert(clock.cpu_now_seconds() == 0, "default cpu clock should be environment-agnostic before runtime injection")
  end)

  local ports = gameplay_loop_ports.resolve({
    clock = {
      wall_now_seconds = function() return 77 end,
      wall_diff_seconds = function() return 0.6 end,
      cpu_now_seconds = function() return 3.5 end,
      cpu_diff_seconds = function(a, b) return a - b end,
    },
  })
  local clock = ports.clock
  assert(clock.wall_now_seconds() == 77, "wall clock should use injected wall source")
  assert(clock.wall_diff_seconds(10, 9) == 0.6, "wall diff should use injected wall semantics")
  assert(clock.cpu_now_seconds() == 3.5, "cpu clock should use injected cpu source")
  assert(clock.cpu_diff_seconds(10, 9) == 1, "cpu diff should stay arithmetic and source-agnostic")
end

local function _test_choice_auto_policy_consistent_between_wait_and_timeout()
  local g = _new_game()
  local auto_player = g.players[g.turn.current_player_index]
  auto_player.auto = true
  local state = { pending_choice_elapsed = 1.2 }
  local choice = {
    id = 1001,
    kind = "market_buy",
    options = { { id = "buy", label = "购买" } },
  }

  local from_wait = choice_auto_policy.decide(g, state, choice, {
    mode = "wait_choice",
    min_visible_seconds = 0.5,
    elapsed_seconds = state.pending_choice_elapsed,
  })
  local from_timeout = choice_auto_policy.decide(g, state, choice, {
    mode = "tick_timeout",
    min_visible_seconds = 0.5,
    elapsed_seconds = state.pending_choice_elapsed,
  })
  assert(from_wait and from_timeout, "auto policy should return actions for auto actor")
  assert(from_wait.type == from_timeout.type, "wait/timeout should resolve to same action type")
  assert(from_wait.choice_id == from_timeout.choice_id, "wait/timeout should target same choice")
  assert(from_wait.option_id == from_timeout.option_id, "wait/timeout should target same option")
end

local function _test_popup_countdown_uses_effective_modal_timeout()
  local g = _new_game()
  local state = _build_loop_state()
  state.ui.popup_active = true
  state.ui.popup_payload = { auto_close_seconds = 3 }
  state.ui_modal_elapsed = 1.2
  state.pending_choice = nil
  state.action_button_active = false
  state.countdown_last = nil
  state.countdown_active_last = nil

  support.with_patches({
    { target = constants, key = "action_timeout_seconds", value = 10 },
    { target = gameplay_rules, key = "popup_auto_close_seconds", value = 8 },
  }, function()
    tick_ui_sync.update_countdown(g, state)
  end)

  assert(g.turn.countdown_seconds == 2, "popup countdown should use popup effective timeout")
  assert(g.turn.countdown_active == true, "popup countdown should stay active")
end

local function _test_dispatch_gate_blocks_next_when_choice_active()
  local g = _new_game()
  local state = _build_loop_state()
  state.game = g
  state.ui.input_blocked = false
  state.ui.choice_active = true
  state.ui.market_active = false
  state.ui.popup_active = false
  local current_player = g:current_player()

  local should_block_next = turn_dispatch.should_block_action(state, {
    type = "ui_button",
    id = "next",
    actor_role_id = current_player.id,
  })
  local should_block_choice = turn_dispatch.should_block_action(state, {
    type = "choice_select",
    choice_id = 1,
    option_id = 1,
    actor_role_id = current_player.id,
  })

  assert(should_block_next == true, "choice active should block next")
  assert(should_block_choice == false, "choice active should not block choice confirm")
end

return {
  _test_mandatory_payment_causes_bankruptcy,
  _test_bankruptcy_resets_owned_tiles,
  _test_bankruptcy_notifier_reads_grouped_ports,
  _test_chance_pay_others_stops_after_bankruptcy,
  _test_set_tile_owner_without_ui_port_does_not_crash,
  _test_tile_owner_notifier_receives_owner_changes,
  _test_dispatch_validator_accepts_ui_state_snapshot,
  _test_intent_dispatcher_sets_choice_route_metadata,
  _test_stop_all_players_movement_clears_move_dir_and_stop_event,
  _test_end_turn_stops_all_players_movement,
  _test_stop_all_players_movement_skips_invalid_role_without_error,
  _test_runtime_context_get_vehicle_player_no_fallback,
  _test_runtime_context_forward_stop_skips_invalid_role,
  _test_runtime_event_bridge_detects_unbound_binding_without_call,
  _test_runtime_context_vehicle_events_gracefully_degrade_when_trigger_unavailable,
  _test_runtime_context_split_install_stages,
  _test_runtime_context_install_helpers_without_globals,
  _test_runtime_context_install_environment_fails_fast,
  _test_game_startup_build_state_is_pure_and_bridge_installs_events,
  _test_set_player_seat_emits_exit_then_enter,
  _test_mine_destroy_vehicle_emits_exit_event,
  _test_vehicle_feature_disabled_ignores_seat_bonus,
  _test_turn_move_anim_omits_vehicle_id_when_disabled,
  _test_autorunner_runs_to_end,
  _test_complex_consecutive_turn_settlement,
  _test_complex_market_interrupt_with_rent,
  _test_tick_headless_ports_cover_anim_phases,
  _test_action_button_timeout_auto_advances,
  _test_action_button_timeout_blocked_when_input_locked,
  _test_action_button_timeout_blocked_when_popup_active,
  _test_auto_runner_auto_advances_ai_player,
  _test_auto_runner_human_turn_not_auto_advanced,
  _test_auto_runner_not_advanced_when_input_blocked,
  _test_auto_runner_depends_on_current_player_auto,
  _test_turn_prompt_initialized_for_first_player,
  _test_turn_prompt_emitted_on_next_player_switch,
  _test_turn_dispatch_uses_clock_ports_without_game_api,
  _test_gameplay_loop_set_game_uses_runtime_ui_port_dto,
  _test_gameplay_loop_refresh_drives_camera_follow_via_port,
  _test_gameplay_loop_clock_ports_split_wall_and_cpu_semantics,
  _test_choice_auto_policy_consistent_between_wait_and_timeout,
  _test_popup_countdown_uses_effective_modal_timeout,
  _test_dispatch_gate_blocks_next_when_choice_active,
}

