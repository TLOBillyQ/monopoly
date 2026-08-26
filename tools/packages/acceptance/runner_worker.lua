local bootstrap = dofile((debug.getinfo(1, "S").source:gsub("^@", "")):match("^(.*)/[^/]+$") .. "/../../foundation/bootstrap.lua")
local env = bootstrap.install(debug.getinfo(1, "S").source)
local acceptance_tool = assert(bootstrap.ensure_tool("acceptance4lua", env))

local path_lib = require("foundation.path")
local json = require("acceptance4lua.json")
local runner = require("acceptance4lua.runner")
local spawn_env = require("packages.acceptance.spawn_env")

local runner_opts = spawn_env.runner_opts(env, acceptance_tool)

local function _response_for_job(job)
  local generated_path = path_lib.join_path(job.generated_dir, "test_feature_acceptance.lua")
  local opts = { feature_json = job.feature_json, cwd = env.repo_root }
  for key, value in pairs(runner_opts) do opts[key] = value end
  local result = runner.run_generated(generated_path, opts)

  local outcome = "infrastructure_error"
  local error_text = result.error or ""
  if error_text == "" then
    outcome = result.passed and "test_success" or "test_failure"
  end

  return {
    id = job.id,
    outcome = outcome,
    output = result.output or "",
    error = error_text,
    duration = result.duration or 0,
  }
end

for line in io.lines() do
  if line ~= "" then
    local ok, job = pcall(json.decode, line)
    local response
    if ok then
      response = _response_for_job(job)
    else
      response = {
        id = "",
        outcome = "infrastructure_error",
        output = "",
        error = tostring(job),
        duration = 0,
      }
    end
    io.write(json.encode_compact(response), "\n")
    io.flush()
  end
end
