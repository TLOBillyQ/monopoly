---@diagnostic disable
-- luacheck: ignore 113 122
local function make_cases(helpers)
  local _ENV = helpers
  local _ = _ENV._new_game
  local event_log = require("src.state.event_log")

local function _test_turn_start_logs_phase_event_to_event_feed()
  local g = _new_game()
  g.players[1].status.stay_turns = 2
  g.players[1].status.deity = { type = "poor", remaining = 3 }
  inventory.give(g.players[1], item_ids.remote_dice)
  local _, tile_ref = _first_land_tile(g.board)
  g:set_tile_owner(tile_ref, g.players[1].id)
  g:set_tile_level(tile_ref, 2)
  g:set_player_property(g.players[1], tile_ref.id, true)
  g:set_player_cash(g.players[1], 4321)
  event_log.clear(g.state.event_log)
  turn_decision.log_turn_start(g)
  local text = event_log.get_text(g.state.event_log)
  assert(string.find(text, "第1回合开始：", 1, true) ~= nil, "turn start should write phase event to event feed")
  assert(string.find(text, g.players[1].name, 1, true) ~= nil, "turn start event should mention current player")
  assert(string.find(text, "金币=", 1, true) == nil, "turn start event should not include player balance")
  assert(string.find(text, "状态:", 1, true) == nil, "turn start event should not include player status details")
  assert(string.find(text, "背包:", 1, true) == nil, "turn start event should not include player items")
  assert(string.find(text, "地产:", 1, true) == nil, "turn start event should not include player properties")
end

local function _test_intent_dispatcher_logs_waiting_choice_event()
  local g = _new_game()
  event_log.clear(g.state.event_log)
  intent_dispatcher.open_choice(g, {
    kind = "remote_dice_value",
    route_key = "remote",
    title = "遥控骰子",
    body_lines = { "选择点数" },
    options = { { id = 1, label = "1" } },
    allow_cancel = true,
    meta = { player_id = g:current_player().id, item_id = 2001 },
  }, {})
  local text = event_log.get_text(g.state.event_log)
  assert(string.find(text, "等待选择：遥控骰子：选择点数", 1, true) ~= nil,
    "open_choice should log waiting-choice phase event")
end

local function _test_intent_dispatcher_dispatches_descriptor_meta_validator_without_required_keys()
  local g = _new_game()
  local validated = false
  g.registries = {
    choices = {
      descriptor_for = function(_, kind)
        if kind ~= "custom_probe" then
          return nil
        end
        return {
          normalize_meta = function(_, meta)
            meta = meta or {}
            meta.normalized = true
            return meta
          end,
          meta_validator = function(_, meta, choice_spec)
            validated = true
            assert(meta.normalized == true, "descriptor meta_validator should receive normalized meta")
            assert(choice_spec.kind == "custom_probe", "descriptor meta_validator should receive choice spec")
          end,
        }
      end,
    },
  }

  local entry = intent_dispatcher.open_choice(g, {
    kind = "custom_probe",
    title = "自定义流程",
    options = { { id = 1, label = "A" } },
    meta = {},
  }, {})

  assert(validated == true, "dispatcher should run descriptor meta_validator even without required_meta")
  assert(entry.meta and entry.meta.normalized == true, "dispatcher should keep normalized meta on custom descriptor choices")
end

local function _test_intent_dispatcher_allows_missing_choice_registry()
  local g = _new_game()
  g.registries = {}

  local entry = intent_dispatcher.open_choice(g, {
    kind = "custom_probe_without_registry",
    title = "无注册表",
    options = { { id = 1, label = "A" } },
    meta = { probe = true },
  }, {})

  assert(entry.kind == "custom_probe_without_registry", "dispatcher should still open choices without registry descriptors")
  assert(entry.meta and entry.meta.probe == true, "dispatcher should preserve original meta when registry is missing")
end

local function _test_choice_cancel_logs_skip_event_but_tax_cancel_does_not()
  local g = _new_game()
  local event_feed = require("src.rules.ports.event_feed")

  event_log.clear(g.state.event_log)
  local normal_choice = {
    id = 10,
    kind = "landing_optional_effect",
    title = "可选效果",
    options = { { id = "buy_land", label = "购买地块" } },
    allow_cancel = true,
    meta = { player_id = g.players[1].id, tile_id = 1, effect_ids = { "buy_land" } },
  }
  choice_resolver.resolve(g, normal_choice, {
    type = "choice_cancel",
    choice_id = normal_choice.id,
    actor_role_id = g.players[1].id,
  }, {
    on_event = function(event)
      event_feed.publish(g, event)
    end,
  })
  local skip_text = event_log.get_text(g.state.event_log)
  assert(string.find(skip_text, "跳过选择：可选效果", 1, true) ~= nil,
    "true cancel should log skip-choice event")

  event_log.clear(g.state.event_log)
  local tax_choice = {
    id = 11,
    kind = "tax_card_prompt",
    title = "是否使用免税卡",
    options = { { id = "use", label = "使用" }, { id = "skip", label = "跳过" } },
    allow_cancel = true,
    meta = { player_id = g.players[1].id },
  }
  choice_resolver.resolve(g, tax_choice, {
    type = "choice_cancel",
    choice_id = tax_choice.id,
    actor_role_id = g.players[1].id,
  }, {
    on_event = function(event)
      event_feed.publish(g, event)
    end,
  })
  local tax_text = event_log.get_text(g.state.event_log)
  assert(string.find(tax_text, "跳过选择", 1, true) == nil,
    "tax cancel fallback should not log skip-choice event")
end

local function _test_choice_resolver_normalizes_market_buy_action_before_execute()
  local g = _new_game()
  local p = g:current_player()
  local choice = {
    id = 901,
    kind = "market_buy",
    route_key = "market",
    owner_role_id = p.id,
    options = { { id = 2001, label = "免费卡" } },
    meta = { player_id = p.id },
  }
  g.turn.pending_choice = choice

  local called_product_id = nil
  local descriptor = g.registries.choices:descriptor_for("market_buy")
  support.with_patches({
    {
      target = descriptor,
      key = "execute",
      value = function(_, _, action)
        called_product_id = action and action.option_id or nil
        return { status = "resolved", stay = false }
      end,
    },
  }, function()
    choice_resolver.resolve(g, choice, {
      type = "choice_select",
      choice_id = choice.id,
      option_id = "2001",
      actor_role_id = p.id,
    })
  end)

  assert(called_product_id == 2001, "market buy should normalize string option_id before execute")
end

local function _test_choice_resolver_normalizes_roadblock_action_before_execute()
  local g = _new_game()
  local p = g:current_player()
  local choice = {
    id = 902,
    kind = "roadblock_target",
    route_key = "target",
    owner_role_id = p.id,
    options = { { id = 3, label = "上海路" } },
    meta = {
      player_id = p.id,
      item_id = item_ids.roadblock,
    },
  }
  g.turn.pending_choice = choice

  local called_target_index = nil
  local descriptor = g.registries.choices:descriptor_for("roadblock_target")
  support.with_patches({
    {
      target = descriptor,
      key = "execute",
      value = function(_, _, action)
        called_target_index = action and action.option_id or nil
        return { status = "resolved", stay = false }
      end,
    },
  }, function()
    choice_resolver.resolve(g, choice, {
      type = "choice_select",
      choice_id = choice.id,
      option_id = "3",
      actor_role_id = p.id,
    })
  end)

  assert(called_target_index == 3, "roadblock target should normalize string option_id before execute")
end

local function _test_end_turn_logs_phase_event_to_event_feed()
  local g = _new_game()
  local phases = phase_registry.build_default_phases()
  event_log.clear(g.state.event_log)
  phases.end_turn({ game = g, next_player = function()
    g.turn.current_player_index = 2
  end }, { player = g.players[1] })
  local text = event_log.get_text(g.state.event_log)
  assert(string.find(text, "回合结束：" .. g.players[1].name, 1, true) ~= nil,
    "end_turn should log phase end event")
  assert(string.find(text, "停在", 1, true) ~= nil, "end_turn event should include landing tile")
end

local function _test_clear_obstacles_zero_does_not_log_event_noise()
  local g = _new_game()
  local player = g.players[1]
  logger.clear()
  item_effects.apply_post(g, player, item_ids.clear_obstacles, { branch_parity = 12 })
  local text = event_log.get_text(g.state.event_log)
  assert(string.find(text, "清除前方障碍数：0", 1, true) == nil,
    "clear obstacles zero result should not enter event feed")
end

local function _test_ai_obstacle_probe_does_not_enter_event_feed()
  local g = _new_game()
  local player = g.players[1]
  player.auto = true
  inventory.give(player, item_ids.clear_obstacles)
  local current = player.position
  local facing = facing_policy.resolve_initial_facing("fresh_forward", player)
  local next_index = select(1, g.board:step_forward_by_facing(current, facing, 12))
  g.board:place_roadblock(next_index)

  logger.clear()
  item_strategy.auto_pre_action(g, player, "pre_action", { is_auto_player = true })
  local text = event_log.get_text(g.state.event_log)
  assert(string.find(text, "前方发现障碍，准备使用清障卡", 1, true) == nil,
    "AI obstacle probe should not enter event feed")
end

local function _test_stop_all_players_movement_preserves_inner_move_dir_and_stop_event()
  local g = _new_game()
  g.players[1].seat_id = 4001
  g.players[2].seat_id = nil
  g:update_player_position(g.players[1], g.board:index_of_tile_id(1))
  g:update_player_position(g.players[2], g.board:index_of_tile_id(28))
  g:set_player_status(g.players[1], "move_dir", "left")
  g:set_player_status(g.players[2], "move_dir", "right")
  local before_seq = g.turn.vehicle_resync_seq or 0
  local stopped_ids = {}
  support.with_patches({
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
  assert(g.players[1].status.move_dir == nil, "outer player move_dir should be cleared")
  assert(g.players[2].status.move_dir == "right", "inner player move_dir should be preserved")
  assert(#stopped_ids == 1, "stop event should only be sent to players with vehicle and valid role")
  assert(stopped_ids[1] == g.players[1].id, "stop event should target player with valid role")
  assert((g.turn.vehicle_resync_seq or 0) == before_seq + 1, "stop should bump vehicle_resync_seq")
end

local function _test_end_turn_stops_all_players_movement()
  local g = _new_game()
  g.players[1].seat_id = 4001
  g.players[2].seat_id = nil
  g:update_player_position(g.players[1], g.board:index_of_tile_id(1))
  g:update_player_position(g.players[2], g.board:index_of_tile_id(28))
  g:set_player_status(g.players[1], "move_dir", "left")
  g:set_player_status(g.players[2], "move_dir", "right")
  local before_seq = g.turn.vehicle_resync_seq or 0
  local stopped_ids = {}
  support.with_patches({
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
  assert(g.players[1].status.move_dir == nil, "outer player move_dir should be cleared at end turn")
  assert(g.players[2].status.move_dir == "right", "inner player move_dir should be preserved at end turn")
  assert(#stopped_ids == 1, "end turn should only stop players with vehicle and valid role")
  assert(stopped_ids[1] == g.players[1].id, "end turn stop should target valid vehicle player")
  assert((g.turn.vehicle_resync_seq or 0) == before_seq + 1, "end turn should bump vehicle_resync_seq")
end

local function _test_location_transfers_clear_move_dir()
  local g = _new_game()
  local p = g:current_player()

  g:set_player_status(p, "move_dir", "left")
  g:player_relocate(p, { tile_type = "hospital", move_dir_mode = "clear" })
  g:player_apply_location_effect(p, "hospital")
  assert(p.status.move_dir == nil, "hospital transfer should clear move_dir")

  g:set_player_status(p, "move_dir", "right")
  g:player_relocate(p, { tile_type = "mountain", move_dir_mode = "clear" })
  g:player_apply_location_effect(p, "mountain")
  assert(p.status.move_dir == nil, "mountain transfer should clear move_dir")
end

local function _test_stop_all_players_movement_skips_invalid_role_without_error()
  local g = _new_game()
  g.players[1].seat_id = 4001
  g.players[2].seat_id = 4002
  g:set_player_status(g.players[1], "move_dir", "left")
  g:set_player_status(g.players[2], "move_dir", "right")
  local stopped_ids = {}
  support.with_patches({
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
    assert(SetTimeOut ~= lua_api.call_delay_time, "install_environment should stay validation-only")

    local installed_helpers = runtime_context.install_runtime_helpers(ctx)
    assert(installed_helpers ~= nil and installed_helpers.camera_helper ~= nil, "install_runtime_helpers should return camera helper")
    assert(camera_helper == nil, "install_runtime_helpers should not export globals by default")
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
    local installed_helpers = runtime_context.install_runtime_helpers(ctx, { install_globals = false })
    assert(installed_helpers ~= nil and installed_helpers.camera_helper ~= nil, "install_runtime_helpers should return helpers")
    assert(all_roles == nil, "install_runtime_helpers install_globals=false should not write all_roles")

    runtime_context.install_runtime_helper_globals(helpers)
    assert(all_roles == helpers.roles, "install_runtime_helper_globals should expose roles")
  end)
end

local function _test_runtime_context_release_helper_install_flow()
  _with_runtime_context_globals(function()
    support.with_patches({
      { key = "MONOPOLY_BUILD_MODE", value = "release" },
    }, function()
      local provider_role = { id = 1, get_roleid = function() return 1 end }
      local fallback_role = { id = 2, get_roleid = function() return 2 end }
      local ctx = runtime_context.new({
        GameAPI = {
          get_role = function(role_id)
            if role_id == 1 then
              return provider_role
            end
            if role_id == 2 then
              return fallback_role
            end
            return nil
          end,
          get_all_valid_roles = function()
            return { fallback_role }
          end,
        },
        LuaAPI = _mock_lua_api(),
      })

      runtime_context.install_environment(ctx)
      ctx.roles = { provider_role }
      local installed_helpers = runtime_context.install_runtime_helpers(ctx)

      assert(type(installed_helpers.vehicle_helper.resolve_any_role) == "function",
        "release install flow should still expose resolve_any_role")
      assert(installed_helpers.vehicle_helper.resolve_any_role() == provider_role,
        "release install flow should keep provider role priority")
      assert(installed_helpers.vehicle_helper.resolve_role(2) == fallback_role,
        "release install flow should keep resolve_role available")
    end)
  end)
end

local function _test_camera_sync_follow_camera_keeps_role_id_event_chain()
  local camera_sync = require("src.ui.ports.ui_sync.camera")
  local follow_calls = 0
  local helper = {
    target_role_id = nil,
    follow = function(role_id)
      follow_calls = follow_calls + 1
      return role_id == 9
    end,
  }

  support.with_patches({
    {
      target = runtime_ports,
      key = "resolve_camera_helper",
      value = function()
        return helper
      end,
    },
  }, function()
    local ok = camera_sync.follow_camera(9)
    assert(ok == true, "camera_sync.follow_camera should call helper.follow")
  end)

  assert(helper.target_role_id == 9, "camera sync should still write target_role_id")
  assert(follow_calls == 1, "camera sync should call helper.follow once")
end

local function _test_game_startup_build_state_is_pure_and_bridge_installs_events()
  local events = {}
  local state = nil
  local current_game = nil
  support.with_patches({
    { key = "LuaAPI", value = _mock_lua_api() },
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
    LuaAPI.global_register_custom_event = function(event_name, handler)
      events[event_name] = handler
    end
    local runtime_ctx = runtime_context.current()
    if runtime_ctx and runtime_ctx.env and runtime_ctx.env.LuaAPI then
      runtime_ctx.env.LuaAPI.global_register_custom_event = LuaAPI.global_register_custom_event
    end
    state = _build_startup_state(function()
      return current_game
    end)
    assert(next(events) == nil, "build_state should not register custom events")

    game_startup_event_bridge.install(state, function()
      return current_game
    end)
    assert(type(events[monopoly_event.land.tile_upgraded]) == "function", "bridge should register tile_upgraded")
    assert(type(events[monopoly_event.intent.need_choice]) == "function", "bridge should register need_choice")

    local opened = nil
    local choice_payload = { id = 11, kind = "item_target_player", route_key = "player", options = { { id = 1, label = "A" } } }
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
      { target = require("src.ui.coord.modal"), key = "open_choice_modal", value = function(_, choice)
        opened = choice
      end },
    }, function()
      events[monopoly_event.intent.need_choice](nil, nil, { choice = choice_payload })
    end)
    assert(runtime_state.get_pending_choice_id(state) == 11, "bridge should sync pending_choice_id from event")
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

  return {
    _test_turn_start_logs_phase_event_to_event_feed = _test_turn_start_logs_phase_event_to_event_feed,
    _test_intent_dispatcher_logs_waiting_choice_event = _test_intent_dispatcher_logs_waiting_choice_event,
    _test_intent_dispatcher_dispatches_descriptor_meta_validator_without_required_keys = _test_intent_dispatcher_dispatches_descriptor_meta_validator_without_required_keys,
    _test_intent_dispatcher_allows_missing_choice_registry = _test_intent_dispatcher_allows_missing_choice_registry,
    _test_choice_cancel_logs_skip_event_but_tax_cancel_does_not = _test_choice_cancel_logs_skip_event_but_tax_cancel_does_not,
    _test_choice_resolver_normalizes_market_buy_action_before_execute = _test_choice_resolver_normalizes_market_buy_action_before_execute,
    _test_choice_resolver_normalizes_roadblock_action_before_execute = _test_choice_resolver_normalizes_roadblock_action_before_execute,
    _test_end_turn_logs_phase_event_to_event_feed = _test_end_turn_logs_phase_event_to_event_feed,
    _test_clear_obstacles_zero_does_not_log_event_noise = _test_clear_obstacles_zero_does_not_log_event_noise,
    _test_ai_obstacle_probe_does_not_enter_event_feed = _test_ai_obstacle_probe_does_not_enter_event_feed,
    _test_stop_all_players_movement_preserves_inner_move_dir_and_stop_event = _test_stop_all_players_movement_preserves_inner_move_dir_and_stop_event,
    _test_end_turn_stops_all_players_movement = _test_end_turn_stops_all_players_movement,
    _test_location_transfers_clear_move_dir = _test_location_transfers_clear_move_dir,
    _test_stop_all_players_movement_skips_invalid_role_without_error = _test_stop_all_players_movement_skips_invalid_role_without_error,
    _test_runtime_context_split_install_stages = _test_runtime_context_split_install_stages,
    _test_runtime_context_install_helpers_without_globals = _test_runtime_context_install_helpers_without_globals,
    _test_runtime_context_release_helper_install_flow = _test_runtime_context_release_helper_install_flow,
    _test_camera_sync_follow_camera_keeps_role_id_event_chain = _test_camera_sync_follow_camera_keeps_role_id_event_chain,
    _test_game_startup_build_state_is_pure_and_bridge_installs_events = _test_game_startup_build_state_is_pure_and_bridge_installs_events,
    _test_runtime_context_install_environment_fails_fast = _test_runtime_context_install_environment_fails_fast,
  }
end

return { make_cases = make_cases }
