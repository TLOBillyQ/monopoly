-- The worker never launches bootstrap discovery against its protocol stdin.
local interpreter = os.getenv("ACCEPTANCE_LUA_BIN") or os.getenv("LUA54_BIN") or arg[-1]
assert(interpreter and _VERSION == "Lua 5.4", "worker requires Lua 5.4")
local source = debug.getinfo(1, "S").source:gsub("^@", ""):gsub("\\", "/")
local bootstrap = dofile(assert(source:match("^(.*)/[^/]+$")) .. "/../../foundation/bootstrap.lua")
local env = bootstrap.install(source)
local json = require("acceptance4lua.json")
local run_all = require("packages.acceptance.run_all")
local path = require("foundation.path")
for line in io.lines() do
  if line ~= "" then
  local id = ""
  local started = os.clock()
  local ok, response = xpcall(function()
    local job = json.decode(line)
    assert(type(job) == "table", "job must be an object")
    id = job.id or ""
    assert(type(job.generated_dir) == "string" and job.generated_dir ~= "", "missing generated_dir")
    assert(type(job.feature_json) == "string" and job.feature_json ~= "", "missing feature_json")
    local result = require("foundation.proc").run_command(run_all.command(
      path.join_path(job.generated_dir, "test_feature_acceptance.lua"), job.feature_json, interpreter), { cwd = env.repo_root, stdin_path = "NUL" })
    return run_all.decode_result(result)
  end, debug.traceback)
  if not ok then response = { outcome = "infrastructure_error", error = tostring(response), output = "" } end
  response.id, response.duration = id, os.clock() - started
  io.write(json.encode_compact(response), "\n")
  io.flush()
  end
end
