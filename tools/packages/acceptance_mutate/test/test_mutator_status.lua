require("test.bootstrap").install_package_paths()
local check = require("luassert")
local fs_lib = require("foundation.fs")
local path_lib = require("foundation.path")
local proc_lib = require("foundation.proc")
local shell_lib = require("foundation.shell")
local json = require("acceptance4lua.json")
local lua54 = require("foundation.lua54")

local function _tmp_dir(name)
  local token = tostring(os.time()) .. "_" .. tostring({}):gsub("[^%w]+", "")
  local dir = path_lib.join_path("tmp", name .. "_" .. token)
  fs_lib.remove_path(dir)
  assert(fs_lib.ensure_dir(dir))
  return dir
end

local function _write_sample_feature(path)
  assert(fs_lib.write_file(path, table.concat({
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
  local stdout_path = path_lib.join_path(tmp_dir, options.name .. "_stdout.txt")
  local stderr_path = path_lib.join_path(tmp_dir, options.name .. "_stderr.txt")
  local args = {
    lua54.lua54_bin(), shell_lib.shell_quote("tools/packages/acceptance_mutate/mutator.lua"),
    "--feature", shell_lib.shell_quote(options.feature_path),
    "--work-dir", shell_lib.shell_quote(path_lib.join_path(tmp_dir, options.name .. "_work")),
    "--runner-worker", shell_lib.shell_quote(
      lua54.lua54_bin() .. " tools/packages/acceptance/runner_worker.lua"),
    "--json",
  }
  if options.workers ~= nil then
    args[#args + 1] = "--workers"
    args[#args + 1] = tostring(options.workers)
  end
  if options.status_interval ~= nil then
    args[#args + 1] = "--status-interval"
    args[#args + 1] = shell_lib.shell_quote(options.status_interval)
  end
  local command = table.concat(args, " ")
    .. " > " .. shell_lib.shell_quote(stdout_path)
    .. " 2> " .. shell_lib.shell_quote(stderr_path)
  local result = proc_lib.run_command("(" .. command .. ")", { cwd = "." })
  return {
    result = result,
    stdout = fs_lib.read_file(stdout_path) or "",
    stderr = fs_lib.read_file(stderr_path) or "",
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

-- #361 P4:原差分跳过汇报 e2e 已删——与 test_mutator_level 集成层重复;
-- e2e 层独有价值仅「stderr 不污染 stdout JSON」与「jsonl 按 workers 拆分」,
-- 即下方两例。
-- POSIX-only examples are excluded, never counted as passed on Windows.

local function
writes_status_lines_to_stderr_without_polluting_the_json_report(_self)
  local tmp_dir = _tmp_dir("acceptance_mutator_status")
  local feature_path = path_lib.join_path(tmp_dir, "status.feature")
  _write_sample_feature(feature_path)

  local run = _run_mutator(tmp_dir, {
    name = "status",
    feature_path = feature_path,
    status_interval = "30s",
  })

  check.is_true(run.result.ok, run.stderr)
  check.is_table(json.decode(run.stdout))
  check.is_nil(run.stdout:find("^status%s+"))
  check.is_true(fs_lib.path_exists(path_lib.join_path(tmp_dir, "status_work/mutations/m1/feature.json")))
  check.is_false(fs_lib.path_exists(path_lib.join_path(tmp_dir, "status_work/m1/feature.json")))

  local worker_input = assert(fs_lib.read_file(path_lib.join_path(tmp_dir, "status_work/runner-worker-input.jsonl")))
  local first_job = json.decode(worker_input:match("([^\n]+)"))
  check.equal(
    path_lib.join_path(tmp_dir, "status_work/mutations/m1/feature.json"),
    first_job.feature_json
  )
  check.equal(
    path_lib.join_path(tmp_dir, "status_work/mutations/m1"),
    first_job.work_dir
  )

  local status_line = _last_status_line(run.stderr)
  check.is_string(status_line)
  check.truthy(status_line:find("total=2", 1, true))
  check.truthy(status_line:find("completed=2", 1, true))
  check.truthy(status_line:find("running=0", 1, true))
  check.truthy(status_line:find("elapsed=", 1, true))
end

local function
splits_runner_worker_jobs_across_requested_workers(_self)
  local tmp_dir = _tmp_dir("acceptance_mutator_status_workers")
  local feature_path = path_lib.join_path(tmp_dir, "status.feature")
  _write_sample_feature(feature_path)

  local run = _run_mutator(tmp_dir, {
    name = "workers",
    feature_path = feature_path,
    workers = 2,
  })

  check.is_true(run.result.ok, run.stderr)
  check.is_true(fs_lib.path_exists(path_lib.join_path(tmp_dir, "workers_work/runner-worker-input-1.jsonl")))
  check.is_true(fs_lib.path_exists(path_lib.join_path(tmp_dir, "workers_work/runner-worker-input-2.jsonl")))
end

describe("acceptance mutator status POSIX capability", function()
  it("writes_status_lines_to_stderr_without_polluting_the_json_report", writes_status_lines_to_stderr_without_polluting_the_json_report)
  it("splits_runner_worker_jobs_across_requested_workers", splits_runner_worker_jobs_across_requested_workers)
end)
