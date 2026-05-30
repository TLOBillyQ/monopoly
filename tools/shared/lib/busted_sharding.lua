local common = require("shared.lib.common")
local number_utils = require("src.foundation.number")

local M = {}

local function _file_has_it(path)
  local f = io.open(path, "r")
  if f == nil then
    return false
  end
  for line in f:lines() do
    if line:find("it(", 1, true) then
      f:close()
      return true
    end
  end
  f:close()
  return false
end

function M.discover_spec_files(root)
  if root == nil or root == "" then
    return {}
  end
  local command = "find " .. common.shell_quote(root) .. " -name '*_spec.lua' -type f 2>/dev/null"
  local handle = io.popen(command)
  if handle == nil then
    return {}
  end
  local files = {}
  for line in handle:lines() do
    local trimmed = line:match("^%s*(.-)%s*$")
    if trimmed ~= nil and trimmed ~= "" and _file_has_it(trimmed) then
      files[#files + 1] = trimmed
    end
  end
  handle:close()
  table.sort(files)
  return files
end

function M.file_cost(path)
  local f = io.open(path, "r")
  if f == nil then
    return 1
  end
  local count = 0
  for line in f:lines() do
    if line:find("it(", 1, true) then
      count = count + 1
    end
  end
  f:close()
  return math.max(1, count)
end

local function _ranked_entries(files)
  local ranked = {}
  for index, path in ipairs(files) do
    ranked[#ranked + 1] = {
      path = path,
      cost = M.file_cost(path),
      index = index,
    }
  end
  table.sort(ranked, function(left, right)
    if left.cost ~= right.cost then
      return left.cost > right.cost
    end
    return left.index < right.index
  end)
  return ranked
end

function M.build_lpt_lanes(files, worker_count)
  local clamped = math.max(1, math.min(worker_count or 1, math.max(1, #files)))
  local lanes = {}
  for i = 1, clamped do
    lanes[i] = { index = i, total_cost = 0, files = {} }
  end
  for _, entry in ipairs(_ranked_entries(files)) do
    local target = lanes[1]
    for i = 2, #lanes do
      if lanes[i].total_cost < target.total_cost then
        target = lanes[i]
      elseif lanes[i].total_cost == target.total_cost and lanes[i].index < target.index then
        target = lanes[i]
      end
    end
    target.total_cost = target.total_cost + entry.cost
    target.files[#target.files + 1] = entry.path
  end
  return lanes
end

function M.resolve_workers(env_var_name, file_count, default_workers)
  local capacity = math.max(1, file_count or 0)
  local resolved = default_workers or 1
  if env_var_name ~= nil then
    local env_val = os.getenv(env_var_name)
    if env_val ~= nil and env_val ~= "" then
      local parsed = number_utils.to_integer(env_val)
      if parsed ~= nil and parsed >= 1 then
        resolved = parsed
      end
    end
  end
  if resolved < 1 then
    resolved = 1
  end
  if resolved > capacity then
    resolved = capacity
  end
  return resolved
end

return M
