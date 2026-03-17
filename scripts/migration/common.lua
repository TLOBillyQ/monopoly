local package_path_helper = dofile("scripts/shared/package_path_helper.lua")
package_path_helper.install_monopoly_package_paths({ repo_root = "." })

local migration_map = require("support.migration_map")

local M = {}

local function list_files(roots)
  local files = {}
  local seen = {}
  for _, root in ipairs(roots or {}) do
    local process = io.popen('find "' .. tostring(root) .. '" -type f 2>/dev/null')
    if process ~= nil then
      for line in process:lines() do
        if line ~= "" and not seen[line] then
          seen[line] = true
          files[#files + 1] = line
        end
      end
      process:close()
    end
  end
  table.sort(files)
  return files
end

function M.parse_args(args)
  local opts = {
    dry_run = true,
    write = false,
  }

  for _, token in ipairs(args or {}) do
    if token == "--write" then
      opts.write = true
      opts.dry_run = false
    elseif token == "--dry-run" then
      opts.dry_run = true
    else
      error("unknown flag: " .. tostring(token))
    end
  end

  return opts
end

function M.iter_entries()
  return migration_map.iter_entries()
end

function M.list_repo_files()
  return list_files({ "src", "tests", "scripts", "docs", ".agents" })
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

function M.write_file(path, text)
  local file = assert(io.open(path, "w"))
  file:write(text)
  file:close()
end

return M
