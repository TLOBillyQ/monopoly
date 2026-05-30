require("spec.bootstrap").install_package_paths()

local common = require("shared.lib.common")
local number_utils = require("src.foundation.number")
local parallel_lanes = require("shared.lib.parallel_lanes")

local _PHASE_TIMEOUT = 600

local function _which(name)
  local handle = io.popen("command -v " .. common.shell_quote(name) .. " 2>/dev/null")
  if handle == nil then
    return nil
  end
  local result = handle:read("*a")
  handle:close()
  if result == nil or result == "" then
    return nil
  end
  return (result:gsub("%s+$", ""))
end

local function _check_command(name)
  return _which(name) ~= nil
end

local function _resolve_binary(env_var, candidates, fallback_fn)
  local override = os.getenv(env_var)
  if override ~= nil and override ~= "" then
    return override
  end
  for _, candidate in ipairs(candidates) do
    if common.path_exists(candidate) then
      return candidate
    end
  end
  return fallback_fn()
end

local _LUA54_BIN_CANDIDATES = {
  "/opt/homebrew/bin/lua5.4",
  "/usr/local/bin/lua5.4",
  "/opt/homebrew/opt/lua@5.4/bin/lua5.4",
  "/usr/local/opt/lua@5.4/bin/lua5.4",
}

local function _resolve_lua54()
  return _resolve_binary("LUA54_BIN", _LUA54_BIN_CANDIDATES, function()
    return _which("lua5.4")
  end)
end

local _BUSTED54_BIN_CANDIDATES = {
  os.getenv("HOME") .. "/.luarocks/bin/busted",
  "/opt/homebrew/bin/busted",
}

local function _resolve_busted54()
  return _resolve_binary("BUSTED54_BIN", _BUSTED54_BIN_CANDIDATES, function()
    return "busted"
  end)
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
  return "BUSTED_BIN=" .. common.shell_quote(busted_bin)
    .. " lua tools/quality/busted_lane.lua --profile " .. common.shell_quote(profile)
end

local function _add_lint_or_skip(lanes, skipped, env)
  if env.luacheck_available == true and env.lua54_bin then
    lanes[#lanes + 1] = {
      label = "lint",
      cmd = common.shell_quote(env.lua54_bin) .. " tools/quality/lint.lua",
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
    if env.lua54_bin then
      lanes[#lanes + 1] = {
        label = "coverage",
        cmd = common.shell_quote(env.lua54_bin)
          .. " tools/quality/coverage.lua --quiet --out tmp/coverage.md",
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

local M = { run = _main, build_output = _build_output, _resolve_lanes = _resolve_lanes }

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
