#!/usr/bin/env lua

local common = require("tools.shared.lib.common")

local function print_stderr(msg)
  io.stderr:write(msg .. "\n")
end

local function parse_args(args)
  local result = {
    threshold = 90,
    out = "tmp/coverage.md",
    profiles = { "behavior", "contract", "guards" },
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

local LUA_VERSION = "5.5"

local function detect_lua55_paths()
  local paths = {
    lua = os.getenv("LUA55_BIN"),
    busted = os.getenv("BUSTED_BIN"),
    luacov = os.getenv("LUACOV_BIN"),
    lua_path = os.getenv("LUA55_LUA_PATH"),
    lua_cpath = os.getenv("LUA55_LUA_CPATH"),
  }

  if not paths.lua then
    local candidates = {
      "/opt/homebrew/bin/lua" .. LUA_VERSION,
      "/usr/local/bin/lua" .. LUA_VERSION,
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
    print_stderr("ERROR: Cannot locate lua" .. LUA_VERSION .. " binary. Set LUA55_BIN or install lua@" .. LUA_VERSION)
    return nil
  end

  local function find_rocks_bin(rock_name)
    local list_result = common.run_command(
      "luarocks --lua-version=" .. LUA_VERSION .. " list --porcelain " .. rock_name .. " 2>/dev/null"
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
    local result = common.run_command("luarocks --lua-version=" .. LUA_VERSION .. " path")
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

local LUA55 = nil

local function ensure_lua55()
  if LUA55 then return LUA55 end
  LUA55 = detect_lua55_paths()
  return LUA55
end

local function run_busted_profile(profile)
  local paths = ensure_lua55()
  if not paths then return false end

  local command_parts = {
    "LUACOV=1",
    "LUA_PATH=" .. common.shell_quote(paths.lua_path),
    "LUA_CPATH=" .. common.shell_quote(paths.lua_cpath),
    common.shell_quote(paths.lua),
    common.shell_quote(paths.busted),
    "-c", "--run", profile,
  }
  local command = table.concat(command_parts, " ")

  print("Running: " .. command)
  local result = common.run_command(command)

  if not result.ok then
    print_stderr("ERROR: busted profile '" .. profile .. "' failed with exit code " .. tostring(result.code))
    if result.output and result.output ~= "" then
      print_stderr("Output:\n" .. result.output)
    end
    return false
  end

  return true
end

local function build_luacov_without_untested()
  local config_content = [[
return {
  include = {
    "src/core/", "src/rules/", "src/turn/",
    "src/state/", "src/player/", "src/computer/",
  },
  exclude = {
    "src/app/", "src/host/", "src/ui/", "src/config/",
    "tests/", "spec/", "tools/", "vendor/",
    "/usr/", "/%.luarocks/",
  },
  statsfile  = "luacov.stats.out",
  reportfile = "luacov.report.out",
  deletestats = false,
  runreport   = false,
  codefromstrings = false,
}
]]
  return config_content
end

local function run_luacov()
  local paths = ensure_lua55()
  if not paths then return false end

  local luacov_cmd = table.concat({
    "LUA_PATH=" .. common.shell_quote(paths.lua_path),
    "LUA_CPATH=" .. common.shell_quote(paths.lua_cpath),
    common.shell_quote(paths.lua),
    common.shell_quote(paths.luacov),
  }, " ")

  print("Running: " .. luacov_cmd)
  local result = common.run_command(luacov_cmd)

  if not result.ok then
    local output = result.output or ""
    if output:find("includeuntestedfiles") and output:find("lfs") then
      print_stderr("WARNING: lfs module not available, retrying without includeuntestedfiles")
      local temp_config = common.make_temp_path("luacov_config", ".lua")
      local write_ok = common.write_file(temp_config, build_luacov_without_untested())
      if not write_ok then
        print_stderr("ERROR: Failed to create temporary luacov config")
        return false
      end

      local retry_cmd = luacov_cmd .. " -c " .. common.shell_quote(temp_config)
      print("Running: " .. retry_cmd)
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
    "src/core/",
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
    "src/core/",
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
    "src/core/",
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
      local ok = run_busted_profile(profile)
      if not ok then
        os.exit(1)
      end
    end
  end

  local ok = run_luacov()
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

  print(report)

  if not passed then
    print_stderr(string.format(
      "Coverage %.2f%% is below threshold %d%%", aggregate_coverage, opts.threshold
    ))
    os.exit(1)
  end

  os.exit(0)
end

main(arg)
