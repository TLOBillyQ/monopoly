#!/usr/bin/env lua

local function _normalize_path(path)
  return tostring(path or ""):gsub("\\", "/")
end
local function _module_dir()
  local source = debug.getinfo(1, "S").source or "@tools/packages/coverage/coverage.lua"
  return _normalize_path(source):gsub("^@", ""):match("^(.*)/[^/]+$") or "tools/packages/coverage"
end

local bootstrap = dofile(_module_dir() .. "/../../foundation/bootstrap.lua")
bootstrap.install((arg and arg[0]) or debug.getinfo(1, "S").source)

local env_lib = require("foundation.env")
local fs_lib = require("foundation.fs")
local path_lib = require("foundation.path")
local shell_lib = require("foundation.shell")
local text_lib = require("foundation.text")
local parallel_lanes = require("foundation.parallel_lanes")
local sharding = require("packages.luaunit_runner.spec_sharding")
-- 收集 lane 走项目 LuaUnit 运行器（argv_prefix 默认
-- { lua5.4, runner.lua }),runner `-c` 在 luacov.runner 下跑 spec、退出时落
-- per-shard stats;分片合并后由 luacov 原生 reporter 产 report.out。luacov 经
-- 上游 rockspec 依赖带入 luarocks tree,runner 与 reporter 都从 tree require。
local runner_bin = require("packages.luaunit_runner.lua54")

-- 单源 config 的绝对路径(coverage_config.lua 与本文件同层);per-lane 临时 config
-- dofile 它、只覆写 statsfile,使收集侧 include/exclude 单一真源(自研收集器决策 pt5)。
local function _coverage_config_path()
  local dir = _normalize_path(_module_dir())
  if dir:sub(1, 1) ~= "/" and not dir:match("^%a:") then
    dir = _normalize_path(env_lib.current_dir()):gsub("/+$", "") .. "/" .. dir
  end
  return dir .. "/coverage_config.lua"
end

-- 收集 lane 的命令前缀(argv_prefix 各 token shell-quote 后拼接)。
local function _spec_command_prefix()
  local parts = {}
  for _, token in ipairs(runner_bin.argv_prefix()) do
    parts[#parts + 1] = shell_lib.shell_quote(token)
  end
  return table.concat(parts, " ")
end

-- 收集 lane 的环境变量前缀:仅 LUACOV_CONFIG —— luacov.runner 由 runner `-c` 触发
-- init 时读它。lane 不发 LUACOV=1（那是 rock luacov 的旧信号），也不注
-- 入 luarocks 树的 LUA_PATH/LUA_CPATH —— 运行器 install_eggy_package_paths 自举
-- 全套仓内路径,luacov 由 runner 在 require 前确保 tree 就绪。
local function _coverage_env_prefix(config_path)
  return "LUACOV_CONFIG=" .. shell_lib.shell_quote(config_path)
end

-- Profile -> spec root. Sharded profiles run as N parallel coverage lanes (one
-- per shard) instead of a single lane, each writing its own stats file. Total
-- wall is bounded by the slowest shard rather than the full lane.
local _SHARDED_PROFILES = { behavior = "test/behavior" }
-- EGGY_COVERAGE_WORKERS overrides; baseline came from a 1/3/6/8 sweep on
-- this machine (187 behavior specs): 6 was the knee — 3 still serial-bound,
-- 8 paid scheduler/process overhead without wall reduction.
local _DEFAULT_COVERAGE_WORKERS = 6

local function print_stderr(msg)
  io.stderr:write(msg .. "\n")
end

local _DEFAULT_TRACE_SINK = function(msg) io.stdout:write(tostring(msg) .. "\n") end
local _trace_sink = _DEFAULT_TRACE_SINK

local function _trace(quiet, msg)
  if not quiet then
    _trace_sink(msg)
  end
end

local function _set_trace_sink_for_tests(sink)
  _trace_sink = sink or _DEFAULT_TRACE_SINK
end

local function parse_args(args)
  local result = {
    threshold = 90,
    out = "tmp/coverage.md",
    profiles = { "behavior", "contract" },
    quiet = false,
  }

  for _, arg in ipairs(args) do
    local threshold_match = arg:match("^%-%-threshold=(.+)$")
    if threshold_match then
      result.threshold = tonumber(threshold_match) or 90
    end

    local out_match = arg:match("^%-%-out=(.+)$")
    if out_match then
      result.out = out_match
    end

    local profiles_match = arg:match("^%-%-profiles=(.+)$")
    if profiles_match then
      result.profiles = text_lib.split(profiles_match, ",")
    end

    if arg == "--quiet" then
      result.quiet = true
    end

    if arg == "--reuse-stats" then
      result.reuse_stats = true
    end
  end

  return result
end

local function delete_stale_files()
  fs_lib.ensure_dir("build")
  local files = { "build/luacov.stats.out", "build/luacov.report.out" }
  for _, file in ipairs(files) do
    if fs_lib.path_exists(file) then
      local ok, err = fs_lib.remove_path(file)
      if not ok then
        print_stderr("Warning: failed to delete " .. file .. ": " .. tostring(err))
      end
    end
  end
end

local function _profile_stats_path(profile)
  return "build/luacov." .. profile .. ".stats.out"
end

local function _shard_statsfile(profile, shard_index)
  return string.format("build/luacov.%s_w%d.stats.out", profile, shard_index)
end

local function _resolve_coverage_workers(file_count)
  return sharding.resolve_workers("EGGY_COVERAGE_WORKERS", file_count, _DEFAULT_COVERAGE_WORKERS)
end

-- 单源 config 派生:dofile coverage_config.lua、只覆写 statsfile(可选去掉
-- includeuntestedfiles,供 reporter 的 lfs 缺失降级)。include/exclude 等口径字段
-- 一律来自单源,收集侧不再重复真源(自研收集器决策 pt5)。
local function _build_luacov_config(opts)
  opts = opts or {}
  local statsfile = opts.statsfile or "build/luacov.stats.out"
  local with_untested = opts.with_untested ~= false

  local parts = {
    "local cfg = dofile(" .. string.format("%q", _coverage_config_path()) .. ")",
    "cfg.statsfile = " .. string.format("%q", statsfile),
  }
  if not with_untested then
    parts[#parts + 1] = "cfg.includeuntestedfiles = nil"
  end
  parts[#parts + 1] = "return cfg"
  parts[#parts + 1] = ""

  return table.concat(parts, "\n")
end

local function _write_profile_luacov_config(profile)
  local config_path = env_lib.make_temp_path("luacov_" .. profile, ".lua")
  local content = _build_luacov_config({ statsfile = _profile_stats_path(profile) })
  local ok, err = fs_lib.write_file(config_path, content)
  if not ok then
    return nil, err
  end
  return config_path
end

local function _write_shard_luacov_config(profile, shard_index)
  local config_path = env_lib.make_temp_path(
    "luacov_" .. profile .. "_w" .. tostring(shard_index), ".lua"
  )
  local content = _build_luacov_config({
    statsfile = _shard_statsfile(profile, shard_index),
  })
  local ok, err = fs_lib.write_file(config_path, content)
  if not ok then
    return nil, err
  end
  return config_path
end

local function _build_profile_lane(profile, config_path)
  local cmd = table.concat({
    _coverage_env_prefix(config_path),
    _spec_command_prefix(),
    "-c", "--run", profile,
  }, " ")
  return { label = profile, cmd = cmd }
end

local function _build_shard_lane(profile, shard_index, config_path, files)
  -- Sort lane files alphabetically so within-shard execution order matches
  -- the runner's recursive walk of the spec tree. LPT picks which files go to
  -- which shard by descending cost, but once a shard is fixed we want its
  -- files to run in the same relative order they would in a monolithic run
  -- so that test-pollution patterns surface the same way.
  local sorted = {}
  for _, f in ipairs(files) do sorted[#sorted + 1] = f end
  table.sort(sorted)
  local file_args = {}
  for _, f in ipairs(sorted) do
    file_args[#file_args + 1] = shell_lib.shell_quote(f)
  end
  local cmd = table.concat({
    _coverage_env_prefix(config_path),
    _spec_command_prefix(),
    "-c",
    "--helper=test/helper.lua",
    "--output=test/log_warns_handler.lua",
    "--pattern=test_",
    "--", table.concat(file_args, " "),
  }, " ")
  return { label = profile .. "_w" .. tostring(shard_index), cmd = cmd }
end

local function _merge_stats_into(target, source)
  for filename, source_data in pairs(source) do
    local existing = target[filename]
    if not existing then
      local copy = { max = source_data.max, max_hits = 0 }
      for line = 1, source_data.max do
        local hits = source_data[line]
        if hits and hits > 0 then
          copy[line] = hits
          if hits > copy.max_hits then copy.max_hits = hits end
        end
      end
      target[filename] = copy
    else
      if source_data.max > existing.max then existing.max = source_data.max end
      for line = 1, source_data.max do
        local hits = source_data[line]
        if hits and hits > 0 then
          local total = (existing[line] or 0) + hits
          existing[line] = total
          if total > existing.max_hits then existing.max_hits = total end
        end
      end
    end
  end
end

-- luacov stats file format (per vendor/luarocks luacov/stats.lua):
--   <max>:<filename>\n
--   <hit_line_1> <hit_line_2> ... <hit_line_max>\n
-- Inlined here to avoid pulling luacov into the lua interpreter used by
-- coverage.lua (luacov is installed for lua5.4 only; coverage.lua may run
-- under a different interpreter when invoked directly).
local function _load_stats(statsfile)
  local fd = io.open(statsfile, "r")
  if not fd then return nil end
  local data = {}
  while true do
    local max = fd:read("*n")
    if not max then break end
    if fd:read(1) ~= ":" then break end
    local filename = fd:read("*l")
    if not filename then break end
    local file_data = { max = max, max_hits = 0 }
    data[filename] = file_data
    for line = 1, max do
      local hits = fd:read("*n")
      if not hits then break end
      if fd:read(1) ~= " " then break end
      if hits > 0 then
        file_data[line] = hits
        if hits > file_data.max_hits then file_data.max_hits = hits end
      end
    end
  end
  fd:close()
  return data
end

local function _save_stats(statsfile, data)
  local fd = assert(io.open(statsfile, "w"))
  local filenames = {}
  for filename in pairs(data) do filenames[#filenames + 1] = filename end
  table.sort(filenames)
  for _, filename in ipairs(filenames) do
    local file_data = data[filename]
    fd:write(file_data.max, ":", filename, "\n")
    for line = 1, file_data.max do
      fd:write(tostring(file_data[line] or 0), " ")
    end
    fd:write("\n")
  end
  fd:close()
end

local function _merge_one(merged, path)
  if not fs_lib.path_exists(path) then return end
  local data = _load_stats(path)
  if data then
    _merge_stats_into(merged, data)
  end
  fs_lib.remove_path(path)
end

local function merge_profile_stats(profiles, target_path, shard_counts)
  shard_counts = shard_counts or {}
  local merged = {}
  for _, profile in ipairs(profiles) do
    local shard_count = shard_counts[profile]
    if shard_count then
      for i = 1, shard_count do
        _merge_one(merged, _shard_statsfile(profile, i))
      end
    else
      _merge_one(merged, _profile_stats_path(profile))
    end
  end
  _save_stats(target_path, merged)
end

local function _append_sharded_lanes(profile, root, configs, lanes)
  local files = sharding.discover_spec_files(root)
  if #files == 0 then
    return nil, "no spec files found in " .. root .. " for profile " .. profile
  end
  local worker_count = _resolve_coverage_workers(#files)
  local shard_lanes = sharding.build_lpt_lanes(files, worker_count)
  for _, shard in ipairs(shard_lanes) do
    local cfg, cfg_err = _write_shard_luacov_config(profile, shard.index)
    if not cfg then
      return nil, "failed to write shard luacov config " .. profile .. " w"
        .. tostring(shard.index) .. ": " .. tostring(cfg_err)
    end
    configs[#configs + 1] = cfg
    lanes[#lanes + 1] = _build_shard_lane(profile, shard.index, cfg, shard.files)
  end
  return #shard_lanes
end

local function _cleanup_stats(profiles, shard_counts)
  for _, profile in ipairs(profiles) do
    local count = shard_counts[profile]
    if count then
      for i = 1, count do fs_lib.remove_path(_shard_statsfile(profile, i)) end
    else
      fs_lib.remove_path(_profile_stats_path(profile))
    end
  end
end

local function run_spec_profiles_parallel(profiles)
  local configs = {}
  local lanes = {}
  local shard_counts = {}
  for _, profile in ipairs(profiles) do
    local shard_root = _SHARDED_PROFILES[profile]
    if shard_root then
      local count, err = _append_sharded_lanes(profile, shard_root, configs, lanes)
      if not count then
        for _, c in ipairs(configs) do fs_lib.remove_path(c) end
        print_stderr("ERROR: " .. tostring(err))
        return false
      end
      shard_counts[profile] = count
    else
      local cfg_path, err = _write_profile_luacov_config(profile)
      if not cfg_path then
        for _, c in ipairs(configs) do fs_lib.remove_path(c) end
        print_stderr("ERROR: failed to write luacov config for '" .. profile .. "': " .. tostring(err))
        return false
      end
      configs[#configs + 1] = cfg_path
      lanes[#lanes + 1] = _build_profile_lane(profile, cfg_path)
    end
  end

  print("Running parallel coverage profiles: " .. table.concat(profiles, ", "))
  local ok_all, results = parallel_lanes.run(lanes, { stream = true })

  for _, c in ipairs(configs) do fs_lib.remove_path(c) end

  if not ok_all then
    for _, r in ipairs(results) do
      if not r.ok then
        print_stderr("ERROR: coverage lane '" .. r.label
          .. "' failed with exit code " .. tostring(r.exit_code))
      end
    end
    _cleanup_stats(profiles, shard_counts)
    return false
  end

  merge_profile_stats(profiles, "build/luacov.stats.out", shard_counts)
  return true
end

-- report.out 由 luacov 原生 reporter 产出（report 阶段
-- 读合并后的 build/luacov.stats.out 写 build/luacov.report.out)。reporter 在干净
-- lua5.4 进程里跑——runner.load_config 在 configuration 已设时直接返回旧配置,
-- 同一进程里换 stats 不可靠。luacov runner/reporter 的 require 需要 tree 的
-- LUA_PATH(纯 lua)与 LUA_CPATH(cluacov 的 C 扩展 .so),由调用方显式注入
-- (reporter 进程不经 runner 引导)。
local function _write_merged_luacov_config()
  local config_path = env_lib.make_temp_path("luacov_merged", ".lua")
  local content = _build_luacov_config({ statsfile = "build/luacov.stats.out" })
  local ok, err = fs_lib.write_file(config_path, content)
  if not ok then
    return nil, err
  end
  return config_path
end

local function run_reporter(quiet)
  local lua54_bin = runner_bin.detect_lua54()
  if lua54_bin == nil then
    print_stderr("ERROR: cannot resolve lua5.4 interpreter for luacov reporter")
    return false
  end
  local config_path, config_err = _write_merged_luacov_config()
  if not config_path then
    print_stderr("ERROR: " .. tostring(config_err))
    return false
  end
  local script = string.format(
    "local cfg = dofile(%q); require(%q).run_report(cfg)",
    config_path, "luacov.runner"
  )
  local tree = path_lib.join_path(env_lib.current_dir(), ".toolcache/luarocks")
  local lua_path = path_lib.join_path(tree, "share/lua/5.4/?.lua") .. ";;"
  -- luacov 0.17 在 cluacov.version 可 require 时走 C 扩展 hook(reporter 的
  -- deepactivelines 同样):cluacov 的 .so 住 tree 的 lib/lua/5.4/,只注入
  -- LUA_PATH 会 module not found(实测 macOS 必红)。LUA_CPATH 与 LUA_PATH
  -- 同 tree 派生,不加平台特判(macOS / WSL 同一 luarocks tree 布局)。
  local lua_cpath = path_lib.join_path(tree, "lib/lua/5.4/?.so") .. ";;"
  local cmd = table.concat({
    "LUA_PATH=" .. shell_lib.shell_quote(lua_path),
    "LUA_CPATH=" .. shell_lib.shell_quote(lua_cpath),
    shell_lib.shell_quote(lua54_bin),
    "-e", shell_lib.shell_quote(script),
  }, " ")
  _trace(quiet, "Running luacov reporter (stats: build/luacov.stats.out)")
  local ok, _, code = os.execute(cmd .. " > " .. shell_lib.shell_quote("build/luacov_reporter.log") .. " 2>&1")
  local success = ok == true and (code == nil or code == 0)
  if not success then
    local log = fs_lib.read_file("build/luacov_reporter.log") or ""
    print_stderr("ERROR: luacov reporter failed: " .. text_lib.trim(log))
  end
  fs_lib.remove_path(config_path)
  fs_lib.remove_path("build/luacov_reporter.log")
  return success
end

local function normalize_repo_path(file_path)
  local normalized = path_lib.normalize_path(file_path)
  local repo_root = env_lib.current_dir()
  if normalized:find(repo_root, 1, true) == 1 then
    normalized = normalized:sub(#repo_root + 1)
  end
  normalized = normalized:gsub("^/", ""):gsub("^%./", "")
  return normalized
end

local function classify_directory(file_path)
  local normalized = normalize_repo_path(file_path)
  local dirs = {
    "src/foundation/",
    "src/rules/",
    "src/turn/",
    "src/state/",
    "src/player/",
    "src/computer/",
  }

  for _, dir in ipairs(dirs) do
    if normalized:find(dir, 1, true) == 1 then
      return dir
    end
  end

  return nil
end


local function parse_luacov_report()
  local content, err = fs_lib.read_file("build/luacov.report.out")
  if not content then
    print_stderr("ERROR: Cannot read build/luacov.report.out: " .. tostring(err))
    return nil
  end

  local by_path = {}
  local in_summary = false
  local past_header = false

  for line in content:gmatch("[^\r\n]+") do
    if line:match("^=+%s*$") then
      if in_summary and past_header then
        break
      end
    end

    if line:match("^%s*Summary%s*$") then
      in_summary = true
      past_header = false
    elseif in_summary and line:match("^%-+%s*$") then
      past_header = true
    elseif in_summary and past_header and line ~= "" then
      local total_match = line:match("^%s*Total%s+")
      if total_match then
        break
      end

      local coverage_str = line:match("(%d+%.%d+)%%%s*$")
      if not coverage_str then
        coverage_str = line:match("(%d+)%%%s*$")
      end

      if coverage_str then
        local coverage = tonumber(coverage_str)
        local pattern = "(.-)%s+(%d+)%s+(%d+)%s+" .. coverage_str:gsub("%.", "%%.") .. "%%"
        local file_path, hits_str, missed_str = line:match(pattern)

        if file_path and hits_str and missed_str then
          local hits = tonumber(hits_str)
          local missed = tonumber(missed_str)
          -- luacov 原生 reporter 的 Summary 行保留 stats 原 key:被测试文件是
          -- 加载时形态(绝对路径、可能带 /./ 段),未测试文件是相对 cwd 形态。
          -- 先归一化再归类，否则绝对形态永远归不进 tier。
          local norm_path = normalize_repo_path(file_path)
          local dir = classify_directory(norm_path)

          if dir then
            local existing = by_path[norm_path]
            if (not existing) or hits > existing.hits then
              by_path[norm_path] = {
                path = norm_path,
                dir = dir,
                hits = hits,
                missed = missed,
                coverage = coverage,
              }
            end
          end
        end
      end
    end
  end

  local files = {}
  for _, entry in pairs(by_path) do
    files[#files + 1] = entry
  end

  return files
end

local function aggregate_by_directory(files)
  local dirs = {
    "src/foundation/",
    "src/rules/",
    "src/turn/",
    "src/state/",
    "src/player/",
    "src/computer/",
  }

  local aggregates = {}
  for _, dir in ipairs(dirs) do
    aggregates[dir] = {
      hits = 0,
      missed = 0,
      total = 0,
      files = {},
    }
  end

  for _, file in ipairs(files) do
    local agg = aggregates[file.dir]
    if agg then
      agg.hits = agg.hits + file.hits
      agg.missed = agg.missed + file.missed
      agg.total = agg.total + file.hits + file.missed
      table.insert(agg.files, file)
    end
  end

  return aggregates
end

local function format_coverage(hits, total)
  if total == 0 then
    return 0.0
  end
  return (hits / total) * 100
end

local function generate_report(aggregates, threshold, profiles, quiet)
  local lines = {}

  table.insert(lines, "# Coverage Report")
  table.insert(lines, "")
  table.insert(lines, "Generated: " .. os.date("%Y-%m-%d %H:%M:%S"))
  table.insert(lines, "Profiles: " .. table.concat(profiles, ", "))
  table.insert(lines, "Threshold: " .. threshold .. "%")
  table.insert(lines, "")
  table.insert(lines, "## Per-Directory Summary")
  table.insert(lines, "")
  table.insert(lines, "| Directory | Hits | Miss | Total | Coverage |")
  table.insert(lines, "|-----------|------|------|-------|----------|")

  local dirs = {
    "src/foundation/",
    "src/rules/",
    "src/turn/",
    "src/state/",
    "src/player/",
    "src/computer/",
  }

  local total_hits = 0
  local total_missed = 0
  local total_lines = 0

  for _, dir in ipairs(dirs) do
    local agg = aggregates[dir]
    local dir_total = agg.hits + agg.missed
    local coverage = format_coverage(agg.hits, dir_total)

    total_hits = total_hits + agg.hits
    total_missed = total_missed + agg.missed
    total_lines = total_lines + dir_total

    table.insert(lines, string.format(
      "| %s | %d | %d | %d | %.2f%% |",
      dir, agg.hits, agg.missed, dir_total, coverage
    ))
  end

  table.insert(lines, "")

  local aggregate_coverage = format_coverage(total_hits, total_lines)
  table.insert(lines, "## Aggregate")
  table.insert(lines, "")
  table.insert(lines, string.format("**%.2f%%** (threshold: %d%%)", aggregate_coverage, threshold))
  table.insert(lines, "")

  if not quiet then
    local all_files = {}
    for _, dir in ipairs(dirs) do
      for _, file in ipairs(aggregates[dir].files) do
        table.insert(all_files, file)
      end
    end

    table.sort(all_files, function(a, b)
      return a.coverage < b.coverage
    end)

    if #all_files > 0 then
      table.insert(lines, "## Per-File Details")
      table.insert(lines, "")
      table.insert(lines, "| File | Directory | Hits | Miss | Total | Coverage |")
      table.insert(lines, "|------|-----------|------|------|-------|----------|")

      for _, file in ipairs(all_files) do
        local file_total = file.hits + file.missed
        table.insert(lines, string.format(
          "| %s | %s | %d | %d | %d | %.2f%% |",
          file.path, file.dir, file.hits, file.missed, file_total, file.coverage
        ))
      end

      table.insert(lines, "")
    end
  end

  local passed = aggregate_coverage >= threshold
  table.insert(lines, "## Result")
  table.insert(lines, "")
  if passed then
    table.insert(lines, "✅ PASS")
  else
    table.insert(lines, "❌ FAIL")
  end
  table.insert(lines, "")

  return table.concat(lines, "\n"), passed, aggregate_coverage
end

local function main(args)
  local opts = parse_args(args)

  local out_dir = path_lib.parent_dir(opts.out)
  if out_dir then
    local ok, err = fs_lib.ensure_dir(out_dir)
    if not ok then
      print_stderr("ERROR: Cannot create output directory: " .. tostring(err))
      os.exit(1)
    end
  end

  if not opts.reuse_stats then
    delete_stale_files()
    for _, profile in ipairs(opts.profiles) do
      fs_lib.remove_path(_profile_stats_path(profile))
    end

    local ok = run_spec_profiles_parallel(opts.profiles)
    if not ok then
      os.exit(1)
    end
  end

  local ok = run_reporter(opts.quiet)
  if not ok then
    os.exit(1)
  end

  local files = parse_luacov_report()
  if not files then
    os.exit(1)
  end

  local aggregates = aggregate_by_directory(files)

  local report, passed, aggregate_coverage = generate_report(
    aggregates, opts.threshold, opts.profiles, opts.quiet
  )

  local write_ok, write_err = fs_lib.write_file(opts.out, report)
  if not write_ok then
    print_stderr("ERROR: Cannot write report: " .. tostring(write_err))
    os.exit(1)
  end

  if not opts.quiet then
    print(report)
  end

  if not passed then
    print_stderr(string.format(
      "Coverage %.2f%% is below threshold %d%%", aggregate_coverage, opts.threshold
    ))
    os.exit(1)
  end

  os.exit(0)
end

local M = {
  parse_args = parse_args,
  _trace = _trace,
  _set_trace_sink_for_tests = _set_trace_sink_for_tests,
}

if ... == "packages.coverage.coverage" then
  return M
end

main(arg)
