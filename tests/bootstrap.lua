local M = {}

local _package_paths_installed = false

function M.install_package_paths()
  if _package_paths_installed then
    return
  end

  require("scripts.shared.package_path_helper").install_monopoly_package_paths({ repo_root = "." })

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
