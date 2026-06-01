local common = require("shared.lib.common")
local json = require("acceptance4lua.json")

local function _tmp_dir(name)
  local token = tostring(os.time()) .. "_" .. tostring({}):gsub("[^%w]+", "")
  local dir = common.join_path("tmp", name .. "_" .. token)
  common.remove_path(dir)
  assert(common.ensure_dir(dir))
  return dir
end

local function _write_sample_feature(path)
  assert(common.write_file(path, table.concat({
    "Feature: mutator status sample",
    "",
    "Scenario Outline: integer conversion",
    "  Given project acceptance step handlers are loaded",
    "  And a text value <raw>",
    "  When the project converts it to an integer",
    "  Then the integer result is <result>",
    "",
    "Examples:",
    "  | raw | result |",
    "  | 1   | 1      |",
    "",
  }, "\n")))
end

local function _run_mutator(tmp_dir, options)
  options = options or {}
  local stdout_path = common.join_path(tmp_dir, options.name .. "_stdout.txt")
  local stderr_path = common.join_path(tmp_dir, options.name .. "_stderr.txt")
  local args = {
    common.shell_quote("./gherkin-mutator"),
    "--feature", common.shell_quote(options.feature_path),
    "--work-dir", common.shell_quote(common.join_path(tmp_dir, options.name .. "_work")),
    "--runner-worker", common.shell_quote("lua tools/acceptance/runner_worker.lua"),
    "--json",
  }
  if options.workers ~= nil then
    args[#args + 1] = "--workers"
    args[#args + 1] = tostring(options.workers)
  end
  if options.status_interval ~= nil then
    args[#args + 1] = "--status-interval"
    args[#args + 1] = common.shell_quote(options.status_interval)
  end
  local command = table.concat(args, " ")
    .. " > " .. common.shell_quote(stdout_path)
    .. " 2> " .. common.shell_quote(stderr_path)
  local result = common.run_command(command, { cwd = "." })
  return {
    result = result,
    stdout = common.read_file(stdout_path) or "",
    stderr = common.read_file(stderr_path) or "",
  }
end

local function _last_status_line(text)
  local found = nil
  for line in (tostring(text or "") .. "\n"):gmatch("([^\n]*)\n") do
    if line:match("^status%s+") then
      found = line
    end
  end
  return found
end

describe("gherkin-mutator status reporting", function()
  it("writes status lines to stderr without polluting the JSON report", function()
    local tmp_dir = _tmp_dir("acceptance_mutator_status")
    local feature_path = common.join_path(tmp_dir, "status.feature")
    _write_sample_feature(feature_path)

    local run = _run_mutator(tmp_dir, {
      name = "status",
      feature_path = feature_path,
      status_interval = "30s",
    })

    assert.is_true(run.result.ok, run.stderr)
    assert.is_table(json.decode(run.stdout))
    assert.is_nil(run.stdout:find("^status%s+"))
    assert.is_true(common.path_exists(common.join_path(tmp_dir, "status_work/mutations/m1/feature.json")))
    assert.is_false(common.path_exists(common.join_path(tmp_dir, "status_work/m1/feature.json")))

    local worker_input = assert(common.read_file(common.join_path(tmp_dir, "status_work/runner-worker-input.jsonl")))
    local first_job = json.decode(worker_input:match("([^\n]+)"))
    assert.are.equal(
      common.join_path(tmp_dir, "status_work/mutations/m1/feature.json"),
      first_job.feature_json
    )
    assert.are.equal(
      common.join_path(tmp_dir, "status_work/mutations/m1"),
      first_job.work_dir
    )

    local status_line = _last_status_line(run.stderr)
    assert.is_string(status_line)
    assert.is_truthy(status_line:find("total=2", 1, true))
    assert.is_truthy(status_line:find("completed=2", 1, true))
    assert.is_truthy(status_line:find("running=0", 1, true))
    assert.is_truthy(status_line:find("elapsed=", 1, true))
  end)

  it("splits runner-worker jobs across requested workers", function()
    local tmp_dir = _tmp_dir("acceptance_mutator_status_workers")
    local feature_path = common.join_path(tmp_dir, "status.feature")
    _write_sample_feature(feature_path)

    local run = _run_mutator(tmp_dir, {
      name = "workers",
      feature_path = feature_path,
      workers = 2,
    })

    assert.is_true(run.result.ok, run.stderr)
    assert.is_true(common.path_exists(common.join_path(tmp_dir, "workers_work/runner-worker-input-1.jsonl")))
    assert.is_true(common.path_exists(common.join_path(tmp_dir, "workers_work/runner-worker-input-2.jsonl")))
  end)

  it("reports skipped scenarios and mutations when differential reuse skips work", function()
    local tmp_dir = _tmp_dir("acceptance_mutator_status_skips")
    local feature_path = common.join_path(tmp_dir, "status.feature")
    _write_sample_feature(feature_path)

    local baseline = _run_mutator(tmp_dir, {
      name = "baseline",
      feature_path = feature_path,
    })
    assert.is_true(baseline.result.ok, baseline.stderr)

    local run = _run_mutator(tmp_dir, {
      name = "reuse",
      feature_path = feature_path,
      status_interval = "30s",
    })

    assert.is_true(run.result.ok, run.stderr)
    local status_line = _last_status_line(run.stderr)
    assert.is_string(status_line)
    assert.is_truthy(status_line:find("skipped_scenarios=1", 1, true))
    assert.is_truthy(status_line:find("skipped_mutations=2", 1, true))
  end)
end)
