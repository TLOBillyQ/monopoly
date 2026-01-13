local logger = {
  entries = {},
  max_entries = 200,
  file_path = "runtime.log",
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
  table.insert(logger.entries, {
    level = level,
    text = text,
    timestamp = timestamp,
  })
  if #logger.entries > logger.max_entries then
    table.remove(logger.entries, 1)
  end
  append_to_file(level, text, timestamp)
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
  if logger.file_path then
    local file = io.open(logger.file_path, "w")
    if file then
      file:write("-- session start " .. os.date("%Y-%m-%d %H:%M:%S") .. " --\n")
      file:close()
    end
  end
end

function logger.set_max_entries(count)
  logger.max_entries = math.max(10, tonumber(count) or logger.max_entries)
end

return logger
