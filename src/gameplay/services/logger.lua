local logger = {
  entries = {},
  max_entries = 200,
}

local function stringify(...)
  local parts = {}
  for i = 1, select("#", ...) do
    parts[i] = tostring(select(i, ...))
  end
  return table.concat(parts, " ")
end

local function push(level, ...)
  local text = stringify(...)
  table.insert(logger.entries, {
    level = level,
    text = text,
    timestamp = os.time(),
  })
  if #logger.entries > logger.max_entries then
    table.remove(logger.entries, 1)
  end
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
end

function logger.set_max_entries(count)
  logger.max_entries = math.max(10, tonumber(count) or logger.max_entries)
end

return logger
