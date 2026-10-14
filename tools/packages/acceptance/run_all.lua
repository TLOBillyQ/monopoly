-- Manifest-selected genuine busted processes, sharing native argv/Job lanes.
local source = debug.getinfo(1, "S").source:gsub("^@", ""):gsub("\\", "/")
local bootstrap = dofile(assert(source:match("^(.*)/[^/]+$")) .. "/../../foundation/bootstrap.lua")
local env = bootstrap.install(source)
local tool = { root = env.repo_root .. "/.toolcache/luarocks" }
local path = require("foundation.path")
local json = require("acceptance4lua.json")
local proc = require("foundation.proc")
local registry = require("packages.acceptance.acceptance_features")
local spawn_env = require("packages.acceptance.spawn_env")
local M = {}

function M.command(spec, ir, interpreter, feature)
  local opts = interpreter and { lua_bin = interpreter } or spawn_env.runner_opts(env, tool)
  return { opts.lua_bin, env.repo_root .. "/tools/packages/acceptance/execute.lua", spec, ir, feature }
end

function M.decode_result(result)
  local text = tostring(result.output or "")
  local ok, response = pcall(json.decode, text)
  if not ok or type(response) ~= "table" or response.backend ~= "busted" then
    return { outcome = "infrastructure_error", error = text ~= "" and text or
      ("lua launcher failed with exit code " .. tostring(result.code or result.exit_code)), output = text }
  end
  local counts = response.counts
  if type(counts) ~= "table" or (counts.cases or 0) == 0 then
    response.outcome = "infrastructure_error"
    response.error = response.error ~= "" and response.error or "no acceptance cases executed"
  elseif result.ok ~= (response.outcome == "test_success") then
    response.outcome, response.error = "infrastructure_error", "busted exit/result disagreement"
  end
  return response
end

function M.run(options)
  options = options or {}
  local generated = options.generated_dir or registry.generated_dir
  local entries, excluded = registry.select(function(line) io.write(line, "\n") end)
  local lanes = {}
  for index, entry in ipairs(entries) do
    lanes[index] = { label = "acceptance_" .. index, cmd = M.command(path.join_path(generated, entry.generated),
      path.join_path("build/acceptance", (entry.generated:gsub("%.lua$", ".json"))), nil, entry.feature) }
  end
  local results = {}
  if options.serial then
    for index, lane in ipairs(lanes) do results[index] = proc.run_command(lane.cmd, { cwd = env.repo_root }) end
  else
    local _, parallel = require("foundation.parallel_lanes").run(lanes, { stream = false })
    results = parallel
  end
  local summary = { passed = 0, failed = {}, total = #entries, registered = #registry.entries, excluded = excluded,
    counts = { files = #entries, cases = 0, passed = 0, failed = 0, errors = 0 }, executions = {} }
  for index, entry in ipairs(entries) do
    local response = M.decode_result(results[index])
    local counts = response.counts or { cases = 0, passed = 0, failed = 0, errors = 1 }
    for _, key in ipairs({ "cases", "passed", "failed", "errors" }) do summary.counts[key] = summary.counts[key] + counts[key] end
    summary.executions[entry.feature] = response.executions
    io.write(string.format("[acceptance] counts %s cases=%d passed=%d failed=%d errors=%d\n",
      entry.generated, counts.cases, counts.passed, counts.failed, counts.errors))
    if response.outcome == "test_success" then
      summary.passed = summary.passed + 1
      io.write("[acceptance] ok ", entry.generated, "\n")
    else
      summary.failed[#summary.failed + 1] = { name = entry.generated, output = response.output or "", error = response.error or "" }
      io.write("[acceptance] FAILED ", entry.generated, "\n")
    end
    io.flush()
  end
  io.write(string.format("[acceptance] COUNTS: files=%d cases=%d passed=%d failed=%d errors=%d\n",
    summary.counts.files, summary.counts.cases, summary.counts.passed, summary.counts.failed, summary.counts.errors))
  return summary
end

function M.main()
  local options = { serial = true }
  for _, token in ipairs(arg or {}) do
    if token == "--serial" then options.serial = true
    elseif token == "--parallel" then options.serial = false
    else io.stderr:write("unknown option: " .. token .. "\n"); return 2 end
  end
  local ok, summary = pcall(M.run, options)
  if not ok then io.stderr:write(tostring(summary), "\n"); return 1 end
  for _, failure in ipairs(summary.failed) do io.stderr:write("---- ", failure.name, " ----\n", failure.error ~= "" and failure.error or failure.output, "\n") end
  io.write(string.format("acceptance: %d/%d specs passed\n", summary.passed, summary.total))
  return summary.total > 0 and #summary.failed == 0 and summary.passed == summary.total and 0 or 1
end
if arg and tostring(arg[0] or ""):match("tools/packages/acceptance/run_all%.lua$") then os.exit(M.main()) end
return M
