#!/usr/bin/env lua

local function _normalize_path(path)
  return tostring(path or ""):gsub("\\", "/")
end
local function _module_dir()
  local source = debug.getinfo(1, "S").source or "@tools/quality/coverage.lua"
  return _normalize_path(source):gsub("^@", ""):match("^(.*)/[^/]+$") or "tools/quality"
end

local bootstrap = dofile(_module_dir() .. "/../shared/bootstrap.lua")
bootstrap.install((arg and arg[0]) or debug.getinfo(1, "S").source)

local common = require("shared.lib.common")
local parallel_lanes = require("shared.lib.parallel_lanes")
local sharding = require("shared.lib.busted_sharding")

-- Profile -> spec root. Sharded profiles run as N parallel busted lanes (one
-- per shard) instead of a single lane, each writing its own stats file. Total
-- wall is bounded by the slowest shard rather than the full lane.
local _SHARDED_PROFILES = { behavior = "spec/behavior" }
-- MONO_COVERAGE_WORKERS overrides; baseline came from a 1/3/6/8 sweep on
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
      result.profiles = common.split(profiles_match, ",")
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
  local files = { "luacov.stats.out", "luacov.report.out" }
  for _, file in ipairs(files) do
    if common.path_exists(file) then
      local ok, err = common.remove_path(file)
      if not ok then
        print_stderr("Warning: failed to delete " .. file .. ": " .. tostring(err))
      end
    end
  end
end

local LUA_VERSION = "5.4"

local function detect_lua54_paths()
  local paths = {
    lua = os.getenv("LUA54_BIN"),
    busted = os.getenv("BUSTED_BIN"),
    luacov = os.getenv("LUACOV_BIN"),
    lua_path = os.getenv("LUA54_LUA_PATH"),
    lua_cpath = os.getenv("LUA54_LUA_CPATH"),
  }

  if not paths.lua then
    local candidates = {
      "/opt/homebrew/bin/lua" .. LUA_VERSION,
      "/usr/local/bin/lua" .. LUA_VERSION,
      "/opt/homebrew/opt/lua@" .. LUA_VERSION .. "/bin/lua" .. LUA_VERSION,
      "/usr/local/opt/lua@" .. LUA_VERSION .. "/bin/lua" .. LUA_VERSION,
    }
    for _, candidate in ipairs(candidates) do
      if common.path_exists(candidate) then
        paths.lua = candidate
        break
      end
    end
  end

  if not paths.lua then
    local result = common.run_command("command -v lua" .. LUA_VERSION)
    if result.ok and result.output then
      local trimmed = result.output:match("^%s*(.-)%s*$")
      if trimmed and trimmed ~= "" then
        paths.lua = trimmed
      end
    end
  end

  if not paths.lua then
    print_stderr("ERROR: Cannot locate lua" .. LUA_VERSION .. " binary. Set LUA54_BIN or install lua@" .. LUA_VERSION)
    return nil
  end

  local lua_bin_dir = paths.lua:match("(.*)/[^/]+$")
  local luarocks_prefix = lua_bin_dir and ("PATH=" .. lua_bin_dir .. ":$PATH ") or ""

  local function find_rocks_bin(rock_name)
    local list_result = common.run_command(
      luarocks_prefix .. "luarocks --lua-version=" .. LUA_VERSION .. " list --porcelain " .. rock_name .. " 2>/dev/null"
    )
    if not (list_result.ok and list_result.output) then return nil end
    local version, tree = list_result.output:match("^" .. rock_name .. "%s+([^%s]+)%s+installed%s+(/[^%s]+)")
    if not version or not tree then return nil end
    local bin = tree .. "/" .. rock_name .. "/" .. version .. "/bin/" .. rock_name
    if common.path_exists(bin) then
      return bin
    end
    return nil
  end

  if not paths.busted then
    paths.busted = find_rocks_bin("busted")
  end
  if not paths.luacov then
    paths.luacov = find_rocks_bin("luacov")
  end

  if not paths.busted or not paths.luacov then
    print_stderr("ERROR: Cannot locate busted/luacov for Lua " .. LUA_VERSION
      .. ". Install with: luarocks --lua-version=" .. LUA_VERSION .. " install busted luacov luafilesystem")
    return nil
  end

  if not paths.lua_path or not paths.lua_cpath then
    local result = common.run_command(luarocks_prefix .. "luarocks --lua-version=" .. LUA_VERSION .. " path")
    if result.ok and result.output then
      paths.lua_path = paths.lua_path or result.output:match("LUA_PATH='([^']+)'")
      paths.lua_cpath = paths.lua_cpath or result.output:match("LUA_CPATH='([^']+)'")
    end
  end

  if not paths.lua_path or not paths.lua_cpath then
    print_stderr("ERROR: Cannot resolve LUA_PATH/LUA_CPATH for Lua " .. LUA_VERSION)
    return nil
  end

  paths.lua_path = paths.lua_path .. ";;"
  paths.lua_cpath = paths.lua_cpath .. ";;"

  return paths
end

local LUA54 = nil

local function ensure_lua54()
  if LUA54 then return LUA54 end
  LUA54 = detect_lua54_paths()
  return LUA54
end

local function _profile_stats_path(profile)
  return "luacov." .. profile .. ".stats.out"
end

local function _shard_statsfile(profile, shard_index)
  return string.format("luacov.%s_w%d.stats.out", profile, shard_index)
end

local function _resolve_coverage_workers(file_count)
  return sharding.resolve_workers("MONO_COVERAGE_WORKERS", file_count, _DEFAULT_COVERAGE_WORKERS)
end

local function _build_luacov_config(opts)
  opts = opts or {}
  local statsfile = opts.statsfile or "luacov.stats.out"
  local with_untested = opts.with_untested ~= false

  local parts = {
    "return {",
    '  include = {',
    '    "src/foundation/", "src/rules/", "src/turn/",',
    '    "src/state/", "src/player/", "src/computer/",',
    '  },',
    '  exclude = {',
    '    "src/app/", "src/host/", "src/ui/", "src/config/",',
    '    "tests/", "spec/", "tools/", "vendor/",',
    '    "/usr/", "/%.luarocks/",',
    '  },',
  }
  if with_untested then
    parts[#parts + 1] = '  includeuntestedfiles = {'
    parts[#parts + 1] = '    "src/foundation", "src/rules", "src/turn",'
    parts[#parts + 1] = '    "src/state", "src/player", "src/computer",'
    parts[#parts + 1] = '  },'
  end
  parts[#parts + 1] = '  statsfile  = ' .. string.format("%q", statsfile) .. ","
  parts[#parts + 1] = '  reportfile = "luacov.report.out",'
  parts[#parts + 1] = '  deletestats = false,'
  parts[#parts + 1] = '  runreport   = false,'
  parts[#parts + 1] = '  codefromstrings = false,'
  parts[#parts + 1] = "}"
  parts[#parts + 1] = ""

  return table.concat(parts, "\n")
end

local function _write_profile_luacov_config(profile)
  local config_path = common.make_temp_path("luacov_" .. profile, ".lua")
  local content = _build_luacov_config({ statsfile = _profile_stats_path(profile) })
  local ok, err = common.write_file(config_path, content)
  if not ok then
    return nil, err
  end
  return config_path
end

local function _write_shard_luacov_config(profile, shard_index)
  local config_path = common.make_temp_path(
    "luacov_" .. profile .. "_w" .. tostring(shard_index), ".lua"
  )
  local content = _build_luacov_config({
    statsfile = _shard_statsfile(profile, shard_index),
  })
  local ok, err = common.write_file(config_path, content)
  if not ok then
    return nil, err
  end
  return config_path
end

local function _build_profile_lane(profile, config_path, paths)
  local cmd = table.concat({
    "LUACOV=1",
    "LUACOV_CONFIG=" .. common.shell_quote(config_path),
    "LUA_PATH=" .. common.shell_quote(paths.lua_path),
    "LUA_CPATH=" .. common.shell_quote(paths.lua_cpath),
    common.shell_quote(paths.lua),
    common.shell_quote(paths.busted),
    "-c", "--run", profile,
  }, " ")
  return { label = profile, cmd = cmd }
end

local function _build_shard_lane(profile, shard_index, config_path, files, paths)
  -- Sort lane files alphabetically so within-shard execution order matches
  -- busted's recursive walk of the spec tree. LPT picks which files go to
  -- which shard by descending cost, but once a shard is fixed we want its
  -- files to run in the same relative order they would in a monolithic run
  -- so that test-pollution patterns surface the same way.
  local sorted = {}
  for _, f in ipairs(files) do sorted[#sorted + 1] = f end
  table.sort(sorted)
  local file_args = {}
  for _, f in ipairs(sorted) do
    file_args[#file_args + 1] = common.shell_quote(f)
  end
  local cmd = table.concat({
    "LUACOV=1",
    "LUACOV_CONFIG=" .. common.shell_quote(config_path),
    "LUA_PATH=" .. common.shell_quote(paths.lua_path),
    "LUA_CPATH=" .. common.shell_quote(paths.lua_cpath),
    common.shell_quote(paths.lua),
    common.shell_quote(paths.busted),
    "-c",
    "--helper=spec/helper.lua",
    "--output=spec/log_warns_handler.lua",
    "--pattern=_spec",
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
  if not common.path_exists(path) then return end
  local data = _load_stats(path)
  if data then
    _merge_stats_into(merged, data)
  end
  common.remove_path(path)
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

local function _append_sharded_lanes(profile, root, paths, configs, lanes)
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
    lanes[#lanes + 1] = _build_shard_lane(profile, shard.index, cfg, shard.files, paths)
  end
  return #shard_lanes
end

local function _cleanup_stats(profiles, shard_counts)
  for _, profile in ipairs(profiles) do
    local count = shard_counts[profile]
    if count then
      for i = 1, count do common.remove_path(_shard_statsfile(profile, i)) end
    else
      common.remove_path(_profile_stats_path(profile))
    end
  end
end

local function run_busted_profiles_parallel(profiles)
  local paths = ensure_lua54()
  if not paths then return false end

  local configs = {}
  local lanes = {}
  local shard_counts = {}
  for _, profile in ipairs(profiles) do
    local shard_root = _SHARDED_PROFILES[profile]
    if shard_root then
      local count, err = _append_sharded_lanes(profile, shard_root, paths, configs, lanes)
      if not count then
        for _, c in ipairs(configs) do common.remove_path(c) end
        print_stderr("ERROR: " .. tostring(err))
        return false
      end
      shard_counts[profile] = count
    else
      local cfg_path, err = _write_profile_luacov_config(profile)
      if not cfg_path then
        for _, c in ipairs(configs) do common.remove_path(c) end
        print_stderr("ERROR: failed to write luacov config for '" .. profile .. "': " .. tostring(err))
        return false
      end
      configs[#configs + 1] = cfg_path
      lanes[#lanes + 1] = _build_profile_lane(profile, cfg_path, paths)
    end
  end

  print("Running parallel coverage profiles: " .. table.concat(profiles, ", "))
  local ok_all, results = parallel_lanes.run(lanes, { stream = true })

  for _, c in ipairs(configs) do common.remove_path(c) end

  if not ok_all then
    for _, r in ipairs(results) do
      if not r.ok then
        print_stderr("ERROR: busted lane '" .. r.label
          .. "' failed with exit code " .. tostring(r.exit_code))
      end
    end
    _cleanup_stats(profiles, shard_counts)
    return false
  end

  merge_profile_stats(profiles, "luacov.stats.out", shard_counts)
  return true
end

local function run_luacov(quiet)
  local paths = ensure_lua54()
  if not paths then return false end

  local luacov_cmd = table.concat({
    "LUA_PATH=" .. common.shell_quote(paths.lua_path),
    "LUA_CPATH=" .. common.shell_quote(paths.lua_cpath),
    common.shell_quote(paths.lua),
    common.shell_quote(paths.luacov),
  }, " ")

  _trace(quiet, "Running: " .. luacov_cmd)
  local result = common.run_command(luacov_cmd)

  if not result.ok then
    local output = result.output or ""
    if output:find("includeuntestedfiles") and output:find("lfs") then
      print_stderr("WARNING: lfs module not available, retrying without includeuntestedfiles")
      local temp_config = common.make_temp_path("luacov_config", ".lua")
      local write_ok = common.write_file(temp_config, _build_luacov_config({ with_untested = false }))
      if not write_ok then
        print_stderr("ERROR: Failed to create temporary luacov config")
        return false
      end

      local retry_cmd = luacov_cmd .. " -c " .. common.shell_quote(temp_config)
      _trace(quiet, "Running: " .. retry_cmd)
      result = common.run_command(retry_cmd)
      common.remove_path(temp_config)

      if not result.ok then
        print_stderr("ERROR: luacov retry failed with exit code " .. tostring(result.code))
        if result.output and result.output ~= "" then
          print_stderr("Output:\n" .. result.output)
        end
        return false
      end

      return true
    end

    print_stderr("ERROR: luacov failed with exit code " .. tostring(result.code))
    if output ~= "" then
      print_stderr("Output:\n" .. output)
    end
    return false
  end

  return true
end

local function normalize_repo_path(file_path)
  local normalized = common.normalize_path(file_path)
  local repo_root = common.current_dir()
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
  local content, err = common.read_file("luacov.report.out")
  if not content then
    print_stderr("ERROR: Cannot read luacov.report.out: " .. tostring(err))
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
          local dir = classify_directory(file_path)

          if dir then
            local norm_path = normalize_repo_path(file_path)
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

  local out_dir = common.parent_dir(opts.out)
  if out_dir then
    local ok, err = common.ensure_dir(out_dir)
    if not ok then
      print_stderr("ERROR: Cannot create output directory: " .. tostring(err))
      os.exit(1)
    end
  end

  if not opts.reuse_stats then
    delete_stale_files()
    for _, profile in ipairs(opts.profiles) do
      common.remove_path(_profile_stats_path(profile))
    end

    local ok = run_busted_profiles_parallel(opts.profiles)
    if not ok then
      os.exit(1)
    end
  end

  local ok = run_luacov(opts.quiet)
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

  local write_ok, write_err = common.write_file(opts.out, report)
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

if ... == "quality.coverage" then
  return M
end

main(arg)
