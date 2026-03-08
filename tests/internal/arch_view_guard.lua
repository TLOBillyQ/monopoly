package.path = package.path .. ";./scripts/architecture/?.lua;./scripts/architecture/?/?.lua"

local build = require("arch_view.build")
local config = require("monopoly_architecture")

local architecture, err = build.analyze(config)
if architecture == nil then
  io.stderr:write("arch_view_guard error: ", tostring(err), "\n")
  os.exit(1)
end

if architecture.views == nil or architecture.views.root == nil then
  io.stderr:write("arch_view_guard error: missing root view\n")
  os.exit(1)
end

if architecture.check == nil or architecture.check.ok ~= true then
  io.stderr:write("arch_view_guard failed\n")
  for _, violation in ipairs((architecture.check and architecture.check.violations) or {}) do
    if violation.kind == "forbidden_dependency" then
      io.stderr:write(
        "arch_view_guard: forbidden_dependency [",
        tostring(violation.rule),
        "] ",
        tostring(violation.from),
        " -> ",
        tostring(violation.to),
        "\n"
      )
    elseif violation.kind == "unclassified_module" then
      io.stderr:write("arch_view_guard: unclassified_module ", tostring(violation.module_id), "\n")
    else
      io.stderr:write("arch_view_guard: ", tostring(violation.kind), "\n")
    end
  end
  os.exit(1)
end

print("arch_view_guard ok")
