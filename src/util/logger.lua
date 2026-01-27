local logger = {
  entries = {},
  max_entries = 200,
  file_path = "game.log",
  enable_file_io = false,
  adapter = nil,
}

local function stringify(...)
  local parts = {}
  for i = 1, select("#", ...) do
    parts[i] = tostring(select(i, ...))
  end
  return table.concat(parts, " ")
end

local function append_to_file(level, text, timestamp)
  if not logger.file_path then
    return
  end
  local file = io.open(logger.file_path, "a")
  if not file then
    return
  end
  local prefix = os.date("%Y-%m-%d %H:%M:%S", timestamp or os.time())
  file:write("[" .. prefix .. "][" .. level .. "] " .. text .. "\n")
  file:close()
end

local function push(level, ...)
  local text = stringify(...)
  local timestamp = os.time()
  local entry = {
    level = level,
    text = text,
    timestamp = timestamp,
  }
  table.insert(logger.entries, entry)
  if #logger.entries > logger.max_entries then
    table.remove(logger.entries, 1)
  end
  if logger.enable_file_io then
    append_to_file(level, text, timestamp)
  end
  local adapter = logger.adapter
  if adapter and adapter.on_log then
    local allow = adapter.level
    local should_call = false
    if allow == nil then
      should_call = true
    elseif type(allow) == "table" then
      for _, value in ipairs(allow) do
        if value == entry.level then
          should_call = true
          break
        end
      end
    else
      should_call = allow == entry.level
    end
    if should_call then
      local ok, err = pcall(adapter.on_log, entry)
      if not ok then
        io.stderr:write("[logger] adapter error: " .. tostring(err) .. "\n")
      end
    end
  end
end

function logger.set_adapter(adapter)
  logger.adapter = adapter
end

function logger.set_file_io_enabled(enabled)
  logger.enable_file_io = enabled == true
end

function logger.info(...)
  push("info", ...)
end

function logger.warn(...)
  push("warn", ...)
end

function logger.event(...)
  push("event", ...)
end

function logger.clear()
  logger.entries = {}
  if logger.enable_file_io and logger.file_path then
    local file = io.open(logger.file_path, "w")
    if file then
      file:write("-- session start " .. os.date("%Y-%m-%d %H:%M:%S") .. " --\n")
      file:close()
    end
  end
end

return logger
