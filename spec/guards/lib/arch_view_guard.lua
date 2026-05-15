require("spec.bootstrap").install_package_paths()

local arch_view = require("arch_view")
local guard_support = require("spec.support.guards.guard_support")

local function _first_existing(paths)
  for _, path in ipairs(paths or {}) do
    if guard_support.path_exists(path) then
      return path
    end
  end
  return paths and paths[1] or nil
end

local arch_filter = require("quality.arch.filter")
local arch_config_path = _first_existing({
  "tools/quality/arch/config.json",
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
