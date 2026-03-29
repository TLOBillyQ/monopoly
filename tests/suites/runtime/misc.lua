local support = require("support.runtime_support")
local _assert_eq = support.assert_eq
local with_patches = support.with_patches
local number_utils = support.number_utils
local runtime_constants = require("src.config.gameplay.runtime_constants")
local runtime_context = require("src.host.context")
local default_ports = require("src.host.default_ports")
local wait_callbacks = require("src.turn.waits.callback_registry")

local logger_tests = require("suites.runtime.misc_logger")
local tip_queue_tests = require("suites.runtime.misc_tip_queue")
local lvh_tests = require("suites.runtime.misc_landing_visual_hold")
local gateway_tests = require("suites.runtime.misc_eggy_paid_gateway")

local function _test_number_utils_to_integer()
  _assert_eq(number_utils.to_integer("12"), 12, "string integer should parse")
  _assert_eq(number_utils.to_integer("-7"), -7, "negative string integer should parse")
  _assert_eq(number_utils.to_integer("12.3"), nil, "float string should be rejected")
end

local function _test_number_utils_to_integer_fallback_from_tostring()
  local wrapped = setmetatable({}, {
    __tostring = function()
      return "5"
    end,
  })
  _assert_eq(number_utils.to_integer(wrapped), 5, "non-numeric value should parse from tostring fallback")
end

local function _test_number_utils_to_integer_fallback_rejects_non_integer_text()
  local wrapped = setmetatable({}, {
    __tostring = function()
      return "abc"
    end,
  })
  _assert_eq(number_utils.to_integer(wrapped), nil, "non-integer tostring fallback should be rejected")
end

local function _test_synthetic_actor_registry_spawns_from_first_path_tile()
  local registry_module = require("src.host.synthetic_actor_registry")
  local runtime_constants = require("src.config.gameplay.runtime_constants")
  local created = {}
  local registry = registry_module.new({
    LuaAPI = {
      query_unit = function(name)
        return {
          get_position = function()
            created.query_name = name
            return { x = 1, y = 2, z = 3 }
          end,
        }
      end,
    },
    GameAPI = {
      create_creature_fixed_scale = function(unit_key, pos, rot)
        created[#created + 1] = { unit_key = unit_key, pos = pos, rot = rot }
        return {
          start_ai = function() end,
        }
      end,
    },
  })

  registry.register_specs({
    { player_id = -2, unit_key = "npc_2", avatar_image_key = 1002 },
  })
  registry.spawn_pending({
    path = { 7, 8, 9 },
  })

  _assert_eq(created.query_name, "t7", "registry should use the first path tile as spawn anchor")
  _assert_eq(created[1].unit_key, "npc_2", "registry should spawn configured synthetic unit key")
  _assert_eq(created[1].pos.x, 1, "registry should pass queried spawn position to GameAPI")
  _assert_eq(created[1].rot, runtime_constants.q_left, "registry should spawn synthetic actors facing left")
end

local function _test_synthetic_actor_registry_reset_destroys_spawned_actor_and_clears_registry()
  local registry_module = require("src.host.synthetic_actor_registry")
  local destroyed = {}
  local spawned_unit = {
    id = "synthetic_unit",
    start_ai = function() end,
  }
  local registry = registry_module.new({
    LuaAPI = {
      query_unit = function()
        return {
          get_position = function()
            return { x = 0, y = 0, z = 0 }
          end,
        }
      end,
    },
    GameAPI = {
      create_creature_fixed_scale = function()
        return spawned_unit
      end,
      destroy_unit = function(unit)
        destroyed[#destroyed + 1] = unit
      end,
    },
  })

  registry.register_specs({
    { player_id = -3, unit_key = "npc_3", avatar_image_key = 1003 },
  })
  registry.spawn_pending({
    path = { 1 },
  })
  assert(registry.resolve_actor(-3) ~= nil, "spawned synthetic actor should be resolvable before reset")

  registry.reset()

  _assert_eq(#destroyed, 1, "registry reset should destroy spawned synthetic actor")
  _assert_eq(destroyed[1], spawned_unit, "registry reset should destroy the created unit")
  _assert_eq(registry.resolve_actor(-3), nil, "registry reset should clear actor lookup")
end

local function _test_ui_bootstrap_required_click_nodes_appends_extras()
  local ui_bootstrap = require("src.app.ui_bootstrap")
  local ui_manager_nodes = {
    { "基础屏_行动按钮" },
  }
  local missing = nil

  with_patches({
    {
      target = _G,
      key = "RegisterTriggerEvent",
      value = function(_, cb)
        cb()
      end,
    },
    {
      target = _G,
      key = "EVENT",
      value = {
        GAME_INIT = "GAME_INIT",
      },
    },
    {
      target = package.loaded,
      key = "vendor.third_party.UIManager.Utils",
      value = true,
    },
    {
      target = package.loaded,
      key = "Data.UIManagerNodes",
      value = ui_manager_nodes,
    },
    {
      target = _G,
      key = "UIManager",
      value = {
        Builder = {
          new = function()
            return {}
          end,
        },
      },
    },
    {
      target = require("src.ui.ctl.ui_events"),
      key = "send_to_all",
      value = function() end,
    },
    {
      target = require("src.ui.ctl.canvas_event_router"),
      key = "bind",
      value = function() end,
    },
    {
      target = require("src.ui.ctl.ui_runtime"),
      key = "init_ui_assets",
      value = function() end,
    },
    {
      target = require("src.ui.ctl.ui_runtime"),
      key = "capture_player_colors",
      value = function() end,
    },
    {
      target = require("src.ui.render.board_scene"),
      key = "init",
      value = function() end,
    },
    {
      target = require("src.host.context"),
      key = "current",
      value = function()
        return nil
      end,
    },
    {
      target = require("src.core.ports.runtime_ports"),
      key = "resolve_roles",
      value = function()
        return {}
      end,
    },
    {
      target = require("src.core.ports.runtime_ports"),
      key = "schedule",
      value = function(_, fn)
        fn()
      end,
    },
    {
      target = require("src.state.state_access.ui_role_globals"),
      key = "install",
      value = function()
        return {}
      end,
    },
  }, function()
    local ok, err = pcall(function()
      ui_bootstrap.install({}, {
        {
          board = { map = {} },
        },
      }, {
        start_runtime = function()
          return {
            board = { map = {} },
          }
        end,
      })
    end)
    missing = err
    assert(ok == false, "ui bootstrap should validate missing UI nodes")
  end)

  assert(tostring(missing):find("UI 节点缺失", 1, true) ~= nil, "ui bootstrap should report missing required nodes")
end

local function _test_default_ports_wall_diff_seconds_prefers_game_api_then_falls_back()
  local ctx = {
    env = {
      GameAPI = {
        get_timestamp_diff = function(current, previous)
          return (current - previous) * 2
        end,
      },
    },
  }
  local runtime_ctx = {
    current = function()
      return ctx
    end,
  }
  local ports = default_ports.build(runtime_ctx)

  _assert_eq(ports.wall_diff_seconds(9, 7), 4, "wall diff should prefer GameAPI semantics when available")
  ctx.env.GameAPI.get_timestamp_diff = nil
  _assert_eq(ports.wall_diff_seconds(9, 7), 2, "wall diff should fall back to arithmetic when GameAPI diff is unavailable")
  _assert_eq(ports.wall_diff_seconds("x", 7), 0, "wall diff should return 0 for non-numeric fallback inputs")
end

local function _test_ui_bootstrap_spawns_startup_synthetic_actors()
  local ui_bootstrap = require("src.app.ui_bootstrap")
  local capture = {
    registered_specs = nil,
    spawned_map = nil,
  }

  with_patches({
    {
      target = require("src.host.context"),
      key = "current",
      value = function()
        return {
          synthetic_actor_registry = {
            register_specs = function(specs)
              capture.registered_specs = specs
            end,
            spawn_pending = function(map_cfg)
              capture.spawned_map = map_cfg
            end,
          },
        }
      end,
    },
  }, function()
    local game = {
      startup_synthetic_players = {
        { player_id = -2, unit_key = "npc_2" },
      },
      board = { map = { path = { 1, 2, 3 } } },
    }
    ui_bootstrap.spawn_startup_synthetic_actors(game)
  end)

  assert(type(capture.registered_specs) == "table" and capture.registered_specs[1].player_id == -2,
    "ui bootstrap should register startup synthetic actor specs")
  assert(capture.spawned_map and capture.spawned_map.path[1] == 1,
    "ui bootstrap should spawn pending synthetic actors with board map")
end

local function _test_runtime_context_first_role_from_game_api_with_valid_roles()
  local role = { id = 5, get_roleid = function() return 5 end }
  local ctx = runtime_context.new({
    GameAPI = {
      get_all_valid_roles = function()
        return { role }
      end,
      get_role = function(id)
        if id == 5 then return role end
        return nil
      end,
    },
    LuaAPI = {
      call_delay_time = function() end,
      global_register_custom_event = function() end,
      global_register_trigger_event = function() end,
      unit_register_custom_event = function() end,
      unit_register_trigger_event = function() end,
      global_send_custom_event = function() end,
    },
  })

  runtime_context.install_environment(ctx)
  runtime_context.install_runtime_helpers(ctx)

  local helper = ctx.vehicle_helper
  local resolved = helper.resolve_any_role()
  _assert_eq(resolved, role, "resolve_any_role should return first role from GameAPI")
end

local function _test_runtime_context_first_role_from_game_api_empty_list_fallback()
  local role = { id = 3, get_roleid = function() return 3 end }
  local ctx = runtime_context.new({
    GameAPI = {
      get_all_valid_roles = function()
        return {}
      end,
      get_role = function(id)
        if id == 3 then return role end
        return nil
      end,
    },
    LuaAPI = {
      call_delay_time = function() end,
      global_register_custom_event = function() end,
      global_register_trigger_event = function() end,
      unit_register_custom_event = function() end,
      unit_register_trigger_event = function() end,
      global_send_custom_event = function() end,
    },
  })

  runtime_context.install_environment(ctx)
  runtime_context.install_runtime_helpers(ctx)

  local helper = ctx.vehicle_helper
  local resolved = helper.resolve_any_role()
  _assert_eq(resolved, role, "resolve_any_role should fall back to role range when GameAPI returns empty list")
end

local function _test_runtime_context_first_role_from_game_api_nil_game_api()
  local ctx = runtime_context.new({
    LuaAPI = {
      call_delay_time = function() end,
      global_register_custom_event = function() end,
      global_register_trigger_event = function() end,
      unit_register_custom_event = function() end,
      unit_register_trigger_event = function() end,
      global_send_custom_event = function() end,
    },
  })

  runtime_context.install_environment(ctx)
  runtime_context.install_runtime_helpers(ctx)

  local helper = ctx.vehicle_helper
  local resolved = helper.resolve_any_role()
  _assert_eq(resolved, nil, "resolve_any_role should return nil when GameAPI is nil and no ctx.roles set")
end

local function _test_runtime_context_first_role_from_game_api_pcall_failure()
  local role = { id = 5, get_roleid = function() return 5 end }
  local ctx = runtime_context.new({
    GameAPI = {
      get_all_valid_roles = function()
        return { role }
      end,
      get_role = function(id)
        if id == 5 then return role end
        return nil
      end,
    },
    LuaAPI = {
      call_delay_time = function() end,
      global_register_custom_event = function() end,
      global_register_trigger_event = function() end,
      unit_register_custom_event = function() end,
      unit_register_trigger_event = function() end,
      global_send_custom_event = function() end,
    },
  })

  runtime_context.install_environment(ctx)
  runtime_context.install_runtime_helpers(ctx)

  local helper = ctx.vehicle_helper
  local resolved = helper.resolve_any_role()
  _assert_eq(resolved, role, "resolve_any_role should return role from GameAPI when pcall succeeds")
end

local function _test_runtime_context_install_runtime_helpers_survives_game_api_refresh_error()
  local ctx = runtime_context.new({
    GameAPI = {
      get_all_valid_roles = function()
        error("boom")
      end,
    },
    LuaAPI = {
      call_delay_time = function() end,
      global_register_custom_event = function() end,
      global_register_trigger_event = function() end,
      unit_register_custom_event = function() end,
      unit_register_trigger_event = function() end,
      global_send_custom_event = function() end,
    },
  })

  runtime_context.install_environment(ctx)

  local ok, helpers_or_err = pcall(function()
    return runtime_context.install_runtime_helpers(ctx)
  end)

  _assert_eq(ok, true, "install_runtime_helpers should ignore GameAPI refresh errors")
  local helpers = helpers_or_err
  _assert_eq(type(helpers.vehicle_helper.resolve_any_role), "function",
    "install_runtime_helpers should still return the noop vehicle helper")
  _assert_eq(helpers.vehicle_helper.resolve_any_role(), nil,
    "noop helper should keep returning nil after refresh failure")
  _assert_eq(type(ctx.roles), "table", "refresh failure should still leave roles as a table")
  _assert_eq(#ctx.roles, 0, "refresh failure should fall back to an empty role list")
end

local function _test_release_runtime_context_resolve_role_ignores_non_function_get_role()
  support.with_patches({
    { key = "MONOPOLY_BUILD_MODE", value = "release" },
  }, function()
    local ctx = runtime_context.new({
      GameAPI = {
        get_role = "not a function",
      },
      LuaAPI = {
        call_delay_time = function() end,
        global_register_custom_event = function() end,
        global_register_trigger_event = function() end,
        unit_register_custom_event = function() end,
        unit_register_trigger_event = function() end,
        global_send_custom_event = function() end,
      },
    })

    runtime_context.install_environment(ctx)
    ctx.roles = {}
    runtime_context.install_runtime_helpers(ctx)

    local helper = ctx.vehicle_helper
    _assert_eq(helper.resolve_role(4), nil, "release helper should return nil when GameAPI.get_role is not callable")
  end)
end

local function _test_release_runtime_context_resolve_any_role_prefers_provider_roles()
  support.with_patches({
    { key = "MONOPOLY_BUILD_MODE", value = "release" },
  }, function()
    local provider_role = { id = 7, get_roleid = function() return 7 end }
    local fallback_role = { id = 8, get_roleid = function() return 8 end }
    local ctx = runtime_context.new({
      GameAPI = {
        get_all_valid_roles = function()
          return { fallback_role }
        end,
        get_role = function(role_id)
          if role_id == 7 then
            return provider_role
          end
          if role_id == 8 then
            return fallback_role
          end
          return nil
        end,
      },
      LuaAPI = {
        call_delay_time = function() end,
        global_register_custom_event = function() end,
        global_register_trigger_event = function() end,
        unit_register_custom_event = function() end,
        unit_register_trigger_event = function() end,
        global_send_custom_event = function() end,
      },
    })

    runtime_context.install_environment(ctx)
    ctx.roles = { provider_role }
    runtime_context.install_runtime_helpers(ctx)

    local helper = ctx.vehicle_helper
    local resolved = helper.resolve_any_role()
    _assert_eq(resolved, provider_role, "release helper should prefer provider roles before GameAPI fallback")
  end)
end

local function _test_release_runtime_context_resolve_any_role_uses_game_api_fallback()
  support.with_patches({
    { key = "MONOPOLY_BUILD_MODE", value = "release" },
  }, function()
    local fallback_role = { id = 8, get_roleid = function() return 8 end }
    local ctx = runtime_context.new({
      GameAPI = {
        get_all_valid_roles = function()
          return { fallback_role }
        end,
        get_role = function(role_id)
          if role_id == 8 then
            return fallback_role
          end
          return nil
        end,
      },
      LuaAPI = {
        call_delay_time = function() end,
        global_register_custom_event = function() end,
        global_register_trigger_event = function() end,
        unit_register_custom_event = function() end,
        unit_register_trigger_event = function() end,
        global_send_custom_event = function() end,
      },
    })

    runtime_context.install_environment(ctx)
    ctx.roles = {}
    runtime_context.install_runtime_helpers(ctx)

    local helper = ctx.vehicle_helper
    local resolved = helper.resolve_any_role()
    _assert_eq(resolved, fallback_role, "release helper should use GameAPI valid roles when provider roles are empty")
  end)
end

local function _test_release_runtime_context_resolve_any_role_returns_nil_on_game_api_error()
  support.with_patches({
    { key = "MONOPOLY_BUILD_MODE", value = "release" },
  }, function()
    local ctx = runtime_context.new({
      GameAPI = {
        get_all_valid_roles = function()
          error("boom")
        end,
      },
      LuaAPI = {
        call_delay_time = function() end,
        global_register_custom_event = function() end,
        global_register_trigger_event = function() end,
        unit_register_custom_event = function() end,
        unit_register_trigger_event = function() end,
        global_send_custom_event = function() end,
      },
    })

    runtime_context.install_environment(ctx)
    ctx.roles = {}
    runtime_context.install_runtime_helpers(ctx)

    local helper = ctx.vehicle_helper
    local resolved = helper.resolve_any_role()
    _assert_eq(resolved, nil, "release helper should return nil when GameAPI valid role lookup errors")
  end)
end

local function _test_release_runtime_context_resolve_any_role_returns_nil_without_game_api()
  support.with_patches({
    { key = "MONOPOLY_BUILD_MODE", value = "release" },
  }, function()
    local ctx = runtime_context.new({
      LuaAPI = {
        call_delay_time = function() end,
        global_register_custom_event = function() end,
        global_register_trigger_event = function() end,
        unit_register_custom_event = function() end,
        unit_register_trigger_event = function() end,
        global_send_custom_event = function() end,
      },
    })

    runtime_context.install_environment(ctx)
    ctx.roles = {}
    runtime_context.install_runtime_helpers(ctx)

    local helper = ctx.vehicle_helper
    local resolved = helper.resolve_any_role()
    _assert_eq(resolved, nil, "release helper should return nil when no provider roles or GameAPI exist")
  end)
end

local function _test_release_runtime_context_resolve_role_handles_nil_missing_error_and_success()
  support.with_patches({
    { key = "MONOPOLY_BUILD_MODE", value = "release" },
  }, function()
    local role = { id = 4, get_roleid = function() return 4 end }
    local ctx = runtime_context.new({
      GameAPI = {
        get_role = function(role_id)
          if role_id == 4 then
            return role
          end
          error("missing role")
        end,
      },
      LuaAPI = {
        call_delay_time = function() end,
        global_register_custom_event = function() end,
        global_register_trigger_event = function() end,
        unit_register_custom_event = function() end,
        unit_register_trigger_event = function() end,
        global_send_custom_event = function() end,
      },
    })

    runtime_context.install_environment(ctx)
    runtime_context.install_runtime_helpers(ctx)

    local helper = ctx.vehicle_helper
    _assert_eq(helper.resolve_role(nil), nil, "release helper should return nil when role_id is nil")

    ctx.env.GameAPI = {}
    _assert_eq(helper.resolve_role(4), nil, "release helper should return nil when GameAPI.get_role is missing")

    ctx.env.GameAPI = {
      get_role = function()
        error("boom")
      end,
    }
    _assert_eq(helper.resolve_role(4), nil, "release helper should swallow get_role errors")

    ctx.env.GameAPI = {
      get_role = function(role_id)
        if role_id == 4 then
          return role
        end
        return nil
      end,
    }
    _assert_eq(helper.resolve_role(4), role, "release helper should return role when GameAPI.get_role succeeds")
  end)
end

local function _test_callback_registry_wait_lifecycle()
  local game = {}
  local wait_key = wait_callbacks.wait_keys.landing_visual
  local seq = wait_callbacks.begin_wait(game, wait_key)
  _assert_eq(wait_callbacks.pending_wait_seq(game, wait_key), seq, "begin_wait should store pending seq")
  _assert_eq(wait_callbacks.is_wait_ready(game, wait_key), false, "new wait should not be ready")
  _assert_eq(wait_callbacks.mark_wait_ready(game, wait_key, seq), true, "mark_wait_ready should accept matching seq")
  _assert_eq(wait_callbacks.is_wait_ready(game, wait_key), true, "ready wait should report ready")
  _assert_eq(wait_callbacks.finish_wait(game, wait_key, seq), true, "finish_wait should clear matching wait")
  _assert_eq(wait_callbacks.pending_wait_seq(game, wait_key), nil, "finish_wait should clear pending seq")
  _assert_eq(wait_callbacks.is_wait_ready(game, wait_key), false, "finished wait should no longer be ready")
end

local function _clear_module(module_name)
  package.loaded[module_name] = nil
end

local function _with_game_state_mixins(player_mixin, board_mixin, turn_mixin, fn)
  with_patches({
    { target = package.loaded, key = "src.state.player_state", value = player_mixin },
    { target = package.loaded, key = "src.state.board_state", value = board_mixin },
    { target = package.loaded, key = "src.state.turn_state", value = turn_mixin },
    { target = package.loaded, key = "src.state.game_state", value = nil },
  }, function()
    _clear_module("src.state.game_state")
    fn()
    _clear_module("src.state.game_state")
  end, {
    skip_runtime_context_refresh = true,
  })
end

local function _test_game_state_installs_distinct_mixins()
  _with_game_state_mixins({
    player_only = function()
      return "player"
    end,
  }, {
    board_only = function()
      return "board"
    end,
  }, {
    turn_only = function()
      return "turn"
    end,
  }, function()
    local game_state = require("src.state.game_state")
    assert(type(game_state.player_only) == "function", "player mixin should install")
    assert(type(game_state.board_only) == "function", "board mixin should install")
    assert(type(game_state.turn_only) == "function", "turn mixin should install")
  end)
end

local function _test_game_state_rejects_mixin_key_collision()
  _with_game_state_mixins({
    shared_key = function()
      return "player"
    end,
  }, {
    shared_key = function()
      return "board"
    end,
  }, {}, function()
    local ok, err = pcall(require, "src.state.game_state")
    _assert_eq(ok, false, "duplicate mixin key should fail module assembly")
    assert(string.find(tostring(err), "game_state mixin collision: board.shared_key", 1, true) ~= nil,
      "collision error should include conflicting mixin key, err=" .. tostring(err))
  end)
end

return {
  name = "misc",
  tests = {
    { name = "number_utils_to_integer", run = _test_number_utils_to_integer },
    { name = "number_utils_to_integer_fallback_from_tostring", run = _test_number_utils_to_integer_fallback_from_tostring },
    { name = "number_utils_to_integer_fallback_rejects_non_integer_text", run = _test_number_utils_to_integer_fallback_rejects_non_integer_text },
    tip_queue_tests[1], -- tip_queue_uses_fifo_queue_without_override
    tip_queue_tests[2], -- tip_queue_dedupes_same_semantic_key_across_active_and_pending
    tip_queue_tests[3], -- tip_queue_only_blocks_inter_turn_for_blocking_tips
    tip_queue_tests[4], -- tip_queue_non_blocking_tip_never_gates_inter_turn
    tip_queue_tests[5], -- tip_queue_clear_cancels_stale_timeout_without_replaying_queue
    logger_tests[1],  -- logger_event_only_writes_event_feed_without_showing_tip
    logger_tests[2],  -- logger_event_no_tips_stays_in_event_feed_without_showing_tip
    logger_tests[3],  -- logger_configure_host_runtime_uses_injected_hooks
    logger_tests[4],  -- logger_event_collection_provider_drops_closed_action_log_events
    logger_tests[5],  -- logger_event_seq_only_tracks_event_feed_changes
    { name = "synthetic_actor_registry_spawns_from_first_path_tile", run = _test_synthetic_actor_registry_spawns_from_first_path_tile },
    {
      name = "synthetic_actor_registry_reset_destroys_spawned_actor_and_clears_registry",
      run = _test_synthetic_actor_registry_reset_destroys_spawned_actor_and_clears_registry,
    },
    { name = "ui_bootstrap_required_click_nodes_appends_extras", run = _test_ui_bootstrap_required_click_nodes_appends_extras },
    { name = "default_ports_wall_diff_seconds_prefers_game_api_then_falls_back", run = _test_default_ports_wall_diff_seconds_prefers_game_api_then_falls_back },
    { name = "ui_bootstrap_spawns_startup_synthetic_actors", run = _test_ui_bootstrap_spawns_startup_synthetic_actors },
    lvh_tests[1],   -- landing_visual_hold_defer_dirty_initializes_bucket_and_merges_inventory
    logger_tests[6],  -- logger_flush_event_buffer_replays_buffered_events
    logger_tests[7],  -- logger_flush_event_buffer_skips_when_buffer_not_active
    logger_tests[8],  -- logger_flush_event_buffer_no_tip_replay
    logger_tests[9],  -- logger_flush_event_buffer_empty_buffer_returns_false
    logger_tests[10], -- logger_flush_event_buffer_invalid_buffer_returns_false
    { name = "runtime_context_first_role_from_game_api_with_valid_roles", run = _test_runtime_context_first_role_from_game_api_with_valid_roles },
    { name = "runtime_context_first_role_from_game_api_empty_list_fallback", run = _test_runtime_context_first_role_from_game_api_empty_list_fallback },
    { name = "runtime_context_first_role_from_game_api_nil_game_api", run = _test_runtime_context_first_role_from_game_api_nil_game_api },
    { name = "runtime_context_first_role_from_game_api_pcall_failure", run = _test_runtime_context_first_role_from_game_api_pcall_failure },
    {
      name = "runtime_context_install_runtime_helpers_survives_game_api_refresh_error",
      run = _test_runtime_context_install_runtime_helpers_survives_game_api_refresh_error,
    },
    {
      name = "release_runtime_context_resolve_role_ignores_non_function_get_role",
      run = _test_release_runtime_context_resolve_role_ignores_non_function_get_role,
    },
    { name = "release_runtime_context_resolve_any_role_prefers_provider_roles", run = _test_release_runtime_context_resolve_any_role_prefers_provider_roles },
    { name = "release_runtime_context_resolve_any_role_uses_game_api_fallback", run = _test_release_runtime_context_resolve_any_role_uses_game_api_fallback },
    { name = "release_runtime_context_resolve_any_role_returns_nil_on_game_api_error", run = _test_release_runtime_context_resolve_any_role_returns_nil_on_game_api_error },
    { name = "release_runtime_context_resolve_any_role_returns_nil_without_game_api", run = _test_release_runtime_context_resolve_any_role_returns_nil_without_game_api },
    { name = "release_runtime_context_resolve_role_handles_nil_missing_error_and_success", run = _test_release_runtime_context_resolve_role_handles_nil_missing_error_and_success },
    lvh_tests[2],  -- landing_visual_hold_release_flushes_event_buffer_and_replays_deferred
    { name = "callback_registry_wait_lifecycle", run = _test_callback_registry_wait_lifecycle },
    { name = "game_state_installs_distinct_mixins", run = _test_game_state_installs_distinct_mixins },
    { name = "game_state_rejects_mixin_key_collision", run = _test_game_state_rejects_mixin_key_collision },
    lvh_tests[3],  -- landing_visual_hold_release_orders_wrappers_by_priority
    lvh_tests[4],  -- landing_visual_hold_release_skips_when_not_pending
    gateway_tests[1],  -- eggy_paid_gateway_callback_missing_goods_id
    gateway_tests[2],  -- eggy_paid_gateway_callback_empty_goods_id
    gateway_tests[3],  -- eggy_paid_gateway_callback_missing_pending
    gateway_tests[4],  -- eggy_paid_gateway_callback_missing_player
    gateway_tests[5],  -- eggy_paid_gateway_callback_missing_entry
    gateway_tests[6],  -- eggy_paid_gateway_callback_success_with_on_purchase
    gateway_tests[7],  -- eggy_paid_gateway_callback_success_without_on_purchase
    gateway_tests[8],  -- eggy_paid_gateway_start_missing_purchase_api
  },
}
