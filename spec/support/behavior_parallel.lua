require("spec.bootstrap").install_package_paths()

local common = require("shared.lib.common")
local number_utils = require("src.foundation.lang.number")

local M = {}

local _BEHAVIOR_ROOT = "spec/behavior"
local _BATCH_TIMEOUT = 600

local function _discover_spec_files(root)
  local command = "find " .. common.shell_quote(root) .. " -name '*_spec.lua' -type f 2>/dev/null"
  local handle = io.popen(command)
  if handle == nil then
    return {}
  end
  local files = {}
  for line in handle:lines() do
    local trimmed = line:match("^%s*(.-)%s*$")
    if trimmed and trimmed ~= "" then
      files[#files + 1] = trimmed
    end
  end
  handle:close()
  table.sort(files)
  return files
end

local function _file_cost(path)
  local f = io.open(path, "r")
  if f == nil then
    return 1
  end
  local count = 0
  for line in f:lines() do
    if line:find("it(", 1, true) then
      count = count + 1
    end
  end
  f:close()
  return math.max(1, count)
end

local function _ranked_files(files)
  local ranked = {}
  for index, path in ipairs(files) do
    ranked[#ranked + 1] = {
      path = path,
      cost = _file_cost(path),
      index = index,
    }
  end
  table.sort(ranked, function(left, right)
    if left.cost ~= right.cost then
      return left.cost > right.cost
    end
    return left.index < right.index
  end)
  return ranked
end

local function _build_lanes(files, worker_count)
  local clamped = math.max(1, math.min(worker_count, #files))
  local lanes = {}
  for i = 1, clamped do
    lanes[i] = { index = i, total_cost = 0, files = {} }
  end
  for _, entry in ipairs(_ranked_files(files)) do
    local target = lanes[1]
    for i = 2, #lanes do
      if lanes[i].total_cost < target.total_cost then
        target = lanes[i]
      elseif lanes[i].total_cost == target.total_cost and lanes[i].index < target.index then
        target = lanes[i]
      end
    end
    target.total_cost = target.total_cost + entry.cost
    target.files[#target.files + 1] = entry.path
  end
  return lanes, clamped
end

local function _resolve_workers(file_count)
  local env_val = os.getenv("MONO_BEHAVIOR_WORKERS")
  if env_val == nil or env_val == "" or env_val == "auto" then
    return math.min(common.is_windows() and 1 or 3, math.max(1, file_count))
  end
  local parsed = number_utils.to_integer(env_val)
  if parsed == nil or parsed < 1 then
    return 1
  end
  return math.min(parsed, file_count)
end

local function _worker_paths(label, lane_index)
  local prefix = label .. "_w" .. tostring(lane_index)
  return {
    output_file = common.make_temp_path(prefix .. "_output", ".txt"),
    status_file = common.make_temp_path(prefix .. "_status", ".txt"),
    launcher_file = common.make_temp_path(prefix .. "_launcher", ".sh"),
  }
end

local function _write_launcher(lane, paths)
  local cwd = common.current_dir()
  local file_args = {}
  for _, f in ipairs(lane.files) do
    file_args[#file_args + 1] = common.shell_quote(f)
  end

  local script = table.concat({
    "#!/bin/sh",
    "cd " .. common.shell_quote(cwd)
      .. " || { printf '%s\\n' '1' > " .. common.shell_quote(paths.status_file) .. "; exit 0; }",
    "busted"
      .. " --helper=spec/helper.lua"
      .. " --output=spec/log_warns_handler.lua"
      .. " --pattern=_spec"
      .. " -- " .. table.concat(file_args, " ")
      .. " > " .. common.shell_quote(paths.output_file) .. " 2>&1",
    "code=$?",
    "printf '%s\\n' \"$code\" > " .. common.shell_quote(paths.status_file),
    "exit 0",
  }, "\n")
  return common.write_file(paths.launcher_file, script)
end

local function _launch(paths)
  local command = "sh " .. common.shell_quote(paths.launcher_file) .. " >/dev/null 2>&1 &"
  local ok, _, code = os.execute(command)
  if ok == true and (code == nil or code == 0) then
    return true
  end
  if number_utils.is_numeric(code) and code == 0 then
    return true
  end
  return nil, "failed to launch behavior worker"
end

local function _sleep(seconds)
  os.execute("sleep " .. tostring(seconds or 0.3) .. " >/dev/null 2>&1")
end

local function _read_status(path)
  local content = common.read_file(path)
  if content == nil then
    return nil
  end
  return number_utils.to_integer(tostring(content):gsub("%s+", ""))
end

local function _parse_output(content)
  local result = {
    passed = 0,
    failed = 0,
    failure_lines = {},
    warn_lines = {},
    slow_lines = {},
  }
  if content == nil then
    return result
  end
  for line in content:gmatch("[^\n]+") do
    if line:match("^ok %d") then
      result.passed = result.passed + 1
    elseif line:match("^not ok %d") then
      result.failed = result.failed + 1
      result.failure_lines[#result.failure_lines + 1] = line
    elseif line:match("^# WARN ") then
      local text = line:sub(8)
      result.warn_lines[text] = (result.warn_lines[text] or 0) + 1
    elseif line:match("^# SLOW ") then
      result.slow_lines[#result.slow_lines + 1] = line
    end
  end
  return result
end

local function _cleanup(workers)
  for _, w in ipairs(workers) do
    common.remove_path(w.paths.output_file)
    common.remove_path(w.paths.status_file)
    common.remove_path(w.paths.launcher_file)
  end
end

local function _wait(workers)
  local deadline = os.time() + _BATCH_TIMEOUT
  while true do
    local pending = false
    for _, w in ipairs(workers) do
      if common.path_exists(w.paths.status_file) ~= true then
        pending = true
        break
      end
    end
    if not pending then
      return true
    end
    if os.time() > deadline then
      return nil, "behavior workers timed out after " .. tostring(_BATCH_TIMEOUT) .. "s"
    end
    _sleep(0.3)
  end
end

local function _print_summary(merged, elapsed, worker_count, label)
  if next(merged.warn_counts) then
    io.write("# warn summary:\n")
    local rows = {}
    for line, count in pairs(merged.warn_counts) do
      rows[#rows + 1] = { line = line, count = count }
    end
    table.sort(rows, function(a, b)
      if a.count ~= b.count then return a.count > b.count end
      return a.line < b.line
    end)
    for _, row in ipairs(rows) do
      io.write(string.format("#   [non-whitelisted] x%d %s\n", row.count, row.line))
    end
    io.write(string.format("# total non-whitelisted warns: %d\n",
      merged.total_warns))
  end

  if #merged.slow_lines > 0 then
    io.write("# slow summary:\n")
    for _, line in ipairs(merged.slow_lines) do
      io.write(line .. "\n")
    end
    io.write(string.format("# total slow tests: %d\n", #merged.slow_lines))
  end

  local status = merged.failed > 0 and "FAIL" or "PASS"
  io.write(string.format(
    "\n[%s-parallel] %s  %d passed / %d failed  workers=%d  %.1fs\n",
    label, status, merged.passed, merged.failed, worker_count, elapsed
  ))
  io.flush()
end

function M.run(opts)
  opts = opts or {}
  local root = opts.root or _BEHAVIOR_ROOT
  local label = opts.label or root:match("([^/]+)$") or "parallel"

  local files = _discover_spec_files(root)
  if #files == 0 then
    io.write("[" .. label .. "-parallel] no spec files found in " .. root .. "\n")
    return { passed = 0, failed = 0, ok = true }
  end

  local worker_count = _resolve_workers(#files)
  local env_label = os.getenv("MONO_BEHAVIOR_WORKERS") or "auto"
  io.write(string.format(
    "[%s-parallel] files=%d workers=%s resolved=%d scheduler=lpt\n",
    label, #files, env_label, worker_count
  ))
  io.flush()

  if worker_count <= 1 then
    io.write("[" .. label .. "-parallel] single worker, running serial\n")
    io.flush()
    local file_args = {}
    for _, f in ipairs(files) do
      file_args[#file_args + 1] = common.shell_quote(f)
    end
    local cmd = "busted --helper=spec/helper.lua"
      .. " --output=spec/log_warns_handler.lua"
      .. " --pattern=_spec"
      .. " -- " .. table.concat(file_args, " ")
    local ok, _, code = os.execute(cmd)
    local success = ok == true and (code == nil or code == 0)
    if not success and number_utils.is_numeric(code) then
      success = code == 0
    end
    return { passed = 0, failed = success and 0 or 1, ok = success }
  end

  local lanes = _build_lanes(files, worker_count)
  local started_at = os.time()

  local workers = {}
  for _, lane in ipairs(lanes) do
    if #lane.files > 0 then
      local paths = _worker_paths(label, lane.index)
      local ok, err = _write_launcher(lane, paths)
      if not ok then
        _cleanup(workers)
        error("failed to write launcher: " .. tostring(err))
      end
      local launched, launch_err = _launch(paths)
      if not launched then
        _cleanup(workers)
        error("failed to launch worker: " .. tostring(launch_err))
      end
      workers[#workers + 1] = { lane = lane, paths = paths }
    end
  end

  local waited, wait_err = _wait(workers)
  if not waited then
    _cleanup(workers)
    error(wait_err)
  end

  local merged = {
    passed = 0,
    failed = 0,
    failure_lines = {},
    warn_counts = {},
    total_warns = 0,
    slow_lines = {},
  }

  for _, w in ipairs(workers) do
    local status_code = _read_status(w.paths.status_file)
    local content = common.read_file(w.paths.output_file)
    local parsed = _parse_output(content)

    merged.passed = merged.passed + parsed.passed
    merged.failed = merged.failed + parsed.failed
    for _, line in ipairs(parsed.failure_lines) do
      merged.failure_lines[#merged.failure_lines + 1] = line
    end
    for text, count in pairs(parsed.warn_lines) do
      merged.warn_counts[text] = (merged.warn_counts[text] or 0) + count
      merged.total_warns = merged.total_warns + count
    end
    for _, line in ipairs(parsed.slow_lines) do
      merged.slow_lines[#merged.slow_lines + 1] = line
    end

    if status_code ~= 0 and parsed.failed == 0 then
      merged.failed = merged.failed + 1
      merged.failure_lines[#merged.failure_lines + 1] =
        "worker " .. tostring(w.lane.index) .. " exited with code " .. tostring(status_code)
    end
  end

  _cleanup(workers)

  local elapsed = math.max(0, os.time() - started_at)

  if #merged.failure_lines > 0 then
    io.write("\n[" .. label .. "-parallel] failures:\n")
    for _, line in ipairs(merged.failure_lines) do
      io.write("  " .. line .. "\n")
    end
  end

  _print_summary(merged, elapsed, #workers, label)

  return {
    passed = merged.passed,
    failed = merged.failed,
    ok = merged.failed == 0,
  }
end

M._test_support = {
  discover_spec_files = _discover_spec_files,
  file_cost = _file_cost,
  build_lanes = _build_lanes,
  parse_output = _parse_output,
  resolve_workers = _resolve_workers,
}

if arg and arg[0] and arg[0]:find("behavior_parallel", 1, true) then
  local cli_opts = {}
  for i = 1, #arg do
    if arg[i] == "--root" and arg[i + 1] then
      cli_opts.root = arg[i + 1]
    elseif arg[i] == "--label" and arg[i + 1] then
      cli_opts.label = arg[i + 1]
    end
  end
  local result = M.run(cli_opts)
  os.exit(result.ok and 0 or 1)
end

return M
