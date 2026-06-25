local M = {}

local _package_paths_installed = false

local function _normalize_path(path)
  return tostring(path or ""):gsub("\\", "/")
end

local function _module_dir()
  local source = debug.getinfo(1, "S").source or "@spec/bootstrap.lua"
  local normalized = _normalize_path(source):gsub("^@", "")
  return normalized:match("^(.*)/[^/]+$") or "spec"
end

function M.install_package_paths()
  if _package_paths_installed then
    return
  end

  local runtime_paths = dofile(_module_dir() .. "/../tools/shared/runtime_paths.lua")
  local env = runtime_paths.resolve({ source_path = debug.getinfo(1, "S").source })
  dofile(runtime_paths.join_path(env.tools_dir, "shared/package_path_helper.lua")).install_monopoly_package_paths({
    repo_root = env.repo_root,
  })
  require("shared.tool_cache").install_locked_tool_paths(env)

  _package_paths_installed = true
end

function M.ensure_tool(name)
  M.install_package_paths()
  local runtime_paths = dofile(_module_dir() .. "/../tools/shared/runtime_paths.lua")
  local env = runtime_paths.resolve({ source_path = debug.getinfo(1, "S").source })
  return require("shared.tool_cache").ensure_tool(name, env)
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
