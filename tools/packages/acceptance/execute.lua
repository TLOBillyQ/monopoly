-- Isolated real busted process. Stdout is exactly one JSON result document.
local source = debug.getinfo(1, "S").source:gsub("^@", ""):gsub("\\", "/")
local bootstrap = dofile(assert(source:match("^(.*)/[^/]+$")) .. "/../../foundation/bootstrap.lua")
local env = bootstrap.install(source)
local json = require("acceptance4lua.json")
local response = { backend = "busted", outcome = "infrastructure_error", error = "", output = "", executions = {} }
local output = {}
local original_write, original_print = io.write, print
local ok, err = xpcall(function()
  assert(_VERSION == "Lua 5.4", "acceptance executor requires Lua 5.4")
  assert(arg[1], "missing generated spec")
  assert(bootstrap.ensure_busted_tree(env.repo_root))
  require("packages.test_runner.cache_loader").install(env.repo_root)
  local path_override = os.getenv("ACCEPTANCE_LUA_PATH")
  if path_override then package.path = path_override end
  if arg[3] then
    local metadata_text = assert(require("foundation.fs").read_raw(require("packages.acceptance.entrypoint").metadata_path_for(arg[1], arg[3])), "acceptance metadata missing")
    local metadata = require("acceptance4lua.json").decode(metadata_text)
    assert(metadata.feature_path == arg[3], "acceptance metadata identity mismatch")
    assert(metadata.implementation_hash == require("acceptance4lua.spec_hash").compute_generated_files_hash({ arg[1] }), "acceptance metadata hash mismatch")
  end
  if arg[2] and arg[2] ~= "" then
    local file = assert(io.open(arg[2], "rb"))
    local text = file:read("*a"); file:close()
    require("packages.acceptance.runtime").override_ir = require("acceptance4lua.json").decode(text)
  end
  rawset(io, "write", function(...) for index = 1, select("#", ...) do output[#output + 1] = tostring(select(index, ...)) end end)
  rawset(_G, "print", function(...)
    local parts = {}; for index = 1, select("#", ...) do parts[index] = tostring(select(index, ...)) end
    output[#output + 1] = table.concat(parts, "\t") .. "\n"
  end)
  local events = require("packages.test_runner.events")
  require("test.env_runtime").refresh()
  local leaks, execution_start = 0, 0
  local runtime = require("packages.acceptance.runtime")
  events.subscribe({ "test", "start" }, function()
    execution_start = #runtime.executions
    require("test.support.env").reseed_defaults()
  end)
  events.subscribe({ "test", "end" }, function(_, _, status)
    for index = execution_start + 1, #runtime.executions do runtime.executions[index].status = status end
    local missing = require("test.support.runtime_baseline_guard").check_and_restore()
    if #missing > 0 then leaks = leaks + 1; io.write("# BASELINE LEAK: " .. table.concat(missing, ", ") .. "\n") end
  end)
  events.subscribe({ "suite", "end" }, function() events.results.errors = events.results.errors + leaks end)
  local counts = require("packages.test_runner.busted_backend").run({ arg[1] }, nil, "TAP", {})
  response.counts = counts
  response.executions = require("packages.acceptance.runtime").executions
  if arg[2] and arg[2] ~= "" and counts.errors == 0 then
    local ir = require("packages.acceptance.runtime").override_ir
    local expected = {}
    for scenario_index, scenario in ipairs(ir.scenarios or {}) do
      local examples = #(scenario.examples or {})
      for example_index = 1, math.max(1, examples) do expected[#expected + 1] = scenario_index .. "/" .. example_index end
    end
    assert(#expected == #response.executions and #expected == counts.cases, "acceptance execution set incomplete")
    for index, execution in ipairs(response.executions) do
      assert(expected[index] == execution.scenario .. "/" .. execution.example, "acceptance execution identity mismatch")
    end
  end
  assert(counts.cases > 0, "no acceptance cases executed")
  response.outcome = counts.errors > 0 and "infrastructure_error" or counts.failed > 0 and "test_failure" or "test_success"
end, debug.traceback)
rawset(io, "write", original_write)
rawset(_G, "print", original_print)
response.output = table.concat(output)
if not ok then response.error = tostring(err) end
if response.outcome == "infrastructure_error" and response.error == "" then response.error = response.output end
io.write(json.encode_compact(response), "\n")
io.flush()
os.exit(response.outcome == "test_success" and 0 or 1)
