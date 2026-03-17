local migration_map = require("support.migration_map")

local M = {}

local function clone_entry(entry)
  local copy = {}
  for key, value in pairs(entry or {}) do
    if type(value) == "table" then
      local list = {}
      for index, item in ipairs(value) do
        list[index] = item
      end
      copy[key] = list
    else
      copy[key] = value
    end
  end
  return copy
end

function M.file_exists(path)
  local file = io.open(path, "r")
  if not file then
    return false
  end
  file:close()
  return true
end

function M.read_file(path)
  local file = io.open(path, "r")
  if not file then
    return nil
  end
  local text = file:read("*a")
  file:close()
  return text
end

function M.iter_pairs(opts)
  opts = opts or {}
  local pairs = {}

  for _, entry in ipairs(migration_map.iter_entries()) do
    if entry.keep_shim ~= false then
      local include = true
      if opts.only_existing == true then
        include = M.file_exists(entry.old_path) or M.file_exists(entry.new_path)
      end
      if include then
        pairs[#pairs + 1] = clone_entry(entry)
      end
    end
  end

  table.sort(pairs, function(left, right)
    return left.old_path < right.old_path
  end)

  return pairs
end

return M
