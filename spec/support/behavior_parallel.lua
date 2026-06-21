require("spec.bootstrap").install_package_paths()

local common = require("shared.lib.common")
local parallel_lanes = require("shared.lib.parallel_lanes")
local sharding = require("shared.lib.busted_sharding")

local M = {}

local _BEHAVIOR_ROOT = "spec/behavior"
local _BATCH_TIMEOUT = 600

local function _discover_spec_files(root)
  return sharding.discover_spec_files(root)
end

local function _profile_roots(profile)
  if profile == nil or profile == "" then
    return nil, "missing profile"
  end
  local profiles = dofile(".busted")
  local config = profiles[profile]
  if config == nil then
    return nil, "unknown busted profile: " .. tostring(profile)
  end
  local root = config.ROOT
  if root == nil then
    return nil, "profile has no ROOT: " .. tostring(profile)
  end
  if type(root) == "table" then
    return root
  end
  return { root }
end

local function _resolve_roots(opts)
  if opts.profile ~= nil then
    return _profile_roots(opts.profile)
  end
  if opts.roots ~= nil then
    return opts.roots
  end
  return { opts.root or _BEHAVIOR_ROOT }
end

local function _discover_spec_files_for_roots(roots)
  local files = {}
  local seen = {}
  for _, root in ipairs(roots or {}) do
    for _, path in ipairs(_discover_spec_files(root)) do
      if not seen[path] then
        files[#files + 1] = path
        seen[path] = true
      end
    end
  end
  table.sort(files)
  return files
end

local function _file_cost(path)
  return sharding.file_cost(path)
end

local function _build_lanes(files, worker_count)
  local lanes = sharding.build_lpt_lanes(files, worker_count)
  return lanes, #lanes
end

local function _default_workers()
  return common.is_windows() and 1 or 3
end

local function _resolve_workers(file_count)
  return sharding.resolve_workers("MONO_BEHAVIOR_WORKERS", file_count, _default_workers())
end

local function _build_lane_args(files)
  local args = {
    "busted",
    "--helper=spec/helper.lua",
    "--output=spec/log_warns_handler.lua",
    "--pattern=_spec",
    "--",
  }
  for _, f in ipairs(files) do
    args[#args + 1] = f
  end
  return args
end

local function _build_lane_cmd(files)
  return common.build_command(_build_lane_args(files))
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
  local summary_passed = nil
  local summary_failed = nil
  local summary_line = nil
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
    elseif line:match("^# RESULT: ") then
      local passed_only = line:match("^# RESULT: (%d+) ok$")
      local passed, failed, errors = line:match("^# RESULT: (%d+) ok .- (%d+) FAIL .- (%d+) error")
      if passed_only ~= nil then
        summary_passed = tonumber(passed_only)
        summary_failed = 0
      elseif passed ~= nil then
        summary_passed = tonumber(passed)
        summary_failed = (tonumber(failed) or 0) + (tonumber(errors) or 0)
        summary_line = line
      end
    end
  end
  if result.passed == 0 and summary_passed ~= nil then
    result.passed = summary_passed
  end
  if result.failed == 0 and (summary_failed or 0) > 0 then
    result.failed = summary_failed
    result.failure_lines[#result.failure_lines + 1] = summary_line or "# RESULT: failed"
  end
  return result
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
  local roots, roots_err = _resolve_roots(opts)
  if roots == nil then
    io.write("[parallel] " .. tostring(roots_err) .. "\n")
    return { passed = 0, failed = 1, ok = false }
  end
  local label = opts.label
    or opts.profile
    or (roots[1] and roots[1]:match("([^/]+)$"))
    or "parallel"

  local files = _discover_spec_files_for_roots(roots)
  if #files == 0 then
    io.write("[" .. label .. "-parallel] no spec files found in " .. table.concat(roots, ",") .. "\n")
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
    local result = common.run_command(_build_lane_args(roots))
    if result.output and result.output ~= "" then
      io.write(result.output)
      if result.output:sub(-1) ~= "\n" then io.write("\n") end
      io.flush()
    end
    local success = result.ok == true
    return { passed = 0, failed = success and 0 or 1, ok = success }
  end

  local lanes = _build_lanes(files, worker_count)
  local started_at = os.time()

  local lane_specs = {}
  local lane_meta = {}
  for _, lane in ipairs(lanes) do
    if #lane.files > 0 then
      lane_specs[#lane_specs + 1] = {
        label = label .. "_w" .. tostring(lane.index),
        cmd = _build_lane_cmd(lane.files),
      }
      lane_meta[#lane_meta + 1] = lane
    end
  end

  local _, results = parallel_lanes.run(lane_specs, {
    stream = false,
    timeout = _BATCH_TIMEOUT,
  })

  local merged = {
    passed = 0,
    failed = 0,
    failure_lines = {},
    warn_counts = {},
    total_warns = 0,
    slow_lines = {},
  }

  for i, r in ipairs(results) do
    local parsed = _parse_output(r.output)

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

    if not r.ok and parsed.failed == 0 then
      merged.failed = merged.failed + 1
      merged.failure_lines[#merged.failure_lines + 1] =
        "worker " .. tostring(lane_meta[i].index) .. " exited with code " .. tostring(r.exit_code)
    end
  end

  local elapsed = math.max(0, os.time() - started_at)

  if #merged.failure_lines > 0 then
    io.write("\n[" .. label .. "-parallel] failures:\n")
    for _, line in ipairs(merged.failure_lines) do
      io.write("  " .. line .. "\n")
    end
  end

  _print_summary(merged, elapsed, #lane_specs, label)

  return {
    passed = merged.passed,
    failed = merged.failed,
    ok = merged.failed == 0,
  }
end

M._test_support = {
  discover_spec_files = _discover_spec_files,
  discover_spec_files_for_roots = _discover_spec_files_for_roots,
  file_cost = _file_cost,
  build_lanes = _build_lanes,
  parse_output = _parse_output,
  resolve_workers = _resolve_workers,
  profile_roots = _profile_roots,
}

if arg and arg[0] and arg[0]:find("behavior_parallel", 1, true) then
  local cli_opts = {}
  for i = 1, #arg do
    if arg[i] == "--root" and arg[i + 1] then
      cli_opts.root = arg[i + 1]
    elseif arg[i] == "--profile" and arg[i + 1] then
      cli_opts.profile = arg[i + 1]
    elseif arg[i] == "--label" and arg[i + 1] then
      cli_opts.label = arg[i + 1]
    end
  end
  local result = M.run(cli_opts)
  os.exit(result.ok and 0 or 1)
end

return M
