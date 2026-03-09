local M = {}

local _package_paths_installed = false

local function _append_path(path_pattern)
  if not tostring(package.path):find(path_pattern, 1, true) then
    package.path = package.path .. ";" .. path_pattern
  end
end

function M.install_package_paths()
  if _package_paths_installed then
    return
  end

  _append_path("./?/init.lua")
  _append_path("./tests/?.lua")
  _append_path("./tests/?/init.lua")
  _append_path("./tests/suites/?.lua")
  _append_path("./tests/fixtures/?.lua")
  _append_path("./scripts/architecture/?.lua")
  _append_path("./scripts/architecture/?/?.lua")

  -- Keep legacy lookup paths for compatibility while the migration is in flight.
  _append_path("./.agents/tests/?.lua")
  _append_path("./.agents/tests/suites/?.lua")
  _append_path("./.agents/tests/fixtures/?.lua")

  _package_paths_installed = true
end

function M.dofile_first(paths)
  for _, path in ipairs(paths or {}) do
    local file = io.open(path, "r")
    if file then
      file:close()
      return dofile(path)
    end
  end
  error("missing script: " .. table.concat(paths or {}, ", "))
end

function M.load_modules(module_names)
  local modules = {}
  for _, module_name in ipairs(module_names or {}) do
    modules[#modules + 1] = require(module_name)
  end
  return modules
end

M.install_package_paths()

return M
