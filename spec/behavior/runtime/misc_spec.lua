---@diagnostic disable: need-check-nil, different-requires, undefined-field

local support = require("support.runtime_support")
local _assert_eq = support.assert_eq
local with_patches = support.with_patches
local number_utils = support.number_utils
local runtime_constants = require("src.config.gameplay.runtime_constants")
local runtime_context = require("src.host.context")
local default_ports = require("src.host.default_ports")
local wait_callbacks = require("src.turn.waits.callback_registry")






















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

-- merged preamble from suites.runtime.misc_tip_queue
local tip_queue = require("src.foundation.coordination.tip_queue")

local function _reset_tip_queue()
  tip_queue.clear()
  tip_queue.configure_runtime({
    clear_presenter = true,
    clear_scheduler = true,
    test_mode = false,
  })
end

local function _with_queue_runtime(fn)
  _reset_tip_queue()
  local ok, err = pcall(fn)
  _reset_tip_queue()
  if not ok then
    error(err)
  end
end

-- merged preamble from suites.runtime.misc_landing_visual_hold
local event_log = require("src.state.event_log")
local landing_visual_hold = require("src.state.visual_hold")

describe("misc", function()
  it("number_utils_to_integer", function()
    _assert_eq(number_utils.to_integer("12"), 12, "string integer should parse")
    _assert_eq(number_utils.to_integer("-7"), -7, "negative string integer should parse")
    _assert_eq(number_utils.to_integer("12.3"), nil, "float string should be rejected")
  end)

  it("number_utils_to_integer_fallback_from_tostring", function()
    local wrapped = setmetatable({}, {
      __tostring = function()
        return "5"
      end,
    })
    _assert_eq(number_utils.to_integer(wrapped), 5, "non-numeric value should parse from tostring fallback")
  end)

  it("number_utils_to_integer_fallback_rejects_non_integer_text", function()
    local wrapped = setmetatable({}, {
      __tostring = function()
        return "abc"
      end,
    })
    _assert_eq(number_utils.to_integer(wrapped), nil, "non-integer tostring fallback should be rejected")
  end)

  it("tip_queue_uses_fifo_queue_without_override", function()
    local shown = {}
    local timers = {}

    _with_queue_runtime(function()
      tip_queue.configure_runtime({
        presenter = function(text, duration)
          shown[#shown + 1] = { text = text, duration = duration }
        end,
        scheduler = function(delay, fn)
          timers[#timers + 1] = { delay = delay, fn = fn }
          return true
        end,
      })

      tip_queue.enqueue({
        text = "A",
        duration = 3.0,
        dedupe_key = "tip_a",
      })
      tip_queue.enqueue({
        text = "B",
        duration = 2.0,
        dedupe_key = "tip_b",
      })

      _assert_eq(#shown, 1, "second tip should wait until the first tip releases")
      _assert_eq(shown[1].text, "A", "first shown tip should be A")
      _assert_eq(#timers, 1, "first tip should schedule one release timer")
      _assert_eq(timers[1].delay, 3.0, "first tip release timer should match duration")

      timers[1].fn()

      _assert_eq(#shown, 2, "second tip should show after first tip release")
      _assert_eq(shown[2].text, "B", "second shown tip should be B")
      _assert_eq(#timers, 2, "second tip should schedule another release timer")
      _assert_eq(timers[2].delay, 2.0, "second tip release timer should match duration")
    end)
  end)

  it("tip_queue_dedupes_same_semantic_key_across_active_and_pending", function()
    local shown = {}
    local timers = {}

    _with_queue_runtime(function()
      tip_queue.configure_runtime({
        presenter = function(text, duration)
          shown[#shown + 1] = { text = text, duration = duration }
        end,
        scheduler = function(delay, fn)
          timers[#timers + 1] = { delay = delay, fn = fn }
          return true
        end,
      })

      _assert_eq(tip_queue.enqueue({
        text = "active",
        duration = 3.0,
        dedupe_key = "same_semantic_tip",
      }), true, "first semantic tip should enqueue")
      _assert_eq(tip_queue.enqueue({
        text = "duplicate_active",
        duration = 1.0,
        dedupe_key = "same_semantic_tip",
      }), false, "active duplicate should be dropped")
      _assert_eq(tip_queue.enqueue({
        text = "queued",
        duration = 2.0,
        dedupe_key = "other_semantic_tip",
      }), true, "different semantic tip should enqueue")
      _assert_eq(tip_queue.enqueue({
        text = "duplicate_queued",
        duration = 1.0,
        dedupe_key = "other_semantic_tip",
      }), false, "queued duplicate should be dropped")

      _assert_eq(#shown, 1, "only the active tip should show immediately")
      _assert_eq(#timers, 1, "only one timer should exist before release")

      timers[1].fn()

      _assert_eq(#shown, 2, "queued semantic tip should show after release")
      _assert_eq(shown[2].text, "queued", "first queued semantic tip should win")
    end)
  end)

  it("tip_queue_only_blocks_inter_turn_for_blocking_tips", function()
    local timers = {}

    _with_queue_runtime(function()
      tip_queue.configure_runtime({
        presenter = function() end,
        scheduler = function(delay, fn)
          timers[#timers + 1] = { delay = delay, fn = fn }
          return true
        end,
      })

      tip_queue.enqueue({
        text = "non_blocking",
        duration = 3.0,
        dedupe_key = "non_blocking_tip",
        blocks_inter_turn = false,
      })
      tip_queue.enqueue({
        text = "blocking",
        duration = 2.0,
        dedupe_key = "blocking_tip",
        blocks_inter_turn = true,
      })

      _assert_eq(tip_queue.has_blocking_pending("inter_turn"), true, "blocking tip should gate inter-turn")
      _assert_eq(tip_queue.has_blocking_pending("choice"), false, "choice phase should ignore tip queue")
      _assert_eq(tip_queue.has_blocking_pending("landing"), false, "landing phase should ignore tip queue")

      timers[1].fn()

      _assert_eq(tip_queue.has_blocking_pending("inter_turn"), true, "active blocking tip should keep inter-turn gated")

      timers[2].fn()

      _assert_eq(tip_queue.has_blocking_pending("inter_turn"), false, "inter-turn gate should clear after blocking tip drains")
    end)
  end)

  it("tip_queue_non_blocking_tip_never_gates_inter_turn", function()
    _with_queue_runtime(function()
      tip_queue.configure_runtime({
        presenter = function() end,
        scheduler = function()
          return true
        end,
      })

      tip_queue.enqueue({
        text = "diagnostic",
        duration = 2.0,
        dedupe_key = "diagnostic_tip",
        blocks_inter_turn = false,
      })

      _assert_eq(tip_queue.has_blocking_pending("inter_turn"), false, "non-blocking tip should not gate inter-turn")
    end)
  end)

  it("tip_queue_clear_cancels_stale_timeout_without_replaying_queue", function()
    local shown = {}
    local timers = {}

    _with_queue_runtime(function()
      tip_queue.configure_runtime({
        presenter = function(text)
          shown[#shown + 1] = text
        end,
        scheduler = function(delay, fn)
          timers[#timers + 1] = { delay = delay, fn = fn }
          return true
        end,
      })

      tip_queue.enqueue({
        text = "first",
        duration = 3.0,
        dedupe_key = "first_tip",
        blocks_inter_turn = true,
      })
      tip_queue.enqueue({
        text = "second",
        duration = 2.0,
        dedupe_key = "second_tip",
        blocks_inter_turn = true,
      })

      _assert_eq(#shown, 1, "first tip should show immediately")
      _assert_eq(shown[1], "first", "first shown tip should be first")

      tip_queue.clear()
      timers[1].fn()

      _assert_eq(#shown, 1, "stale timeout should not replay cleared queue")
      _assert_eq(tip_queue.has_blocking_pending("inter_turn"), false, "clear should drop blocking gate")
    end)
  end)

  it("synthetic_actor_registry_spawns_from_first_path_tile", function()
    local registry_module = require("src.host.synthetic_actor_registry")
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
  end)

  it("synthetic_actor_registry_reset_destroys_spawned_actor_and_clears_registry", function()
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
  end)

  it("ui_bootstrap_required_click_nodes_appends_extras", function()
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
        target = require("src.ui.coord.ui_events"),
        key = "send_to_all",
        value = function() end,
      },
      {
        target = require("src.ui.coord.canvas_event_router"),
        key = "bind",
        value = function() end,
      },
      {
        target = require("src.ui.coord.ui_runtime"),
        key = "init_ui_assets",
        value = function() end,
      },
      {
        target = require("src.ui.coord.ui_runtime"),
        key = "capture_player_colors",
        value = function() end,
      },
      {
        target = require("src.ui.render.board.scene"),
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
        target = require("src.foundation.ports.runtime_ports"),
        key = "resolve_roles",
        value = function()
          return {}
        end,
      },
      {
        target = require("src.foundation.ports.runtime_ports"),
        key = "schedule",
        value = function(_, fn)
          fn()
        end,
      },
      {
      target = require("src.state.ui_role_globals"),
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
  end)

  it("default_ports_wall_diff_seconds_prefers_game_api_then_falls_back", function()
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
  end)

  it("ui_bootstrap_spawns_startup_synthetic_actors", function()
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
  end)

  it("landing_visual_hold_defer_dirty_initializes_bucket_and_merges_inventory", function()
    local state = {}
    local dirty = {
      any = true,
      players = true,
      inventory_ids = {
        [1] = true,
        [2] = true,
      },
    }

    local deferred = landing_visual_hold.defer_dirty(state, dirty)
    assert(deferred.any == true and deferred.players == true, "defer_dirty should merge boolean dirty flags")
    assert(deferred.inventory_ids[1] == true and deferred.inventory_ids[2] == true,
      "defer_dirty should merge inventory_ids into initialized deferred bucket")
  end)

  it("runtime_context_first_role_from_game_api_with_valid_roles", function()
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
  end)

  it("runtime_context_first_role_from_game_api_empty_list_fallback", function()
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
  end)

  it("runtime_context_first_role_from_game_api_nil_game_api", function()
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
  end)

  it("runtime_context_first_role_from_game_api_pcall_failure", function()
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
  end)

  it("runtime_context_install_runtime_helpers_survives_game_api_refresh_error", function()
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
  end)

  it("release_runtime_context_resolve_role_ignores_non_function_get_role", function()
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
  end)

  it("release_runtime_context_resolve_any_role_prefers_provider_roles", function()
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
  end)

  it("release_runtime_context_resolve_any_role_uses_game_api_fallback", function()
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
  end)

  it("release_runtime_context_resolve_any_role_returns_nil_on_game_api_error", function()
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
  end)

  it("release_runtime_context_resolve_any_role_returns_nil_without_game_api", function()
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
  end)

  it("release_runtime_context_resolve_role_handles_nil_missing_error_and_success", function()
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
  end)

  it("landing_visual_hold_release_flushes_event_buffer_and_replays_deferred", function()
    local state = {}
    local game = {
      state = {
        event_log = event_log.new(),
      },
      dirty = {},
      turn = {
        landing_visual_hold_active = false,
        landing_visual_release_pending = false,
      },
    }

    local replayed_visual_syncs = {}
    local replayed_runtime_events = {}
    local replayed_popups = {}

    landing_visual_hold.start(game)
    landing_visual_hold.mark_release_pending(game)

    local hold = landing_visual_hold.sync_state_from_game(state, game)
    event_log.append(game.state.event_log, {
      kind = "test",
      text = "deferred event during hold",
    })

    landing_visual_hold.defer_board_visual_sync(state, { sync_data = true }, function(payload)
      replayed_visual_syncs[#replayed_visual_syncs + 1] = payload
    end)

    landing_visual_hold.defer_runtime_event(state, "test_event", { event_data = true }, function(payload)
      replayed_runtime_events[#replayed_runtime_events + 1] = payload
    end)

    landing_visual_hold.defer_popup(state, { popup_data = true }, { opt = 1 }, function(payload, opts)
      replayed_popups[#replayed_popups + 1] = { payload = payload, opts = opts }
    end)

    _assert_eq(#hold.release_callbacks, 3, "release should register all deferred callbacks")
    _assert_eq(hold.release_callbacks[1].key, "board_visual_sync", "visual sync should register first")
    _assert_eq(hold.release_callbacks[2].key, "runtime_event", "runtime event should register second")
    _assert_eq(hold.release_callbacks[3].key, "popup", "popup should register third")

    local released = landing_visual_hold.release(state, game)

    _assert_eq(released, true, "release should return true when release was pending")
    _assert_eq(#replayed_visual_syncs, 1, "release should replay deferred visual syncs")
    _assert_eq(replayed_visual_syncs[1].sync_data, true, "visual sync payload should be preserved")
    _assert_eq(#replayed_runtime_events, 1, "release should replay deferred runtime events")
    _assert_eq(replayed_runtime_events[1].event_data, true, "runtime event payload should be preserved")
    _assert_eq(#replayed_popups, 1, "release should replay deferred popups")
    _assert_eq(replayed_popups[1].payload.popup_data, true, "popup payload should be preserved")

    local text = event_log.get_text(game.state.event_log)
    assert(string.find(text, "deferred event during hold", 1, true) ~= nil, "release should flush event buffer")
  end)

  it("callback_registry_wait_lifecycle", function()
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
  end)

  it("game_state_installs_distinct_mixins", function()
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
  end)

  it("game_state_rejects_mixin_key_collision", function()
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
  end)

  it("landing_visual_hold_release_orders_wrappers_by_priority", function()
    local state = {}
    local game = {
      dirty = {},
      turn = {
        landing_visual_hold_active = false,
        landing_visual_release_pending = false,
      },
    }
    local calls = {}

    landing_visual_hold.start(game)
    landing_visual_hold.mark_release_pending(game)
    local hold = landing_visual_hold.sync_state_from_game(state, game)

    landing_visual_hold.defer_popup(state, { name = "popup" }, nil, function(payload)
      calls[#calls + 1] = payload.name
    end)
    landing_visual_hold.defer_bankruptcy_clear(state, game, { id = 1 }, { 2 }, function(_, player)
      calls[#calls + 1] = "bankruptcy_" .. tostring(player.id)
    end)
    landing_visual_hold.defer_owner_change(state, 7, 8, function(tile_id, owner_id)
      calls[#calls + 1] = "owner_" .. tostring(tile_id) .. "_" .. tostring(owner_id)
    end)
    landing_visual_hold.defer_tile_update(state, 5, 6, function(tile_id, level)
      calls[#calls + 1] = "tile_" .. tostring(tile_id) .. "_" .. tostring(level)
    end)
    landing_visual_hold.defer_runtime_event(state, "evt", { name = "runtime" }, function(payload)
      calls[#calls + 1] = payload.name
    end)
    landing_visual_hold.defer_board_visual_sync(state, { name = "board" }, function(payload)
      calls[#calls + 1] = payload.name
    end)

    _assert_eq(#hold.release_callbacks, 6, "all wrapper helpers should register release callbacks")
    _assert_eq(landing_visual_hold.release(state, game), true, "release should flush deferred callbacks")
    _assert_eq(table.concat(calls, ","), "board,runtime,tile_5_6,owner_7_8,bankruptcy_1,popup",
      "release should replay wrapper callbacks in configured priority order")
  end)

  it("landing_visual_hold_release_skips_when_not_pending", function()
    local state = {}
    local game = {
      dirty = {},
      turn = {
        landing_visual_hold_active = false,
        landing_visual_release_pending = false,
      },
    }

    landing_visual_hold.start(game)

    local released = landing_visual_hold.release(state, game)
    _assert_eq(released, false, "release should return false when release_pending is false")
  end)

  it("eggy_paid_gateway_callback_missing_goods_id", function()
    local gateway = require("src.host.paid_purchase_gateway")
    local game = { players = {} }
    local rt = gateway._runtime(game)
    local warned = nil

    with_patches({
      {
        target = require("src.foundation.log.logger"),
        key = "warn",
        value = function(msg)
          warned = msg
        end,
      },
    }, function()
      gateway._on_purchase_goods_callback(game, rt, {})
    end)

    _assert_eq(warned, "market paid callback ignored: goods_id missing", "should warn when goods_id is missing")
  end)

  it("eggy_paid_gateway_callback_empty_goods_id", function()
    local gateway = require("src.host.paid_purchase_gateway")
    local game = { players = {} }
    local rt = gateway._runtime(game)
    local warned = nil

    with_patches({
      {
        target = require("src.foundation.log.logger"),
        key = "warn",
        value = function(msg)
          warned = msg
        end,
      },
    }, function()
      gateway._on_purchase_goods_callback(game, rt, { goods_id = "" })
    end)

    _assert_eq(warned, "market paid callback ignored: goods_id missing", "should warn when goods_id is empty")
  end)

  it("eggy_paid_gateway_callback_missing_pending", function()
    local gateway = require("src.host.paid_purchase_gateway")
    local game = { players = {} }
    local rt = gateway._runtime(game)
    local warned = nil

    with_patches({
      {
        target = require("src.foundation.log.logger"),
        key = "warn",
        value = function(msg, ctx1, ctx2)
          warned = msg .. " " .. tostring(ctx1) .. " " .. tostring(ctx2)
        end,
      },
    }, function()
      gateway._on_purchase_goods_callback(game, rt, { goods_id = "goods_123" })
    end)

    assert(warned and warned:find("pending missing", 1, true), "should warn when pending is missing: " .. tostring(warned))
  end)

  it("eggy_paid_gateway_callback_missing_player", function()
    local gateway = require("src.host.paid_purchase_gateway")
    local game = {
      players = {},
      find_player_by_id = function()
        return nil
      end,
    }
    local rt = gateway._runtime(game)
    gateway._push_pending(rt, 5, { player_id = 99, product_id = 1001, goods_id = "goods_123" })
    local warned = nil

    with_patches({
      {
        target = require("src.foundation.log.logger"),
        key = "warn",
        value = function(msg, ctx)
          warned = msg .. " " .. tostring(ctx)
        end,
      },
    }, function()
      gateway._on_purchase_goods_callback(game, rt, { goods_id = "goods_123", role = { get_roleid = function() return 5 end } })
    end)

    assert(warned and warned:find("player missing", 1, true), "should warn when player is missing: " .. tostring(warned))
  end)

  it("eggy_paid_gateway_callback_missing_entry", function()
    local gateway = require("src.host.paid_purchase_gateway")
    local mock_player = { id = 99 }
    local game = {
      players = { mock_player },
      find_player_by_id = function()
        return mock_player
      end,
    }
    local rt = gateway._runtime(game)
    gateway._push_pending(rt, 5, { player_id = 99, product_id = 9999, goods_id = "goods_123" })
    local warned = nil

    with_patches({
      {
        target = require("src.rules.market.query.context"),
        key = "entry_by_id",
        value = function()
          return nil
        end,
      },
      {
        target = require("src.foundation.log.logger"),
        key = "warn",
        value = function(msg, ctx)
          warned = msg .. " " .. tostring(ctx)
        end,
      },
    }, function()
      gateway._on_purchase_goods_callback(game, rt, { goods_id = "goods_123", role = { get_roleid = function() return 5 end } })
    end)

    assert(warned and warned:find("market entry missing", 1, true), "should warn when entry is missing: " .. tostring(warned))
  end)

  it("eggy_paid_gateway_callback_success_with_on_purchase", function()
    local gateway = require("src.host.paid_purchase_gateway")
    local mock_player = { id = 99 }
    local mock_entry = { product_id = 1001, name = "Test Item" }
    local game = {
      players = { mock_player },
      find_player_by_id = function()
        return mock_player
      end,
    }
    local rt = gateway._runtime(game)
    local purchase_called = false
    rt.on_purchase = function(g, p, e, pending)
      purchase_called = true
      _assert_eq(g, game, "game should match")
      _assert_eq(p, mock_player, "player should match")
      _assert_eq(e, mock_entry, "entry should match")
      _assert_eq(pending.product_id, 1001, "pending product_id should match")
    end
    gateway._push_pending(rt, 5, { player_id = 99, product_id = 1001, goods_id = "goods_123" })

    with_patches({
      {
        target = require("src.rules.market.query.context"),
        key = "entry_by_id",
        value = function(id)
          if id == 1001 then return mock_entry end
          return nil
        end,
      },
    }, function()
      gateway._on_purchase_goods_callback(game, rt, { goods_id = "goods_123", role = { get_roleid = function() return 5 end } })
    end)

    _assert_eq(purchase_called, true, "on_purchase should be called")
  end)

  it("eggy_paid_gateway_callback_success_without_on_purchase", function()
    local gateway = require("src.host.paid_purchase_gateway")
    local mock_player = { id = 99 }
    local mock_entry = { product_id = 1001, name = "Test Item" }
    local game = {
      players = { mock_player },
      find_player_by_id = function()
        return mock_player
      end,
    }
    local rt = gateway._runtime(game)
    gateway._push_pending(rt, 5, { player_id = 99, product_id = 1001, goods_id = "goods_123" })

    with_patches({
      {
        target = require("src.rules.market.query.context"),
        key = "entry_by_id",
        value = function(id)
          if id == 1001 then return mock_entry end
          return nil
        end,
      },
    }, function()
      gateway._on_purchase_goods_callback(game, rt, { goods_id = "goods_123", role = { get_roleid = function() return 5 end } })
    end)

    -- No error means success - on_purchase is optional
  end)

  it("eggy_paid_gateway_start_missing_purchase_api", function()
    local gateway = require("src.host.paid_purchase_gateway")
    local game = {
      players = {
        { id = 1 },
      },
    }
    local entry = {
      product_id = 2009,
      name = "强征卡",
      currency = "金豆",
      market_enabled = true,
    }

    with_patches({
      {
        key = "GameAPI",
        value = {
          get_goods_list = function()
            return {
              { name = "强征卡", goods_id = "goods_strong_card" },
            }
          end,
        },
      },
      {
        target = require("src.foundation.ports.runtime_ports"),
        key = "resolve_role",
        value = function()
          return {
            get_roleid = function()
              return 1
            end,
          }
        end,
      },
    }, function()
      local ok, reason = gateway.start(game, game.players[1], entry)
      _assert_eq(ok, false, "start should reject when purchase api is missing")
      _assert_eq(reason, "purchase_api_missing", "start should return explicit missing api reason")
    end)
  end)
end)
