local support = require("support.runtime_support")
local _assert_eq = support.assert_eq
local with_patches = support.with_patches
local number_utils = support.number_utils
local logger = require("src.core.utils.logger")

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
    { name = "ui_bootstrap_required_click_nodes_appends_extras", run = _test_ui_bootstrap_required_click_nodes_appends_extras },
  },
}
