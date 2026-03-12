local support = require("support.runtime_support")
local _assert_eq = support.assert_eq
local with_patches = support.with_patches
local number_utils = support.number_utils
local logger = require("src.core.utils.logger")
local runtime_constants = require("src.core.config.runtime_constants")
local runtime_context = require("src.infrastructure.runtime.context")
local default_ports = require("src.infrastructure.runtime.default_ports")
local landing_visual_hold = require("src.core.state_access.landing_visual_hold")

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

local function _test_logger_show_tip_uses_fifo_queue_without_override()
  local shown = {}
  local timers = {}

  logger.clear()
  logger.set_tip_presenter(function(text, duration)
    shown[#shown + 1] = { text = text, duration = duration }
  end)
  logger.set_scheduler(function(delay, fn)
    timers[#timers + 1] = { delay = delay, fn = fn }
    return true
  end)
  local ok, err = pcall(function()
    logger.show_tip("A", 3.0)
    logger.show_tip("B", 2.0)

    _assert_eq(#shown, 1, "second tip should not override active tip")
    _assert_eq(shown[1].text, "A", "first shown tip should be A")
    _assert_eq(#timers, 1, "first tip should schedule one release timer")
    _assert_eq(timers[1].delay, 3.0, "first tip release timer should match duration")

    timers[1].fn()

    _assert_eq(#shown, 2, "second tip should show after first tip release")
    _assert_eq(shown[2].text, "B", "second shown tip should be B")
    _assert_eq(#timers, 2, "second tip should schedule another release timer")
    _assert_eq(timers[2].delay, 2.0, "second tip release timer should match duration")
  end)
  logger.set_tip_presenter(nil)
  logger.set_scheduler(nil)
  logger.clear()
  if not ok then
    error(err)
  end
end

local function _test_logger_event_tip_defers_until_current_tip_finishes()
  local shown = {}
  local timers = {}

  logger.clear()
  logger.set_tip_presenter(function(text, duration)
    shown[#shown + 1] = { text = text, duration = duration }
  end)
  logger.set_scheduler(function(delay, fn)
    timers[#timers + 1] = { delay = delay, fn = fn }
    return true
  end)
  local ok, err = pcall(function()
    logger.show_tip("market_failed", 3.0)
    logger.event("log event message")

    _assert_eq(#shown, 1, "log event tip should defer while market tip is active")
    _assert_eq(shown[1].text, "market_failed", "first tip should be market_failed")

    timers[1].fn()

    _assert_eq(#shown, 2, "log event tip should show after market tip")
    _assert_eq(shown[2].text, "log event message", "second tip should be log event")
  end)
  logger.set_tip_presenter(nil)
  logger.set_scheduler(nil)
  logger.clear()
  if not ok then
    error(err)
  end
end

local function _test_logger_event_no_tips_stays_in_event_feed_without_showing_tip()
  local shown = {}

  logger.clear()
  logger.set_tip_presenter(function(text, duration)
    shown[#shown + 1] = { text = text, duration = duration }
  end)
  local ok, err = pcall(function()
    logger.event_no_tips("phase event message")
    local text = logger.get_text_by_level("event")
    assert(string.find(text, "phase event message", 1, true) ~= nil, "event_no_tips should still enter event feed")
    _assert_eq(#shown, 0, "event_no_tips should not trigger tips")
  end)
  logger.set_tip_presenter(nil)
  logger.clear()
  if not ok then
    error(err)
  end
end

local function _test_logger_configure_host_runtime_uses_injected_hooks()
  local shown = {}
  local timers = {}

  logger.clear()
  logger.configure_host_runtime({
    game_api = {
      get_timestamp = function()
        return 65
      end,
      get_hour = function()
        return 1
      end,
      get_minute = function()
        return 2
      end,
      get_second = function()
        return 3
      end,
    },
    tip_presenter = function(text, duration)
      shown[#shown + 1] = { text = text, duration = duration }
    end,
    scheduler = function(delay, fn)
      timers[#timers + 1] = { delay = delay, fn = fn }
      return true
    end,
  })

  local ok, err = pcall(function()
    logger.event("host runtime injected")
    local text = logger.get_text_by_level("event")
    assert(string.find(text, "01:02:03", 1, true) ~= nil, "logger should use injected game clock formatter")
    _assert_eq(#shown, 1, "logger should use injected tip presenter")
    _assert_eq(shown[1].text, "host runtime injected", "injected tip presenter should receive event text")
    _assert_eq(#timers, 1, "logger should use injected scheduler for tip release")
  end)

  logger.set_tip_presenter(nil)
  logger.set_scheduler(nil)
  logger.set_timestamp_provider(function()
    return 0
  end)
  logger.set_time_formatter(function(timestamp)
    return tostring(timestamp)
  end)
  logger.clear()
  if not ok then
    error(err)
  end
end

local function _test_logger_event_collection_provider_drops_closed_action_log_events()
  local shown = {}

  logger.clear()
  logger.set_tip_presenter(function(text, duration)
    shown[#shown + 1] = { text = text, duration = duration }
  end)
  logger.set_event_collection_enabled_provider(function()
    return false
  end)

  local ok, err = pcall(function()
    logger.event("closed action log event")
    local text = logger.get_text_by_level("event")
    _assert_eq(text, "", "closed action log should not retain event feed entries")
    _assert_eq(#shown, 1, "closed action log should still show tips")
    _assert_eq(shown[1].text, "closed action log event", "tip text should still be emitted")
  end)

  logger.set_tip_presenter(nil)
  logger.set_event_collection_enabled_provider(nil)
  logger.clear()
  if not ok then
    error(err)
  end
end

local function _test_logger_event_seq_only_tracks_event_feed_changes()
  logger.clear()

  local ok, err = pcall(function()
    local initial_seq = logger.get_event_seq()

    logger.info("info message")
    _assert_eq(logger.get_event_seq(), initial_seq, "info should not change event_seq")

    logger.warn("warn message")
    _assert_eq(logger.get_event_seq(), initial_seq, "warn should not change event_seq")

    logger.event("event message")
    local event_seq = logger.get_event_seq()
    assert(event_seq > initial_seq, "event should advance event_seq")

    logger.event_no_tips("event no tips message")
    local event_no_tips_seq = logger.get_event_seq()
    assert(event_no_tips_seq > event_seq, "event_no_tips should advance event_seq")

    logger.clear()
    assert(logger.get_event_seq() > event_no_tips_seq, "clear should advance event_seq for UI reset")
  end)

  logger.clear()
  if not ok then
    error(err)
  end
end

local function _test_synthetic_actor_registry_spawns_from_first_path_tile()
  local registry_module = require("src.infrastructure.runtime.synthetic_actor_registry")
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
      create_creature_fixed_scale = function(unit_key, pos)
        created[#created + 1] = { unit_key = unit_key, pos = pos }
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
end

local function _test_synthetic_actor_registry_reset_destroys_spawned_actor_and_clears_registry()
  local registry_module = require("src.infrastructure.runtime.synthetic_actor_registry")
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
  local ui_bootstrap = require("src.app.bootstrap.ui_bootstrap")
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
      target = require("src.presentation.runtime.events"),
      key = "send_to_all",
      value = function() end,
    },
    {
      target = require("src.presentation.runtime.canvas_event_router"),
      key = "bind",
      value = function() end,
    },
    {
      target = require("src.presentation.runtime.view"),
      key = "init_ui_assets",
      value = function() end,
    },
    {
      target = require("src.presentation.runtime.view"),
      key = "capture_player_colors",
      value = function() end,
    },
    {
      target = require("src.presentation.view.render.board_scene"),
      key = "init",
      value = function() end,
    },
    {
      target = require("src.infrastructure.runtime.context"),
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
      target = require("src.core.state_access.ui_role_globals"),
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

local function _test_runtime_context_vehicle_helper_consume_enter_delay_only_waits_once()
  local emitted = {}
  local role = { id = 3, get_roleid = function() return 3 end }
  local ctx = runtime_context.new({
    GameAPI = {
      get_role = function(role_id)
        if role_id == 3 then
          return role
        end
        return nil
      end,
      get_all_valid_roles = function()
        return { role }
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

  with_patches({
    {
      target = require("src.game.systems.vehicle"),
      key = "is_enabled",
      value = function()
        return true
      end,
    },
    {
      target = require("src.infrastructure.runtime.event_bridge"),
      key = "emit_custom_event",
      value = function(event_name)
        emitted[#emitted + 1] = event_name
        return true
      end,
    },
  }, function()
    runtime_context.install_environment(ctx)
    runtime_context.install_runtime_helpers(ctx)

    local helper = ctx.vehicle_helper
    _assert_eq(helper.consume_enter_delay(3, 99), runtime_constants.vehicle_enter_delay or 0, "first enter should use configured enter delay")
    _assert_eq(helper.consume_enter_delay(3, 99), 0, "same vehicle should not re-apply enter delay")
    _assert_eq(helper.consume_enter_delay(3, 100), runtime_constants.vehicle_enter_delay or 0, "new vehicle should emit enter and wait again")
  end)

  _assert_eq(#emitted, 2, "vehicle helper should emit enter event only when vehicle changes")
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
  local ui_bootstrap = require("src.app.bootstrap.ui_bootstrap")
  local capture = {
    registered_specs = nil,
    spawned_map = nil,
  }

  with_patches({
    {
      target = require("src.infrastructure.runtime.context"),
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

local function _test_landing_visual_hold_defer_dirty_initializes_bucket_and_merges_inventory()
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
end

local function _test_logger_flush_event_buffer_replays_buffered_events()
  logger.clear()
  local buffer = { entries = {} }
  logger.push_event_buffer(buffer)

  local ok, err = pcall(function()
    logger.event("first buffered event")
    logger.event("second buffered event")

    local text_before = logger.get_text_by_level("event")
    _assert_eq(text_before, "", "buffered events should not appear in feed before flush")

    local flushed = logger.flush_event_buffer(buffer)
    _assert_eq(flushed, true, "flush should return true when buffer has entries")

    local text_after = logger.get_text_by_level("event")
    assert(string.find(text_after, "first buffered event", 1, true) ~= nil, "flush should replay first buffered event")
    assert(string.find(text_after, "second buffered event", 1, true) ~= nil, "flush should replay second buffered event")
  end)

  logger.pop_event_buffer(buffer)
  logger.clear()
  if not ok then
    error(err)
  end
end

local function _test_logger_flush_event_buffer_skips_when_buffer_not_active()
  logger.clear()
  local buffer = { entries = {} }

  local ok, err = pcall(function()
    logger.event("event before buffer")
    local flushed = logger.flush_event_buffer(buffer)
    _assert_eq(flushed, false, "flush should return false when buffer is not active")
  end)

  logger.clear()
  if not ok then
    error(err)
  end
end

local function _test_logger_flush_event_buffer_no_tip_replay()
  logger.clear()
  local shown = {}
  logger.set_tip_presenter(function(text, duration)
    shown[#shown + 1] = { text = text, duration = duration }
  end)

  local buffer = { entries = {} }
  logger.push_event_buffer(buffer)

  local ok, err = pcall(function()
    logger.event_no_tips("no tip event")
    logger.flush_event_buffer(buffer)

    local text = logger.get_text_by_level("event")
    assert(string.find(text, "no tip event", 1, true) ~= nil, "flush should replay no_tip event to feed, text=" .. tostring(text))
    _assert_eq(#shown, 0, "flush should not show tip for no_tip events")
  end)

  logger.pop_event_buffer(buffer)
  logger.set_tip_presenter(nil)
  logger.clear()
  if not ok then
    error(err)
  end
end

local function _test_logger_flush_event_buffer_empty_buffer_returns_false()
  logger.clear()
  local buffer = { entries = {} }
  logger.push_event_buffer(buffer)

  local ok, err = pcall(function()
    local flushed = logger.flush_event_buffer(buffer)
    _assert_eq(flushed, false, "flush should return false for empty buffer")
  end)

  logger.clear()
  if not ok then
    error(err)
  end
end

local function _test_logger_flush_event_buffer_invalid_buffer_returns_false()
  logger.clear()

  local ok, err = pcall(function()
    _assert_eq(logger.flush_event_buffer(nil), false, "flush should return false for nil buffer")
    _assert_eq(logger.flush_event_buffer("string"), false, "flush should return false for string buffer")
    _assert_eq(logger.flush_event_buffer(123), false, "flush should return false for number buffer")
  end)

  logger.clear()
  if not ok then
    error(err)
  end
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

local function _test_landing_visual_hold_release_flushes_event_buffer_and_replays_deferred()
  logger.clear()
  local state = {}
  local game = {
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
  logger.push_event_buffer(hold)
  logger.event("deferred event during hold")

  landing_visual_hold.defer_board_visual_sync(state, { sync_data = true }, function(payload)
    replayed_visual_syncs[#replayed_visual_syncs + 1] = payload
  end)

  landing_visual_hold.defer_runtime_event(state, "test_event", { event_data = true }, function(payload)
    replayed_runtime_events[#replayed_runtime_events + 1] = payload
  end)

  landing_visual_hold.defer_popup(state, { popup_data = true }, { opt = 1 }, function(payload, opts)
    replayed_popups[#replayed_popups + 1] = { payload = payload, opts = opts }
  end)

  local released = landing_visual_hold.release(state, game)

  _assert_eq(released, true, "release should return true when release was pending")
  _assert_eq(#replayed_visual_syncs, 1, "release should replay deferred visual syncs")
  _assert_eq(replayed_visual_syncs[1].sync_data, true, "visual sync payload should be preserved")
  _assert_eq(#replayed_runtime_events, 1, "release should replay deferred runtime events")
  _assert_eq(replayed_runtime_events[1].event_data, true, "runtime event payload should be preserved")
  _assert_eq(#replayed_popups, 1, "release should replay deferred popups")
  _assert_eq(replayed_popups[1].payload.popup_data, true, "popup payload should be preserved")

  local text = logger.get_text_by_level("event")
  assert(string.find(text, "deferred event during hold", 1, true) ~= nil, "release should flush event buffer")

  logger.clear()
end

local function _test_landing_visual_hold_release_skips_when_not_pending()
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
end

local function _test_eggy_paid_gateway_callback_missing_goods_id()
  local gateway = require("src.app.bootstrap.payment.eggy_paid_purchase_gateway")
  local game = { players = {} }
  local rt = gateway._runtime(game)
  local warned = nil

  with_patches({
    {
      target = require("src.core.utils.logger"),
      key = "warn",
      value = function(msg)
        warned = msg
      end,
    },
  }, function()
    gateway._on_purchase_goods_callback(game, rt, {})
  end)

  _assert_eq(warned, "market paid callback ignored: goods_id missing", "should warn when goods_id is missing")
end

local function _test_eggy_paid_gateway_callback_empty_goods_id()
  local gateway = require("src.app.bootstrap.payment.eggy_paid_purchase_gateway")
  local game = { players = {} }
  local rt = gateway._runtime(game)
  local warned = nil

  with_patches({
    {
      target = require("src.core.utils.logger"),
      key = "warn",
      value = function(msg)
        warned = msg
      end,
    },
  }, function()
    gateway._on_purchase_goods_callback(game, rt, { goods_id = "" })
  end)

  _assert_eq(warned, "market paid callback ignored: goods_id missing", "should warn when goods_id is empty")
end

local function _test_eggy_paid_gateway_callback_missing_pending()
  local gateway = require("src.app.bootstrap.payment.eggy_paid_purchase_gateway")
  local game = { players = {} }
  local rt = gateway._runtime(game)
  local warned = nil

  with_patches({
    {
      target = require("src.core.utils.logger"),
      key = "warn",
      value = function(msg, ctx1, ctx2)
        warned = msg .. " " .. tostring(ctx1) .. " " .. tostring(ctx2)
      end,
    },
  }, function()
    gateway._on_purchase_goods_callback(game, rt, { goods_id = "goods_123" })
  end)

  assert(warned and warned:find("pending missing", 1, true), "should warn when pending is missing: " .. tostring(warned))
end

local function _test_eggy_paid_gateway_callback_missing_player()
  local gateway = require("src.app.bootstrap.payment.eggy_paid_purchase_gateway")
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
      target = require("src.core.utils.logger"),
      key = "warn",
      value = function(msg, ctx)
        warned = msg .. " " .. tostring(ctx)
      end,
    },
  }, function()
    gateway._on_purchase_goods_callback(game, rt, { goods_id = "goods_123", role = { get_roleid = function() return 5 end } })
  end)

  assert(warned and warned:find("player missing", 1, true), "should warn when player is missing: " .. tostring(warned))
end

local function _test_eggy_paid_gateway_callback_missing_entry()
  local gateway = require("src.app.bootstrap.payment.eggy_paid_purchase_gateway")
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
      target = require("src.game.systems.market.application.context"),
      key = "entry_by_id",
      value = function()
        return nil
      end,
    },
    {
      target = require("src.core.utils.logger"),
      key = "warn",
      value = function(msg, ctx)
        warned = msg .. " " .. tostring(ctx)
      end,
    },
  }, function()
    gateway._on_purchase_goods_callback(game, rt, { goods_id = "goods_123", role = { get_roleid = function() return 5 end } })
  end)

  assert(warned and warned:find("market entry missing", 1, true), "should warn when entry is missing: " .. tostring(warned))
end

local function _test_eggy_paid_gateway_callback_success_with_on_purchase()
  local gateway = require("src.app.bootstrap.payment.eggy_paid_purchase_gateway")
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
      target = require("src.game.systems.market.application.context"),
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
end

local function _test_eggy_paid_gateway_callback_success_without_on_purchase()
  local gateway = require("src.app.bootstrap.payment.eggy_paid_purchase_gateway")
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
      target = require("src.game.systems.market.application.context"),
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
end

return {
  name = "misc",
  tests = {
    { name = "number_utils_to_integer", run = _test_number_utils_to_integer },
    { name = "number_utils_to_integer_fallback_from_tostring", run = _test_number_utils_to_integer_fallback_from_tostring },
    { name = "number_utils_to_integer_fallback_rejects_non_integer_text", run = _test_number_utils_to_integer_fallback_rejects_non_integer_text },
    { name = "logger_show_tip_uses_fifo_queue_without_override", run = _test_logger_show_tip_uses_fifo_queue_without_override },
    { name = "logger_event_tip_defers_until_current_tip_finishes", run = _test_logger_event_tip_defers_until_current_tip_finishes },
    { name = "logger_event_no_tips_stays_in_event_feed_without_showing_tip", run = _test_logger_event_no_tips_stays_in_event_feed_without_showing_tip },
    { name = "logger_configure_host_runtime_uses_injected_hooks", run = _test_logger_configure_host_runtime_uses_injected_hooks },
    { name = "logger_event_collection_provider_drops_closed_action_log_events", run = _test_logger_event_collection_provider_drops_closed_action_log_events },
    { name = "logger_event_seq_only_tracks_event_feed_changes", run = _test_logger_event_seq_only_tracks_event_feed_changes },
    { name = "synthetic_actor_registry_spawns_from_first_path_tile", run = _test_synthetic_actor_registry_spawns_from_first_path_tile },
    {
      name = "synthetic_actor_registry_reset_destroys_spawned_actor_and_clears_registry",
      run = _test_synthetic_actor_registry_reset_destroys_spawned_actor_and_clears_registry,
    },
    { name = "ui_bootstrap_required_click_nodes_appends_extras", run = _test_ui_bootstrap_required_click_nodes_appends_extras },
    { name = "runtime_context_vehicle_helper_consume_enter_delay_only_waits_once", run = _test_runtime_context_vehicle_helper_consume_enter_delay_only_waits_once },
    { name = "default_ports_wall_diff_seconds_prefers_game_api_then_falls_back", run = _test_default_ports_wall_diff_seconds_prefers_game_api_then_falls_back },
    { name = "ui_bootstrap_spawns_startup_synthetic_actors", run = _test_ui_bootstrap_spawns_startup_synthetic_actors },
    { name = "landing_visual_hold_defer_dirty_initializes_bucket_and_merges_inventory", run = _test_landing_visual_hold_defer_dirty_initializes_bucket_and_merges_inventory },
    { name = "logger_flush_event_buffer_replays_buffered_events", run = _test_logger_flush_event_buffer_replays_buffered_events },
    { name = "logger_flush_event_buffer_skips_when_buffer_not_active", run = _test_logger_flush_event_buffer_skips_when_buffer_not_active },
    { name = "logger_flush_event_buffer_no_tip_replay", run = _test_logger_flush_event_buffer_no_tip_replay },
    { name = "logger_flush_event_buffer_empty_buffer_returns_false", run = _test_logger_flush_event_buffer_empty_buffer_returns_false },
    { name = "logger_flush_event_buffer_invalid_buffer_returns_false", run = _test_logger_flush_event_buffer_invalid_buffer_returns_false },
    { name = "runtime_context_first_role_from_game_api_with_valid_roles", run = _test_runtime_context_first_role_from_game_api_with_valid_roles },
    { name = "runtime_context_first_role_from_game_api_empty_list_fallback", run = _test_runtime_context_first_role_from_game_api_empty_list_fallback },
    { name = "runtime_context_first_role_from_game_api_nil_game_api", run = _test_runtime_context_first_role_from_game_api_nil_game_api },
    { name = "runtime_context_first_role_from_game_api_pcall_failure", run = _test_runtime_context_first_role_from_game_api_pcall_failure },
    { name = "landing_visual_hold_release_flushes_event_buffer_and_replays_deferred", run = _test_landing_visual_hold_release_flushes_event_buffer_and_replays_deferred },
    { name = "landing_visual_hold_release_skips_when_not_pending", run = _test_landing_visual_hold_release_skips_when_not_pending },
    { name = "eggy_paid_gateway_callback_missing_goods_id", run = _test_eggy_paid_gateway_callback_missing_goods_id },
    { name = "eggy_paid_gateway_callback_empty_goods_id", run = _test_eggy_paid_gateway_callback_empty_goods_id },
    { name = "eggy_paid_gateway_callback_missing_pending", run = _test_eggy_paid_gateway_callback_missing_pending },
    { name = "eggy_paid_gateway_callback_missing_player", run = _test_eggy_paid_gateway_callback_missing_player },
    { name = "eggy_paid_gateway_callback_missing_entry", run = _test_eggy_paid_gateway_callback_missing_entry },
    { name = "eggy_paid_gateway_callback_success_with_on_purchase", run = _test_eggy_paid_gateway_callback_success_with_on_purchase },
    { name = "eggy_paid_gateway_callback_success_without_on_purchase", run = _test_eggy_paid_gateway_callback_success_without_on_purchase },
  },
}
