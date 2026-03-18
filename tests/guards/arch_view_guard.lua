require("tests.bootstrap").install_package_paths()

local arch_view = require("arch_view")

local function _load_first(module_names)
  local errors = {}
  for _, module_name in ipairs(module_names or {}) do
    local ok, loaded = pcall(require, module_name)
    if ok then
      return loaded
    end
    errors[#errors + 1] = tostring(loaded)
  end
  error(table.concat(errors, "\n"))
end

local function _path_exists(path)
  local file = io.open(path, "r")
  if file then
    file:close()
    return true
  end
  local ok = os.rename(path, path)
  return ok == true
end

local function _first_existing(paths)
  for _, path in ipairs(paths or {}) do
    if _path_exists(path) then
      return path
    end
  end
  return paths and paths[1] or nil
end

local arch_filter = _load_first({ "quality.arch.filter", "scripts.quality.arch.filter" })
local arch_config_path = _first_existing({
  "tools/quality/arch/config.json",
  "scripts/quality/arch/config.json",
})

local M = {}

function M.run()
  local architecture, err = arch_view.analyze({
    project_root = ".",
    config_path = arch_config_path,
  })
  if architecture == nil then
    return { ok = false, error = "arch_view_guard error: " .. tostring(err) }
  end

  arch_filter.apply(architecture)

  if architecture.views == nil or architecture.views.root == nil then
    return { ok = false, error = "arch_view_guard error: missing root view" }
  end

  if architecture.check == nil or architecture.check.ok ~= true then
    local lines = { "arch_view_guard failed" }
    for _, violation in ipairs((architecture.check and architecture.check.violations) or {}) do
      if violation.kind == "forbidden_dependency" then
        lines[#lines + 1] = "arch_view_guard: forbidden_dependency [" .. tostring(violation.rule) .. "] "
          .. tostring(violation.from) .. " -> " .. tostring(violation.to)
      elseif violation.kind == "unclassified_module" then
        lines[#lines + 1] = "arch_view_guard: unclassified_module " .. tostring(violation.module_id)
      elseif violation.kind == "projection_cycle" then
        lines[#lines + 1] = "arch_view_guard: projection_cycle " .. tostring(violation.view)
      else
        lines[#lines + 1] = "arch_view_guard: " .. tostring(violation.kind)
      end
    end
    return { ok = false, error = table.concat(lines, "\n") }
  end

  return { ok = true, message = "arch_view_guard ok" }
end

function M.main()
  local result = M.run()
  if not result.ok then
    io.stderr:write(result.error, "\n")
    os.exit(1)
  end
  print(result.message)
end

if ... == nil then
  M.main()
else
  return M
end
