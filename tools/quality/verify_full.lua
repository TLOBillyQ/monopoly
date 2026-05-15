require("spec.bootstrap").install_package_paths()

local common = require("shared.lib.common")
local number_utils = require("src.foundation.number")

local _PHASE_TIMEOUT = 600

local function _check_command(cmd)
  local handle = io.popen("command -v " .. common.shell_quote(cmd) .. " 2>/dev/null")
  if handle == nil then
    return false
  end
  local result = handle:read("*a")
  handle:close()
  return result ~= nil and result ~= ""
end

local function _run_step(label, cmd)
  io.write(string.format("[verify-full] >> %s\n", label))
  io.flush()
  local started = os.time()
  local ok, _, code = os.execute(cmd)
  local elapsed = math.max(0, os.time() - started)
  local success = ok == true and (code == nil or code == 0)
  if not success and number_utils.is_numeric(code) then
    success = code == 0
  end
  io.write(string.format(
    "[verify-full] %s %s  %ds\n", success and "PASS" or "FAIL", label, elapsed
  ))
  io.flush()
  return success
end

local function _lane_paths(label)
  local prefix = "vf_" .. label
  return {
    output = common.make_temp_path(prefix .. "_out", ".txt"),
    status = common.make_temp_path(prefix .. "_status", ".txt"),
    launcher = common.make_temp_path(prefix .. "_launcher", ".sh"),
  }
end

local function _write_lane_launcher(cmd, paths)
  local cwd = common.current_dir()
  local script = table.concat({
    "#!/bin/sh",
    "cd " .. common.shell_quote(cwd)
      .. " || { printf '%s\\n' '1' > " .. common.shell_quote(paths.status) .. "; exit 0; }",
    cmd .. " > " .. common.shell_quote(paths.output) .. " 2>&1",
    "code=$?",
    "printf '%s\\n' \"$code\" > " .. common.shell_quote(paths.status),
    "exit 0",
  }, "\n")
  return common.write_file(paths.launcher, script)
end

local function _launch(paths)
  local cmd = "sh " .. common.shell_quote(paths.launcher) .. " >/dev/null 2>&1 &"
  local ok, _, code = os.execute(cmd)
  if ok == true and (code == nil or code == 0) then
    return true
  end
  if number_utils.is_numeric(code) and code == 0 then
    return true
  end
  return nil, "failed to launch lane"
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

local function _cleanup_lane(paths)
  common.remove_path(paths.output)
  common.remove_path(paths.status)
  common.remove_path(paths.launcher)
end

local function _run_parallel(lanes)
  local lane_labels = {}
  for _, l in ipairs(lanes) do
    lane_labels[#lane_labels + 1] = l.label
  end
  io.write(string.format(
    "[verify-full] >> parallel: %s\n", table.concat(lane_labels, " | ")
  ))
  io.flush()

  local started = os.time()
  local active = {}

  for _, lane in ipairs(lanes) do
    local paths = _lane_paths(lane.label)
    local ok, err = _write_lane_launcher(lane.cmd, paths)
    if not ok then
      for _, a in ipairs(active) do
        _cleanup_lane(a.paths)
      end
      error("failed to write launcher for " .. lane.label .. ": " .. tostring(err))
    end
    local launched, launch_err = _launch(paths)
    if not launched then
      _cleanup_lane(paths)
      for _, a in ipairs(active) do
        _cleanup_lane(a.paths)
      end
      error("failed to launch " .. lane.label .. ": " .. tostring(launch_err))
    end
    active[#active + 1] = { label = lane.label, paths = paths }
  end

  local deadline = os.time() + _PHASE_TIMEOUT
  while true do
    local pending = false
    for _, a in ipairs(active) do
      if common.path_exists(a.paths.status) ~= true then
        pending = true
        break
      end
    end
    if not pending then
      break
    end
    if os.time() > deadline then
      for _, a in ipairs(active) do
        _cleanup_lane(a.paths)
      end
      error("parallel lanes timed out after " .. tostring(_PHASE_TIMEOUT) .. "s")
    end
    _sleep(0.3)
  end

  local all_ok = true
  local results = {}

  for _, a in ipairs(active) do
    local status_code = _read_status(a.paths.status)
    local output = common.read_file(a.paths.output)
    local success = status_code == 0

    if output and output ~= "" then
      io.write(output)
      if output:sub(-1) ~= "\n" then
        io.write("\n")
      end
    end

    results[#results + 1] = { label = a.label, ok = success }
    if not success then
      all_ok = false
    end

    _cleanup_lane(a.paths)
  end

  local elapsed = math.max(0, os.time() - started)
  io.write(string.format(
    "[verify-full] %s parallel  %ds\n", all_ok and "PASS" or "FAIL", elapsed
  ))
  io.flush()

  return all_ok, results
end

local function _main(opts)
  opts = opts or {}
  local include_tooling = opts.tooling == true
  local include_coverage = opts.coverage ~= false

  local started = os.time()
  local passed = {}
  local failed = {}
  local skipped = {}

  if _check_command("luacheck") then
    if _run_step("lint", "lua tools/quality/lint.lua") then
      passed[#passed + 1] = "lint"
    else
      failed[#failed + 1] = "lint"
    end
  else
    skipped[#skipped + 1] = "lint"
  end

  if _run_step("encoding", "lua tools/quality/encoding.lua check") then
    passed[#passed + 1] = "encoding"
  else
    failed[#failed + 1] = "encoding"
  end

  if _run_step("behavior", "lua spec/support/behavior_parallel.lua") then
    passed[#passed + 1] = "behavior"
  else
    failed[#failed + 1] = "behavior"
  end

  local lanes = {
    { label = "contract", cmd = "busted --run contract" },
    { label = "guards", cmd = "busted --run guards" },
    { label = "arch", cmd = "lua tools/quality/arch.lua check" },
  }
  if include_tooling then
    lanes[#lanes + 1] = {
      label = "tooling",
      cmd = "lua spec/support/behavior_parallel.lua --root spec/tooling",
    }
  end

  local _, results = _run_parallel(lanes)
  for _, r in ipairs(results) do
    if r.ok then
      passed[#passed + 1] = r.label
    else
      failed[#failed + 1] = r.label
    end
  end

  if _run_step("crap", "lua tools/quality/crap.lua report --lane behavior --out tmp/crap_report.json") then
    passed[#passed + 1] = "crap"
  else
    failed[#failed + 1] = "crap"
  end

  if include_coverage then
    if _check_command("lua5.5") then
      if _run_step("coverage", "lua5.5 tools/quality/coverage.lua --out tmp/coverage.md") then
        passed[#passed + 1] = "coverage"
      else
        failed[#failed + 1] = "coverage"
      end
    else
      skipped[#skipped + 1] = "coverage"
    end
  end

  local elapsed = math.max(0, os.time() - started)
  local all_ok = #failed == 0

  io.write(string.format(
    "\n[verify-full] %s  passed=%d failed=%d skipped=%d  %ds\n",
    all_ok and "PASS" or "FAIL",
    #passed, #failed, #skipped, elapsed
  ))
  if #failed > 0 then
    io.write("[verify-full] failed: " .. table.concat(failed, ", ") .. "\n")
  end
  if #skipped > 0 then
    io.write("[verify-full] skipped: " .. table.concat(skipped, ", ") .. "\n")
  end
  io.flush()

  return { ok = all_ok, passed = passed, failed = failed, skipped = skipped }
end

if arg and arg[0] and arg[0]:find("verify_full", 1, true) then
  local opts = {}
  for i = 1, #arg do
    if arg[i] == "--tooling" then
      opts.tooling = true
    elseif arg[i] == "--no-coverage" then
      opts.coverage = false
    end
  end
  local result = _main(opts)
  os.exit(result.ok and 0 or 1)
end

return { run = _main }
