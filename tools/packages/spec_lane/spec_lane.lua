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

local env_lib = require("foundation.env")
local fs_lib = require("foundation.fs")
local proc_lib = require("foundation.proc")
local tap_summary = require("foundation.tap_summary")
local tool_availability = require("foundation.tool_availability")
local parallel_lanes = require("foundation.parallel_lanes")
local sharding = require("foundation.spec_sharding")
local lane_args = require("packages.spec_lane.spec_lane_args")
local lane_tools = require("packages.spec_lane.spec_lane_tools")
local runner_bin = require("packages.test_runner.lua54")

local M = {}

-- 内置文件分片（与 behavior_parallel 共用 packages/test_runner）：
-- 命名 profile 的文件数超过阈值时,按文件边界拆成 N 条 runner 子进程 lane
-- 并行（不拆文件内顺序）；窄目录点跑（--profile <目录>）、文件数少、
-- worker=1、--verbose、--serial 一律走原单进程路径,命令形态逐字节不变。
-- CLI 默认分片并行(#107 恢复;#73 迁移期安全网曾默认 --serial):实测
-- behavior 45.8s → 18.5s、tooling 230.1s → 85.5s(w=3,热时长缓存)。阈值 30:
-- 每 lane 收容进程固定开销约 3s,contract(22 文件)串行 4.0s / 分片 7.0s,
-- 保持串行;guards(17 文件)耗时集中在两个动态生成套件文件,分片拆不动。
local _SHARD_THRESHOLD = 30
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
        local verdict = require("foundation.platform_boundary").test_verdict(path)
        if verdict then
          io.write("[tooling] excluded status=unavailable file=" .. verdict.identity
            .. " cases=" .. verdict.cases .. " capability=acceptance-mutate reason=" .. verdict.entry.reason .. "\n")
        else files[#files + 1] = path end
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
-- 固定契约,helper/pattern 从 profile config 取值,durations_out 是本 lane
-- 实测时长落点,`--` 后是显式文件清单。
local function _build_shard_cmd(profile, files, durations_out)
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
  args[#args + 1] = "--durations-out=" .. durations_out
  args[#args + 1] = "--"
  for _, f in ipairs(files) do
    args[#args + 1] = f
  end
  return args
end

-- 实测时长缓存(#107):基线实测 tooling 按 it 计数分 3 lane 为 112.8/83.6/72.6s
-- 失衡(单文件 it 数与墙钟无关),改按上次实测秒数做 LPT。缓存落 .toolcache
-- (gitignored),键为仓库相对路径以跨 worktree 复用;首次运行无缓存仍按 it 计数。
-- 每 lane 经 runner --durations-out 落本次每文件秒数,跑完合并回缓存。
local function _cache_path(profile)
  return bootstrap_env.repo_root .. "/.toolcache/spec_durations/" .. profile .. ".tsv"
end

local function _repo_relative(file)
  local normalized = _normalize_path(file)
  local prefix = _normalize_path(bootstrap_env.repo_root) .. "/"
  if normalized:sub(1, #prefix):lower() == prefix:lower() then return normalized:sub(#prefix + 1) end
  return normalized
end

local function _read_durations(path)
  local durations = {}
  for file, seconds in pairs(sharding.parse_durations(fs_lib.read_raw(path))) do
    durations[_repo_relative(file)] = seconds
  end
  return durations
end

-- 缓存秒数映射到本次发现的文件路径;一个都没命中返回 nil(退回 it 计数)。
local function _load_durations(profile, files)
  local cached = _read_durations(_cache_path(profile))
  local durations, hit = {}, false
  for _, file in ipairs(files) do
    local seconds = cached[_repo_relative(file)]
    if seconds then durations[file], hit = seconds, true end
  end
  return hit and durations or nil
end

-- 合并只保留本次发现清单内的文件(已删/改名文件的旧条目随之淘汰);缓存
-- 写失败只告警,不改退出码——缓存只影响下次分配的均衡度,不影响正确性。
local function _merge_durations(profile, files, measured_paths)
  local cache = _cache_path(profile)
  local cached, current, merged, updated = _read_durations(cache), {}, {}, false
  for _, file in ipairs(files) do
    local key = _repo_relative(file)
    current[key], merged[key] = true, cached[key]
  end
  for _, out in ipairs(measured_paths) do
    for file, seconds in pairs(_read_durations(out)) do
      if current[file] then merged[file], updated = seconds, true end
    end
    fs_lib.remove_path(out)
  end
  if not updated then return end
  local ok, err = fs_lib.write_file(cache, sharding.format_durations(merged))
  if not ok then
    io.stderr:write("[spec-lane] warning: duration cache write failed: " .. tostring(err) .. "\n")
  end
end

-- 时长缓存让 lane 分配随运行变化;失败时打印本次 lane → 文件清单(执行顺序)。
local function _lane_listing(lane_specs)
  local lines = { "# lane 分配(执行顺序);复现请用 --serial 或按清单点跑:" }
  for _, spec in ipairs(lane_specs) do
    lines[#lines + 1] = spec.label .. ":"
    for _, file in ipairs(spec.files) do lines[#lines + 1] = "  " .. file end
  end
  return table.concat(lines, "\n") .. "\n"
end

-- 分片路径:每 lane 一条 runner 子进程(run_lanes 注入替身,默认 parallel_lanes,
-- stream=false 收集),按 lane 顺序聚合各 worker 的 TAP 后整段交给
-- tap_summary.compress —— 计数(ok N / not ok N)与失败明细口径和串行路径
-- 一致,ok 编号跨 worker 重排不影响计数。任何 lane 非零退出都算失败
-- (与串行 result.code 语义对齐)。
local function _run_sharded(options, profile, files)
  local run_lanes = options.run_lanes or parallel_lanes.run
  local worker_count = _resolve_workers(#files, options)
  local lane_specs, measured_paths = {}, {}
  for _, lane in ipairs(sharding.build_lpt_lanes(files, worker_count, _load_durations(profile, files))) do
    if #lane.files > 0 then
      local out = env_lib.make_temp_path("spec_durations", ".tsv")
      measured_paths[#measured_paths + 1] = out
      lane_specs[#lane_specs + 1] = {
        label = profile .. "_w" .. tostring(lane.index),
        cmd = _build_shard_cmd(profile, lane.files, out),
        files = lane.files,
      }
    end
  end

  local _, results = run_lanes(lane_specs, { stream = false })
  _merge_durations(profile, files, measured_paths)

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
  if code ~= 0 then
    compressed = compressed .. _lane_listing(lane_specs)
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
  -- 自举的网络类失败(#112)= 环境不可用:退 3、诊断写 stderr,不报 failed——
  -- 一个测试都没跑,不能被读成测试回归。ensure_tool 可注入以便测试。
  local ok_tools, tool_err, unavailable = lane_tools.ensure_for_profile(options.profile,
    options.ensure_tool or bootstrap.ensure_tool, bootstrap_env)
  if unavailable ~= nil then
    return { stdout = "", stderr = tool_availability.message(unavailable, "spec-lane"),
      code = unavailable.exit_code, status = unavailable.status, passed = 0, failed = 0 }
  end
  if ok_tools == nil then
    return { stdout = tostring(tool_err) .. "\n", code = 1, passed = 0, failed = 1 }
  end

  -- 默认后端 = 真实 busted 运行器(argv_prefix 返回 { lua5.4,
  -- tools/packages/test_runner/runner.lua }）。--busted-bin / BUSTED_BIN 已删除，
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
    and options.serial ~= true

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

    local compressed, passed, failed = M.compress_tap(raw)
    local code = result.code or (result.ok and 0 or 1)
    if (failed > 0 or passed == 0) and code == 0 then code = 1 end
    local counts = raw:match("# COUNTS: [^\r\n]+")
    return { stdout = options.verbose and raw or (compressed .. (counts and counts .. "\n" or "")),
      code = code, passed = passed, failed = failed, discovered = #files }
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
  if result.stderr ~= nil then
    io.stderr:write(result.stderr)
  end
  return result.code
end

if ... == "packages.spec_lane.spec_lane" then
  return M
end

os.exit(M.main(arg or {}))
