require("spec.bootstrap").install_package_paths()

local harness = require("TestHarness")
local log_capture = require("spec.support.log_capture")
local common = require("shared.lib.common")
local json_reader = require("arch_view.runtime.json_reader")
local number_utils = require("src.core.utils.number")

local M = {}

local SUITE_COST_HINTS = {
  ["suites.architecture.arch_view_live_tooling_contract"] = 40,
  ["suites.architecture.script_tools_io_tooling_contract"] = 28,
  ["suites.architecture.script_tools_mutate_tooling_contract"] = 16,
  ["suites.architecture.mutate4lua_tooling_contract"] = 10,
  ["suites.architecture.arch_view_snapshot_tooling_contract"] = 5,
  ["suites.architecture.crap_tooling_contract"] = 2,
}

local function _ps_literal(value)
  return "'" .. tostring(value or ""):gsub("'", "''") .. "'"
end

local function _suite_identity(suite, index)
  local module_name = tostring(suite and suite.module_name or "")
  if module_name ~= "" then
    return module_name
  end
  local suite_name = tostring(suite and suite.name or "")
  if suite_name ~= "" then
    return suite_name
  end
  return "tooling_suite_" .. tostring(index or 0)
end

local function _suite_tests(suite)
  if type(suite) ~= "table" then
    return {}
  end
  if type(suite.tests) == "table" then
    return suite.tests
  end
  return {}
end

local function _clamp_worker_count(parsed, suite_count)
  local total = number_utils.to_integer(suite_count) or 0
  if total <= 0 then
    return 1
  end
  if parsed == nil or parsed < 1 then
    return 1
  end
  if parsed > total then
    return total
  end
  return parsed
end

local function _resolve_worker_count(value, suite_count, is_windows)
  local parsed = number_utils.to_integer(value)
  if parsed == nil then
    local auto_workers = is_windows == true and 1 or 3
    parsed = math.min(auto_workers, math.max(1, suite_count or 0))
  end
  return _clamp_worker_count(parsed, suite_count)
end

local function _suite_cost(suite, index)
  local module_name = tostring(suite and suite.module_name or "")
  local hinted_cost = SUITE_COST_HINTS[module_name]
  if number_utils.is_numeric(hinted_cost) and hinted_cost > 0 then
    return hinted_cost
  end
  return math.max(1, #_suite_tests(suite))
end

local function _ranked_suites(suites)
  local ranked = {}
  for index, suite in ipairs(suites or {}) do
    ranked[#ranked + 1] = {
      suite = suite,
      cost = _suite_cost(suite, index),
      identity = _suite_identity(suite, index),
      original_index = index,
    }
  end
  table.sort(ranked, function(left, right)
    if left.cost ~= right.cost then
      return left.cost > right.cost
    end
    if left.identity ~= right.identity then
      return left.identity < right.identity
    end
    return left.original_index < right.original_index
  end)
  return ranked
end

local function _build_execution_plan(suites, worker_total)
  local normalized_workers = _clamp_worker_count(worker_total, #(suites or {}))
  local lanes = {}
  for index = 1, normalized_workers do
    lanes[index] = {
      index = index,
      total_cost = 0,
      suites = {},
    }
  end

  for _, entry in ipairs(_ranked_suites(suites)) do
    local target_lane = lanes[1]
    for lane_index = 2, #lanes do
      local candidate = lanes[lane_index]
      if candidate.total_cost < target_lane.total_cost then
        target_lane = candidate
      elseif candidate.total_cost == target_lane.total_cost and candidate.index < target_lane.index then
        target_lane = candidate
      end
    end
    target_lane.total_cost = target_lane.total_cost + entry.cost
    target_lane.suites[#target_lane.suites + 1] = entry.suite
  end

  local rounds = {}
  local round_count = 0
  for _, lane in ipairs(lanes) do
    if #lane.suites > round_count then
      round_count = #lane.suites
    end
  end

  for round_index = 1, round_count do
    local round = {}
    for _, lane in ipairs(lanes) do
      local suite = lane.suites[round_index]
      if suite ~= nil then
        round[#round + 1] = suite
      end
    end
    if #round > 0 then
      rounds[#rounds + 1] = round
    end
  end

  return {
    worker_total = normalized_workers,
    lanes = lanes,
    rounds = rounds,
  }
end

local function _sleep_seconds(seconds)
  local delay = number_utils.to_integer(seconds) or 1
  if delay < 1 then
    delay = 1
  end
  if common.is_windows() then
    os.execute('powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "Start-Sleep -Seconds '
      .. tostring(delay) .. '" >nul 2>nul')
    return
  end
  os.execute("sleep " .. tostring(delay) .. " >/dev/null 2>&1")
end

local function _launcher_paths(suite_module)
  local prefix = tostring(suite_module or "tooling"):gsub("[^%w_]+", "_")
  return {
    result_file = common.make_temp_path(prefix .. "_tooling_result", ".json"),
    status_file = common.make_temp_path(prefix .. "_tooling_status", ".txt"),
    launcher_file = common.make_temp_path(prefix .. "_tooling_launcher", common.is_windows() and ".ps1" or ".sh"),
  }
end

local function _write_launcher(suite_module, paths)
  local worker_path = common.resolve_path(common.current_dir(), "tests/support/tooling_worker.lua")
  local cwd = common.current_dir()
  local lua_command = "lua"

  if common.is_windows() then
    local script = table.concat({
      "$ErrorActionPreference = 'Stop'",
      "Set-Location -LiteralPath " .. _ps_literal(cwd),
      "try {",
      "  & " .. _ps_literal(lua_command)
        .. " " .. _ps_literal(worker_path)
        .. " '--suite-module' " .. _ps_literal(suite_module)
        .. " '--result-file' " .. _ps_literal(paths.result_file),
      "  $code = if ($LASTEXITCODE -ne $null) { [int]$LASTEXITCODE } else { 0 }",
      "} catch {",
      "  $code = 1",
      "}",
      "Set-Content -LiteralPath " .. _ps_literal(paths.status_file) .. " -Value $code -Encoding utf8",
      "exit 0",
    }, "\n")
    return common.write_file(paths.launcher_file, script)
  end

  local script = table.concat({
    "#!/bin/sh",
    "cd " .. common.shell_quote(cwd) .. " || { printf '%s\\n' '1' > " .. common.shell_quote(paths.status_file) .. "; exit 0; }",
    common.shell_quote(lua_command)
      .. " " .. common.shell_quote(worker_path)
      .. " --suite-module " .. common.shell_quote(suite_module)
      .. " --result-file " .. common.shell_quote(paths.result_file),
    "code=$?",
    "printf '%s\\n' \"$code\" > " .. common.shell_quote(paths.status_file),
    "exit 0",
  }, "\n")
  return common.write_file(paths.launcher_file, script)
end

local function _launch_worker(paths)
  local command
  if common.is_windows() then
    command = 'start "" /b powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File '
      .. common.shell_quote(paths.launcher_file)
  else
    command = "sh " .. common.shell_quote(paths.launcher_file) .. " >/dev/null 2>&1 &"
  end

  local ok, _, code = os.execute(command)
  if ok == true and (code == nil or code == 0) then
    return true
  end
  if number_utils.is_numeric(code) and code == 0 then
    return true
  end
  return nil, "failed to launch tooling worker"
end

local function _read_status(path)
  local content, err = common.read_file(path)
  if content == nil then
    return nil, err
  end
  local normalized = tostring(content):gsub("^\239\187\191", ""):gsub("%s+", "")
  local code = number_utils.to_integer(normalized)
  if code == nil then
    return nil, "invalid worker status: " .. tostring(content)
  end
  return code
end

local function _read_worker_payload(path)
  local content, err = common.read_file(path)
  if content == nil then
    return nil, err
  end
  return json_reader.decode(content)
end

local function _cleanup_paths(batch)
  for _, entry in ipairs(batch or {}) do
    common.remove_path(entry.paths.result_file)
    common.remove_path(entry.paths.status_file)
    common.remove_path(entry.paths.launcher_file)
  end
end

local function _wait_for_batch(batch)
  local deadline = os.time() + 1800
  while true do
    local pending = false
    for _, entry in ipairs(batch or {}) do
      if common.path_exists(entry.paths.status_file) ~= true then
        pending = true
        break
      end
    end
    if not pending then
      return true
    end
    if os.time() > deadline then
      return nil, "tooling worker timed out"
    end
    _sleep_seconds(1)
  end
end

local function _merge_results(merged, payload)
  local result = payload and payload.result or nil
  if type(result) ~= "table" then
    merged.failures[#merged.failures + 1] = {
      name = tostring(payload and payload.suite_name or payload and payload.suite_module or "tooling_worker"),
      err = tostring(payload and payload.error or "invalid tooling worker result"),
    }
    return
  end

  merged.total = merged.total + (result.total or 0)
  for _, failure in ipairs(result.failures or {}) do
    merged.failures[#merged.failures + 1] = failure
  end
  for _, slow in ipairs(result.slow_cases or {}) do
    merged.slow_cases[#merged.slow_cases + 1] = slow
  end
  local timing_data = result.timing_data or {}
  for _, entry in ipairs(timing_data.suite_times or {}) do
    merged.timing_data.suite_times[#merged.timing_data.suite_times + 1] = entry
  end
  for _, entry in ipairs(timing_data.case_times or {}) do
    merged.timing_data.case_times[#merged.timing_data.case_times + 1] = entry
  end
end

local function _finalize_result(merged, started_at)
  merged.failed = #merged.failures > 0
  merged.timing_data.total_elapsed_ms = math.max(0, os.time() - started_at) * 1000
  return merged
end

local function _print_failures(result)
  io.stdout:write("\n")
  print("Tooling failed (" .. tostring(#(result.failures or {})) .. "/" .. tostring(result.total or 0) .. ")")
  for index, failure in ipairs(result.failures or {}) do
    print(tostring(index) .. ") " .. tostring(failure.name))
    if failure.captured and failure.captured.lines and #failure.captured.lines > 0 then
      log_capture.replay(failure.captured)
    end
    print(tostring(failure.err))
  end
end

function M.run(suites, opts)
  opts = opts or {}
  local suite_count = #(suites or {})
  local worker_total = _resolve_worker_count(opts.workers, suite_count, common.is_windows())
  local worker_label = opts.workers == nil and "auto" or tostring(opts.workers)
  print("[tooling] workers=" .. worker_label .. " resolved=" .. tostring(worker_total) .. " scheduler=lpt")

  if worker_total <= 1 or suite_count <= 1 then
    return harness.run_all(suites, {
      capture_logs = opts.capture_logs ~= false,
    })
  end

  local plan = _build_execution_plan(suites, worker_total)
  local merged = {
    total = 0,
    failures = {},
    failed = false,
    summary = {},
    slow_cases = {},
    timing_data = {
      total_elapsed_ms = 0,
      suite_times = {},
      case_times = {},
      timer_source = "os.time",
    },
  }
  local started_at = os.time()

  for _, batch in ipairs(plan.rounds) do
    local active = {}
    for _, suite in ipairs(batch) do
      local suite_module = suite and suite.module_name or suite and suite.name or ""
      local paths = _launcher_paths(suite_module)
      local ok, err = _write_launcher(suite_module, paths)
      if not ok then
        _cleanup_paths(active)
        error(err)
      end
      local launched, launch_err = _launch_worker(paths)
      if not launched then
        _cleanup_paths(active)
        error(launch_err)
      end
      active[#active + 1] = {
        suite = suite,
        paths = paths,
      }
    end

    local waited, wait_err = _wait_for_batch(active)
    if not waited then
      _cleanup_paths(active)
      error(wait_err)
    end

    for _, entry in ipairs(active) do
      local status_code, status_err = _read_status(entry.paths.status_file)
      if status_code == nil then
        _cleanup_paths(active)
        error(status_err)
      end

      local payload = nil
      if common.path_exists(entry.paths.result_file) == true then
        payload = _read_worker_payload(entry.paths.result_file)
      end

      if status_code ~= 0 or type(payload) ~= "table" or payload.ok ~= true then
        merged.failures[#merged.failures + 1] = {
          name = tostring(entry.suite and entry.suite.name or entry.suite and entry.suite.module_name or "tooling_worker"),
          err = tostring((payload and payload.error) or ("tooling worker exited with code " .. tostring(status_code))),
        }
      else
        _merge_results(merged, payload)
      end
    end

    _cleanup_paths(active)
  end

  local result = _finalize_result(merged, started_at)
  if result.failed then
    _print_failures(result)
    error("tooling failed")
  end

  print("\nAll tooling checks passed (" .. tostring(result.total) .. ")")
  return result
end

M._test_support = {
  resolve_worker_count = _resolve_worker_count,
  suite_cost = _suite_cost,
  build_execution_plan = _build_execution_plan,
}

return M
