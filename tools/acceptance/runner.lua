local bootstrap = dofile((debug.getinfo(1, "S").source:gsub("^@", "")):match("^(.*)/[^/]+$") .. "/../shared/bootstrap.lua")
local env = bootstrap.install(debug.getinfo(1, "S").source)
local common = require("shared.lib.common")

local runner = {}

function runner.run_generated(path)
  local start_time = os.clock()
  local result = common.run_command({
    "busted",
    "--helper=spec/helper.lua",
    "--output=TAP",
    path,
  }, {
    cwd = env.repo_root,
  })

  local output = result.output or ""
  local infrastructure_error = ""
  if result.code == 127 or output:find("not found", 1, true) ~= nil then
    infrastructure_error = output
  end

  return {
    passed = result.ok == true,
    output = output,
    error = infrastructure_error,
    duration = os.clock() - start_time,
  }
end

return runner
