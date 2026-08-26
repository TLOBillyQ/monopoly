#!/usr/bin/env lua
local function _normalize_path(path)
  return tostring(path or ""):gsub("\\", "/")
end
local function _module_dir()
  local source = debug.getinfo(1, "S").source or "@tools/packages/spec_lane/spec_lane.lua"
  return _normalize_path(source):gsub("^@", ""):match("^(.*)/[^/]+$") or "tools/packages/spec_lane"
end

local bootstrap = dofile(_module_dir() .. "/../../foundation/bootstrap.lua")
local bootstrap_env = bootstrap.install((arg and arg[0]) or debug.getinfo(1, "S").source)

local fs_lib = require("foundation.fs")
local proc_lib = require("foundation.proc")
local shell_lib = require("foundation.shell")
local tap_summary = require("foundation.tap_summary")
local parallel_lanes = require("foundation.parallel_lanes")
local sharding = require("packages.luaunit_runner.spec_sharding")
local lane_args = require("packages.spec_lane.spec_lane_args")
local lane_tools = require("packages.spec_lane.spec_lane_tools")
local runner_bin = require("packages.luaunit_runner.lua54")

local M = {}

-- 内置文件分片（与 behavior_parallel / coverage 共用 tools/packages/luaunit_runner）：
-- 命名 profile 的文件数超过阈值时,按文件边界拆成 N 条 runner 子进程 lane
-- 并行（不拆文件内顺序）；窄目录点跑（--profile <目录>）、文件数少、
-- worker=1、--verbose 一律走原单进程路径,命令形态逐字节不变。
-- 阈值 20:tooling(42+ 文件)与 contract(22 文件)分片受益;guards(11 文件)
-- 保持串行——其耗时 93% 集中在 test_guard_runner / test_dep_rules 两个动态
-- 生成套件文件,静态 file_cost 失真使 LPT 拆不动、分片反而付轮询税(实测
-- 3.74s -> 4.10s 微回归,见 test_spec_lane 注释)。
local _SHARD_THRESHOLD = 20
local _DEFAULT_WORKERS = 3

-- profile -> 发现根:命名 profile 取 spec_profiles.lua 的 ROOT;目录点跑就是
-- 目录本身;两者都不是(未知 profile)返回 nil,交给串行路径让 runner 报错。
local function _profile_roots(profile)
  if fs_lib.is_dir(profile) then
    return { profile }
  end
  local profiles = dofile("tools/packages/spec_lane/spec_profiles.lua")
  local config = profiles[profile]
  if config == nil then
    return nil
  end
  return config.ROOT or {}
end

-- 分片 lane 需要 profile 的 helper/pattern(显式传参,与串行 `--run <profile>`
-- 让 runner 解析的取值同源——都是 spec_profiles.lua)。
local function _profile_config(profile)
  local profiles = dofile("tools/packages/spec_lane/spec_profiles.lua")
  local config = profiles[profile]
  if type(config) ~= "table" then
    return {}
  end
  return config
end

-- 发现口径与 runner 的 `--run` 逐字节等价(collect_files + basename 子串匹配
-- pattern)。仍保留本地实现而不用 discover_spec_files:那里 pattern 写死
-- test_,这里按 profile 取(值仍同源——都是 spec_profiles.lua)。
-- 分片只拆文件边界、不拆文件内顺序(LPT 纪律)。
local function _discover_files(roots, pattern)
  local files = {}
  local seen = {}
  for _, root in ipairs(roots or {}) do
    local discovered = proc_lib.collect_files(root, ".lua")
    for _, path in ipairs(discovered or {}) do
      local base = path:match("([^/\\]+)%.lua$")
      if base ~= nil and base:find(pattern) ~= nil and not seen[path] then
        files[#files + 1] = path
        seen[path] = true
      end
    end
  end
  table.sort(files)
  return files
end

-- worker 数:options.workers 显式覆写(测试注入用);否则 EGGY_SPEC_LANE_WORKERS
-- 环境变量(语义对齐 EGGY_BEHAVIOR_WORKERS / EGGY_COVERAGE_WORKERS),默认 3,
-- clamp 到文件数、下限 1。
local function _resolve_workers(file_count, options)
  if options ~= nil and options.workers ~= nil then
    return math.max(1, options.workers)
  end
  return sharding.resolve_workers("EGGY_SPEC_LANE_WORKERS", file_count, _DEFAULT_WORKERS)
end

-- 分片 lane 命令(behavior_parallel 同款形态):--output=TAP 是 spec_lane 的
-- 固定契约,helper/pattern 从 profile config 取值,`--` 后是显式文件清单。
local function _build_shard_cmd(profile, files)
  local cfg = _profile_config(profile)
  local args = {}
  for _, token in ipairs(runner_bin.argv_prefix()) do
    args[#args + 1] = token
  end
  args[#args + 1] = "--output=TAP"
  if cfg.helper ~= nil then
    args[#args + 1] = "--helper=" .. cfg.helper
  end
  args[#args + 1] = "--pattern=" .. (cfg.pattern or "test_")
  args[#args + 1] = "--"
  for _, f in ipairs(files) do
    args[#args + 1] = f
  end
  return shell_lib.build_command(args)
end

-- 分片路径:每 lane 一条 runner 子进程(run_lanes 注入替身,默认 parallel_lanes,
-- stream=false 收集),按 lane 顺序聚合各 worker 的 TAP 后整段交给
-- tap_summary.compress —— 计数(ok N / not ok N)与失败明细口径和串行路径
-- 一致,ok 编号跨 worker 重排不影响计数。任何 lane 非零退出都算失败
-- (与串行 result.code 语义对齐)。
local function _run_sharded(options, profile, files)
  local run_lanes = options.run_lanes or parallel_lanes.run
  local worker_count = _resolve_workers(#files, options)
  local lane_specs = {}
  for _, lane in ipairs(sharding.build_lpt_lanes(files, worker_count)) do
    if #lane.files > 0 then
      lane_specs[#lane_specs + 1] = {
        label = profile .. "_w" .. tostring(lane.index),
        cmd = _build_shard_cmd(profile, lane.files),
      }
    end
  end

  local _, results = run_lanes(lane_specs, { stream = false })

  local raw_parts = {}
  local code = 0
  for _, r in ipairs(results) do
    if not r.ok then
      code = 1
    end
    local out = tostring(r.output or ""):gsub("%s+$", "")
    if out ~= "" then
      raw_parts[#raw_parts + 1] = out
    end
  end
  local compressed, passed, failed = M.compress_tap(table.concat(raw_parts, "\n"))
  if failed > 0 and code == 0 then
    code = 1
  end
  return { stdout = compressed, code = code, passed = passed, failed = failed }
end

function M.parse_args(args)
  return lane_args.parse(args)
end

function M.compress_tap(output)
  return tap_summary.compress(output)
end

function M.run(options)
  options = options or {}
  local ok_tools, tool_err = lane_tools.ensure_for_profile(options.profile, bootstrap, bootstrap_env)
  if ok_tools == nil then
    return { stdout = tostring(tool_err) .. "\n", code = 1, passed = 0, failed = 1 }
  end

  -- 默认后端 = LuaUnit 运行器(argv_prefix 返回 { lua5.4, runner.lua },
  -- tools/packages/luaunit_runner）。--busted-bin / BUSTED_BIN 已删除，
  -- PATH 无 busted,迁移已完成)。
  local prefix = runner_bin.argv_prefix()
  local run_command = options.run_command or proc_lib.run_command

  -- 分片判定:命名 profile(非目录窄点跑)、文件数超阈值、worker > 1、非
  -- --verbose 才走并行;否则原单进程路径。
  local roots = _profile_roots(options.profile)
  local files = {}
  if roots ~= nil then
    files = _discover_files(roots, _profile_config(options.profile).pattern or "test_")
  end
  local shardable = roots ~= nil
    and fs_lib.is_dir(options.profile) ~= true
    and #files > _SHARD_THRESHOLD
    and _resolve_workers(#files, options) > 1
    and options.verbose ~= true

  if not shardable then
    local command = {}
    for _, token in ipairs(prefix) do
      command[#command + 1] = token
    end
    command[#command + 1] = "--output=TAP"
    command[#command + 1] = "--run"
    command[#command + 1] = options.profile
    local result = run_command(command)
    local raw = tostring(result.output or "")

    if options.verbose then
      return { stdout = raw, code = result.code or (result.ok and 0 or 1), passed = 0, failed = 0 }
    end

    local compressed, passed, failed = M.compress_tap(raw)
    local code = result.code or (result.ok and 0 or 1)
    if failed > 0 and code == 0 then
      code = 1
    end
    return { stdout = compressed, code = code, passed = passed, failed = failed }
  end

  return _run_sharded(options, options.profile, files)
end

function M.main(args)
  local options, err = M.parse_args(args)
  if not options then
    io.stderr:write(lane_args.usage())
    io.stderr:write(tostring(err) .. "\n")
    return 2
  end
  if options.help then
    io.write(lane_args.usage())
    return 0
  end
  local result = M.run(options)
  io.write(result.stdout)
  return result.code
end

if ... == "packages.spec_lane.spec_lane" then
  return M
end

os.exit(M.main(arg or {}))
