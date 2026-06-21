require("spec.bootstrap").install_package_paths()

local common = require("shared.lib.common")
local number_utils = require("src.foundation.number")
local parallel_lanes = require("shared.lib.parallel_lanes")

local _PHASE_TIMEOUT = 600

local function _env_value(name)
  local value = os.getenv(name)
  if value == nil or value == "" then
    return nil
  end
  return value
end

local function _check_command(name)
  return common.command_exists(name)
end

local function _path_or_command_available(value)
  local text = tostring(value or "")
  if text == "" then
    return false
  end
  if text:find("[/\\]") ~= nil or text:match("^%a:") ~= nil then
    return common.path_exists(text)
  end
  return common.command_exists(text)
end

local function _lua_reports_54(candidate)
  local result = common.run_command({ candidate, "-v" })
  return result.ok == true and tostring(result.output or ""):find("Lua 5%.4") ~= nil
end

local _LUA54_BIN_CANDIDATES = {
  "/opt/homebrew/bin/lua5.4",
  "/usr/local/bin/lua5.4",
  "/opt/homebrew/opt/lua@5.4/bin/lua5.4",
  "/usr/local/opt/lua@5.4/bin/lua5.4",
  "lua5.4",
  "lua54",
  "lua",
}

local function _resolve_lua54()
  local override = _env_value("LUA54_BIN")
  if override ~= nil then
    return override
  end
  for _, candidate in ipairs(_LUA54_BIN_CANDIDATES) do
    if _path_or_command_available(candidate) and _lua_reports_54(candidate) then
      return candidate
    end
  end
  return nil
end

local function _home_busted_candidates()
  local candidates = {}
  for _, env_name in ipairs({ "HOME", "USERPROFILE" }) do
    local home = _env_value(env_name)
    if home ~= nil then
      candidates[#candidates + 1] = common.join_path(home, ".luarocks/bin/busted")
    end
  end
  candidates[#candidates + 1] = "/opt/homebrew/bin/busted"
  return candidates
end

local function _resolve_busted54()
  local override = _env_value("BUSTED54_BIN") or _env_value("BUSTED_BIN")
  if override ~= nil then
    return override
  end
  for _, candidate in ipairs(_home_busted_candidates()) do
    if common.path_exists(candidate) then
      return candidate
    end
  end
  if common.command_exists("busted") then
    return "busted"
  end
  return "busted"
end

local function _rock_installed(name)
  if not common.command_exists("luarocks") then
    return false
  end
  local result = common.run_command({ "luarocks", "--lua-version=5.4", "list", "--porcelain", name })
  return result.ok == true and tostring(result.output or ""):find("^" .. name .. "%s") ~= nil
end

local function _coverage_toolchain_available(lua54_bin, busted_bin)
  if lua54_bin == nil then
    return false
  end
  local busted_available = _path_or_command_available(busted_bin)
    or _env_value("BUSTED54_BIN") ~= nil
    or _env_value("BUSTED_BIN") ~= nil
    or _rock_installed("busted")
  local luacov_available = _path_or_command_available(_env_value("LUACOV_BIN"))
    or common.command_exists("luacov")
    or _rock_installed("luacov")
  return busted_available and luacov_available
end

local function _run_step(label, cmd)
  local paths = {
    output = common.make_temp_path("vf_step_" .. label .. "_out", ".txt"),
  }
  local redirected = cmd .. " > " .. common.shell_quote(paths.output) .. " 2>&1"
  local started = os.time()
  local ok, _, code = os.execute(redirected)
  local elapsed = math.max(0, os.time() - started)
  local success = ok == true and (code == nil or code == 0)
  if not success and number_utils.is_numeric(code) then
    success = code == 0
  end
  local output = common.read_file(paths.output) or ""
  common.remove_path(paths.output)
  return { label = label, ok = success, elapsed = elapsed, output = output }
end

-- 启动 + 调度 + 输出聚合委托给 shared.lib.parallel_lanes（曾经在这里复制粘贴一份）。
-- stream=false 维持 architect 的"收集后选择性 emit"模型：success 路径压缩、
-- failure/verbose 路径全量打印，由下游 _build_output 处理。
local function _run_parallel(lanes)
  local started = os.time()
  local all_ok, lane_results = parallel_lanes.run(lanes, {
    stream = false,
    timeout = _PHASE_TIMEOUT,
  })
  local elapsed = math.max(0, os.time() - started)

  local results = {}
  for index, lane in ipairs(lane_results) do
    results[index] = {
      label = lane.label,
      ok = lane.ok,
      elapsed = nil,
      output = lane.output or "",
    }
  end
  return all_ok, results, elapsed
end

local function _build_output(input)
  input = input or {}
  local results = input.results or {}
  local skipped = input.skipped or {}
  local total_elapsed = input.total_elapsed or 0
  local verbose = input.verbose == true

  local passed, failed = {}, {}
  for _, r in ipairs(results) do
    if r.ok then
      passed[#passed + 1] = r.label
    else
      failed[#failed + 1] = r.label
    end
  end
  local all_ok = #failed == 0

  local buf = {}
  for _, r in ipairs(results) do
    local show_this = verbose or not r.ok
    if show_this then
      buf[#buf + 1] = string.format(
        "[verify] %s %s  %ds\n",
        r.ok and "PASS" or "FAIL", r.label, r.elapsed or 0
      )
      if r.output and r.output ~= "" then
        buf[#buf + 1] = r.output
        if r.output:sub(-1) ~= "\n" then
          buf[#buf + 1] = "\n"
        end
      end
    end
  end

  buf[#buf + 1] = string.format(
    "\n[verify] %s  passed=%d failed=%d skipped=%d  %ds\n",
    all_ok and "PASS" or "FAIL",
    #passed, #failed, #skipped, total_elapsed
  )
  if #skipped > 0 then
    buf[#buf + 1] = "[verify] skipped: " .. table.concat(skipped, ", ") .. "\n"
  end

  return {
    stdout = table.concat(buf),
    exit_code = all_ok and 0 or 1,
    passed = passed,
    failed = failed,
    skipped = skipped,
  }
end

local function _busted_lane_cmd(busted_bin, profile)
  return common.build_command({
    "lua",
    "tools/quality/busted_lane.lua",
    "--busted-bin",
    busted_bin or "busted",
    "--profile",
    profile,
  })
end

local function _add_lint_or_skip(lanes, skipped, env)
  if env.luacheck_available == true and env.lua54_bin then
    lanes[#lanes + 1] = {
      label = "lint",
      cmd = common.build_command({ env.lua54_bin, "tools/quality/lint.lua" }),
    }
  else
    skipped[#skipped + 1] = "lint"
  end
end

local function _smoke_lanes(env, warnings, tooling_requested)
  local lanes, skipped = {}, {}
  if tooling_requested then
    warnings[#warnings + 1] =
      "--smoke overrides --tooling; smoke profile does not run the tooling lane"
  end
  lanes[#lanes + 1] = { label = "arch", cmd = "lua tools/quality/arch.lua check" }
  lanes[#lanes + 1] = { label = "behavior-smoke", cmd = _busted_lane_cmd(env.busted_bin, "behavior-smoke") }
  lanes[#lanes + 1] = { label = "contract", cmd = _busted_lane_cmd(env.busted_bin, "contract") }
  lanes[#lanes + 1] = { label = "encoding", cmd = "lua tools/quality/encoding.lua check" }
  lanes[#lanes + 1] = { label = "guards", cmd = _busted_lane_cmd(env.busted_bin, "guards") }
  _add_lint_or_skip(lanes, skipped, env)
  return lanes, skipped
end

-- ADR 0006 D1 (Option C, specifier-decided): behavior and crap_collect run
-- in parallel. behavior keeps spec/log_warns_handler.lua's warn-summary
-- diagnostic in verify_full output; crap_collect produces the coverage data
-- the post-parallel analyze step turns into crap_report.json without
-- re-running the 2305 tests sequentially.
local function _default_lanes(env, include_tooling, include_coverage)
  local lanes, skipped = {}, {}
  lanes[#lanes + 1] = { label = "contract", cmd = _busted_lane_cmd(env.busted_bin, "contract") }
  lanes[#lanes + 1] = { label = "guards", cmd = _busted_lane_cmd(env.busted_bin, "guards") }
  lanes[#lanes + 1] = { label = "arch", cmd = "lua tools/quality/arch.lua check" }
  lanes[#lanes + 1] = { label = "behavior", cmd = "lua spec/support/behavior_parallel.lua" }
  lanes[#lanes + 1] = {
    label = "crap_collect",
    cmd = "lua tools/quality/crap.lua collect --lane behavior --out tmp/crap_collect.json",
  }
  _add_lint_or_skip(lanes, skipped, env)
  lanes[#lanes + 1] = { label = "encoding", cmd = "lua tools/quality/encoding.lua check" }
  if include_tooling then
    lanes[#lanes + 1] = {
      label = "tooling",
      cmd = "lua spec/support/behavior_parallel.lua --profile tooling",
    }
  end
  -- Coverage runs alongside the other lanes: it re-runs busted under luacov
  -- in a separate lua5.4 process with its own stats files (luacov.<profile>.stats.out),
  -- so it shares no mutable state with the non-coverage lanes. Wall time is
  -- bounded by the slower of (parallel lanes, coverage), not their sum.
  if include_coverage then
    if env.lua54_bin and env.coverage_available ~= false then
      lanes[#lanes + 1] = {
        label = "coverage",
        cmd = common.build_command({
          env.lua54_bin,
          "tools/quality/coverage.lua",
          "--quiet",
          "--out",
          "tmp/coverage.md",
        }),
      }
    else
      skipped[#skipped + 1] = "coverage"
    end
  end
  return lanes, skipped
end

local function _resolve_lanes(opts)
  opts = opts or {}
  local env = opts.env or {}
  local warnings = {}
  if opts.smoke == true then
    local lanes, skipped = _smoke_lanes(env, warnings, opts.tooling == true)
    return { lanes = lanes, skipped = skipped, warnings = warnings }
  end
  local include_coverage = opts.coverage ~= false
  local lanes, skipped = _default_lanes(env, opts.tooling == true, include_coverage)
  return { lanes = lanes, skipped = skipped, warnings = warnings }
end

local function _lanes_have(lanes, label)
  for _, lane in ipairs(lanes) do
    if lane.label == label then return true end
  end
  return false
end

local function _main(opts)
  opts = opts or {}
  local verbose = opts.verbose == true

  local started = os.time()
  local passed = {}
  local failed = {}

  local env = {
    lua54_bin = _resolve_lua54(),
    busted_bin = _resolve_busted54(),
    luacheck_available = _check_command("luacheck"),
  }
  env.coverage_available = _coverage_toolchain_available(env.lua54_bin, env.busted_bin)

  local plan = _resolve_lanes({
    smoke = opts.smoke,
    tooling = opts.tooling,
    coverage = opts.coverage,
    env = env,
  })

  for _, w in ipairs(plan.warnings) do
    io.write("[verify] warning: " .. w .. "\n")
  end
  io.flush()

  local _, parallel_results, parallel_elapsed = _run_parallel(plan.lanes)
  local all_results = {}
  for _, r in ipairs(parallel_results) do
    r.elapsed = r.elapsed or parallel_elapsed
    all_results[#all_results + 1] = r
  end

  if _lanes_have(plan.lanes, "crap_collect") then
    all_results[#all_results + 1] = _run_step(
      "crap",
      "lua tools/quality/crap_analyze.lua --in tmp/crap_collect.json --out tmp/crap_report.json"
    )
    -- Complexity-aware CRAP ratchet: fails only on new violations beyond the
    -- committed baseline (tools/quality/crap/crap_gate_baseline.lua).
    all_results[#all_results + 1] = _run_step(
      "crap_gate",
      "lua tools/quality/crap_gate.lua --in tmp/crap_collect.json"
    )
  end

  local elapsed = math.max(0, os.time() - started)

  local output = _build_output({
    results = all_results,
    skipped = plan.skipped,
    total_elapsed = elapsed,
    verbose = verbose,
  })

  io.write(output.stdout)
  io.flush()

  for _, r in ipairs(all_results) do
    if r.ok then
      passed[#passed + 1] = r.label
    else
      failed[#failed + 1] = r.label
    end
  end

  return { ok = output.exit_code == 0, passed = passed, failed = failed, skipped = plan.skipped }
end

local M = {
  run = _main,
  build_output = _build_output,
  _resolve_lanes = _resolve_lanes,
  _coverage_toolchain_available = _coverage_toolchain_available,
}

if ... == "quality.verify_full" then
  return M
end

local opts = {}
for i = 1, #(arg or {}) do
  if arg[i] == "--tooling" then
    opts.tooling = true
  elseif arg[i] == "--no-coverage" then
    opts.coverage = false
  elseif arg[i] == "--verbose" then
    opts.verbose = true
  elseif arg[i] == "--smoke" then
    opts.smoke = true
  end
end
local result = _main(opts)
os.exit(result.ok and 0 or 1)
