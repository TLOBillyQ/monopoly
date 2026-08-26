-- packages/verify/main.lua —— verify 门禁编排器入口(wayfinder #307 包迁,
-- 原 tools/quality/verify_full.lua)。双重形态:被 require 时返回模块
-- (测试拿 build_output / _resolve_lanes 断言),被 `lua tools/cli.lua verify`
-- 经包内 cli.lua 子进程 spawn 时解析 flag 并 os.exit。
require("test.bootstrap").install_package_paths()

local fs_lib = require("foundation.fs")
local proc_lib = require("foundation.proc")
local runner_bin = require("packages.luaunit_runner.lua54")
local lanes_mod = require("packages.verify.lanes")
local runner = require("packages.verify.runner")

local function _check_command(name)
  return proc_lib.command_exists(name)
end

-- lua5.4 探测(候选表 + `<candidate> -v` 验证 + 记忆化)原先在这里有一份逐字副本,
-- 与 packages.luaunit_runner.lua54 靠"同口径"的注释手工同步。归一到
-- lua54.detect_lua54():探不到返回 nil,正是这里判定 coverage 车道能否开所需要的语义。
local function _resolve_lua54()
  return runner_bin.detect_lua54()
end

-- 覆盖率车道跑在 luacov.runner 下，luacov 经上游 rockspec 硬钉并从
-- rockspec 依赖装入 .toolcache/luarocks tree。可用性 = lua5.4 解释器解析到
-- (spec 与 Eggy 宿主同版本)+ luacov 在 tree(coverage.lua 车道入口会 ensure)。
local function _coverage_toolchain_available(lua54_bin)
  return lua54_bin ~= nil
    and fs_lib.path_exists(".toolcache/luarocks/share/lua/5.4/luacov/runner.lua") == true
end

-- crap 的两步(analyze + gate)在并行车道跑完后串行补跑:它们吃的是 crap_collect
-- 落下的 json,必须等那条车道结束。
local function _run_crap_steps(results)
  results[#results + 1] = runner.run_step(
    "crap",
    "lua tools/packages/coverage/crap_analyze.lua --in tmp/crap_collect.json --out tmp/crap_report.json"
  )
  -- Flat CRAP gate: fails on any function scoring above the configured
  -- threshold. No baseline, no per-file budget, no complexity exemption.
  results[#results + 1] = runner.run_step(
    "crap_gate",
    "lua tools/packages/coverage/crap_gate.lua --in tmp/crap_collect.json"
  )
end

local function _main(opts)
  opts = opts or {}
  local started = os.time()

  local env = {
    lua54_bin = _resolve_lua54(),
    luacheck_available = _check_command("luacheck"),
  }
  env.coverage_available = _coverage_toolchain_available(env.lua54_bin)

  local plan = lanes_mod.resolve({
    tooling = opts.tooling,
    coverage = opts.coverage,
    crap = opts.crap,
    full = opts.full,
    env = env,
  })

  for _, w in ipairs(plan.warnings) do
    io.write("[verify] warning: " .. w .. "\n")
  end
  io.flush()

  local _, parallel_results, parallel_elapsed = runner.run_parallel(plan.lanes)
  local all_results = {}
  for _, r in ipairs(parallel_results) do
    r.elapsed = r.elapsed or parallel_elapsed
    all_results[#all_results + 1] = r
  end

  if lanes_mod.have(plan.lanes, "crap_collect") then
    _run_crap_steps(all_results)
  end

  local output = runner.build_output({
    results = all_results,
    skipped = plan.skipped,
    total_elapsed = math.max(0, os.time() - started),
    verbose = opts.verbose == true,
  })

  io.write(output.stdout)
  io.flush()

  return {
    ok = output.exit_code == 0,
    passed = output.passed,
    failed = output.failed,
    skipped = plan.skipped,
  }
end

local M = {
  run = _main,
  build_output = runner.build_output,
  _resolve_lanes = lanes_mod.resolve,
  _coverage_toolchain_available = _coverage_toolchain_available,
}

if ... == "packages.verify.main" then
  return M
end

local opts = {}
for i = 1, #(arg or {}) do
  if arg[i] == "--tooling" then
    opts.tooling = true
  elseif arg[i] == "--no-coverage" then
    -- Silent no-op; coverage is already opt-out by default.
    opts.coverage = false
  elseif arg[i] == "--coverage" then
    opts.coverage = true
  elseif arg[i] == "--crap" then
    opts.crap = true
  elseif arg[i] == "--full" then
    opts.full = true
  elseif arg[i] == "--verbose" then
    opts.verbose = true
  else
    io.stderr:write("unknown flag: " .. tostring(arg[i]) .. "\n")
    os.exit(2)
  end
end
local result = _main(opts)
os.exit(result.ok and 0 or 1)
