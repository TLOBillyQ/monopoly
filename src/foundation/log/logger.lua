local tip_queue = require("src.foundation.coordination.tip_queue")
local log_formatter = require("src.foundation.log.formatter")

local logger = {
  entries = {},
  max_entries = 200,
  seq = 0,
  event_seq = 0,
  info_per_turn_limit = nil,
  info_turn_provider = nil,
  info_turn = nil,
  info_turn_count = 0,
  timestamp_provider = function()
    return 0
  end,
  time_formatter = function(timestamp)
    return tostring(timestamp)
  end,
  anim_debug_enabled_provider = nil,
  test_mode = false,
  enabled = true,
}

function logger.set_enabled(b)
  logger.enabled = b and true or false
end

function logger.set_timestamp_provider(provider)
  logger.timestamp_provider = provider
end

function logger.set_time_formatter(formatter)
  logger.time_formatter = formatter
end

function logger.reset_time_runtime()
  logger.set_timestamp_provider(function()
    return 0
  end)
  logger.set_time_formatter(function(timestamp)
    return tostring(timestamp)
  end)
end

function logger.set_anim_debug_enabled_provider(provider)
  if provider ~= nil then
    assert(type(provider) == "function", "anim debug provider must be function or nil")
  end
  logger.anim_debug_enabled_provider = provider
end

function logger.set_test_mode(enabled)
  logger.test_mode = enabled == true
  tip_queue.configure_runtime({
    test_mode = logger.test_mode,
  })
end

function logger.is_test_mode()
  return logger.test_mode == true
end

function logger.is_anim_debug_enabled()
  local provider = logger.anim_debug_enabled_provider
  if type(provider) ~= "function" then
    return false
  end
  local ok, enabled = pcall(provider)
  if not ok then
    return false
  end
  return enabled == true
end

function logger.configure_game_time(game_api)
  assert(game_api ~= nil, "missing game api")
  logger.set_timestamp_provider(function()
    return game_api.get_timestamp()
  end)

  local function _pad2(value)
    if value < 10 then
      return "0" .. tostring(value)
    end
    return tostring(value)
  end

  logger.set_time_formatter(function(timestamp)
    assert(timestamp ~= nil, "missing timestamp")
    local hour = game_api.get_hour(timestamp)
    local minute = game_api.get_minute(timestamp)
    local second = game_api.get_second(timestamp)
    return _pad2(hour) .. ":" .. _pad2(minute) .. ":" .. _pad2(second)
  end)
end

function logger.set_file_io_enabled(enabled)
  logger.enable_file_io = enabled == true
end

function logger.set_info_per_turn_limit(limit)
  logger.info_per_turn_limit = limit
end

function logger.set_info_turn_provider(provider)
  logger.info_turn_provider = provider
end

function logger.set_ui_sink(sink)
  logger.ui_sink = sink
end

function logger.info(...)
  if not logger.enabled then
    return
  end
  log_formatter.push(logger, "info", nil, ...)
end

function logger.info_unlimited(...)
  if not logger.enabled then
    return
  end
  log_formatter.push(logger, "info", { unlimited = true }, ...)
end

function logger.warn(...)
  if not logger.enabled then
    return
  end
  log_formatter.push(logger, "warn", nil, ...)
end

function logger.clear()
  logger.entries = {}
  logger.seq = logger.seq + 1
  logger.event_seq = (logger.event_seq or 0) + 1
  logger.info_turn = nil
  logger.info_turn_count = 0
end

function logger.get_seq()
  return logger.seq
end

function logger.get_event_seq()
  return logger.event_seq or 0
end

function logger.get_entries(max_lines)
  return log_formatter.get_entries(logger, max_lines)
end

function logger.get_entries_by_level(level, max_lines)
  return log_formatter.get_entries_by_level(logger, level, max_lines)
end

function logger.get_text(max_lines)
  return log_formatter.get_text(logger, max_lines)
end

return logger
