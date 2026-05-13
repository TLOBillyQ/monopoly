local function _normalize_path(path)
  return tostring(path or ""):gsub("\\", "/")
end

local function _module_dir()
  local source = debug.getinfo(1, "S").source or "@tools/quality/crap.lua"
  local normalized = _normalize_path(source):gsub("^@", "")
  return normalized:match("^(.*)/[^/]+$") or "tools/quality"
end

local bootstrap = dofile(_module_dir() .. "/../shared/bootstrap.lua")
local bootstrap_env = bootstrap.install((arg and arg[0]) or debug.getinfo(1, "S").source)

local common = require("shared.lib.common")
local json_writer = require("shared.lib.json_writer")
local package_path_helper = require("shared.package_path_helper")

common.ensure_windows_utf8_console()
local REPO_ROOT = bootstrap_env.repo_root
local CRAP4LUA_ROOT = common.join_path(REPO_ROOT, "vendor/crap4lua")
local DEFAULT_CONFIG_PATH = common.join_path(REPO_ROOT, "tools/quality/crap/config.lua")
local DEFAULT_REPORT_JSON = "tmp/crap_report.json"
local DEFAULT_VIEW_DIR = "tmp/crap_view"
local TMP_BUILD_DIR = ".monopoly_tmp/cmd/crap4lua"

local M = {}

local function _binary_name()
  if common.is_windows() then
    return "crap4lua.exe"
  end
  return "crap4lua"
end

local function _binary_path(repo_root)
  return common.join_path(common.join_path(repo_root, "vendor/crap4lua"), "bin/" .. _binary_name())
end

local function _default_tmp_root()
  local env_root = os.getenv("MONOPOLY_CRAP_TMP")
  if env_root ~= nil and env_root ~= "" then
    return common.normalize_path(env_root)
  end
  return common.join_path(common.system_tmp_dir(), "monopoly_crap")
end

local function _resolve_cli_path(base, path)
  local normalized = common.normalize_path(path)
  if normalized == "" then
    return common.resolve_path(base, normalized)
  end
  if normalized == "tmp" or normalized:match("^tmp/") then
    local suffix = normalized == "tmp" and "" or normalized:sub(5)
    return common.resolve_path(_default_tmp_root(), suffix)
  end
  return common.resolve_path(base, normalized)
end

local function _help_text(command_name)
  return table.concat({
    "用法:",
    "  lua " .. tostring(command_name) .. " report [--lane NAME] [--runner NAME] [--out FILE] [--top N] [--strict-tests] [--project-root DIR]",
    "  lua " .. tostring(command_name) .. " collect [--lane NAME] [--runner NAME] --out FILE [--project-root DIR]",
    "  lua " .. tostring(command_name) .. " dry-run [--lane NAME] [--runner NAME] [--config FILE]",
    "  lua " .. tostring(command_name) .. " viewer [--in-json FILE] [--out-dir DIR] [--open]",
    "  lua " .. tostring(command_name) .. " summary [--in-json FILE] [--tier-config FILE] [--lane NAME] [--out FILE] [--top N] [--gate]",
    "  lua " .. tostring(command_name),
    "",
    "Usage:",
    "  lua " .. tostring(command_name) .. " report [--lane NAME] [--runner NAME] [--out FILE] [--top N] [--strict-tests] [--project-root DIR]",
    "  lua " .. tostring(command_name) .. " collect [--lane NAME] [--runner NAME] --out FILE [--project-root DIR]",
    "  lua " .. tostring(command_name) .. " dry-run [--lane NAME] [--runner NAME] [--config FILE]",
    "  lua " .. tostring(command_name) .. " viewer [--in-json FILE] [--out-dir DIR] [--open]",
    "  lua " .. tostring(command_name) .. " summary [--in-json FILE] [--tier-config FILE] [--lane NAME] [--out FILE] [--top N] [--gate]",
    "  lua " .. tostring(command_name),
    "",
    "Monopoly 默认值 / Monopoly defaults:",
    "  tmp/... 路径会映射到系统临时目录下的 monopoly_crap/ 子目录",
    "  report --out 会翻译成 vendor CLI 的 --response-json",
    "  report 先通过 Lua bridge 收集 coverage，再以 --request-json 调上游 CLI",
    "  summary 从 crap_report.json 聚合 src/ 行覆盖率，按 tier 分层展示（见 tools/quality/crap/coverage_tiers.lua）",
    "  裸调用会先生成 tmp/crap_report.json，再打开 tmp/crap_view",
  }, "\n") .. "\n"
end

local function _copy_args(args)
  local copied = {}
  for index, value in ipairs(args or {}) do
    copied[index] = value
  end
  return copied
end

local function _parse_report_args(args)
  local options = {
    config = DEFAULT_CONFIG_PATH,
    out = DEFAULT_REPORT_JSON,
    top = 20,
    strict_tests = false,
    project_root = nil,
    lanes = {},
    runner = nil,
  }

  local index = 1
  while index <= #args do
    local token = args[index]
    if token == "--config" then
      index = index + 1
      options.config = args[index]
    elseif token == "--out" or token == "--response-json" then
      index = index + 1
      options.out = args[index]
    elseif token == "--lane" then
      index = index + 1
      options.lanes[#options.lanes + 1] = args[index]
    elseif token == "--project-root" then
      index = index + 1
      options.project_root = args[index]
    elseif token == "--runner" then
      index = index + 1
      options.runner = args[index]
    elseif token == "--top" then
      index = index + 1
      options.top = common.to_integer(args[index]) or 20
    elseif token == "--strict-tests" then
      options.strict_tests = true
    else
      error("unknown flag: " .. tostring(token))
    end
    index = index + 1
  end

  options.config = _resolve_cli_path(REPO_ROOT, options.config)
  options.out = _resolve_cli_path(REPO_ROOT, options.out)
  if options.project_root ~= nil then
    options.project_root = _resolve_cli_path(REPO_ROOT, options.project_root)
  end
  return options
end

local function _parse_collect_args(args)
  local options = {
    config = DEFAULT_CONFIG_PATH,
    out = nil,
    project_root = nil,
    lanes = {},
    runner = nil,
  }

  local index = 1
  while index <= #args do
    local token = args[index]
    if token == "--config" then
      index = index + 1
      options.config = args[index]
    elseif token == "--out" then
      index = index + 1
      options.out = args[index]
    elseif token == "--lane" then
      index = index + 1
      options.lanes[#options.lanes + 1] = args[index]
    elseif token == "--project-root" then
      index = index + 1
      options.project_root = args[index]
    elseif token == "--runner" then
      index = index + 1
      options.runner = args[index]
    else
      error("unknown flag: " .. tostring(token))
    end
    index = index + 1
  end

  if options.out == nil or options.out == "" then
    error("collect requires --out FILE")
  end
  options.config = _resolve_cli_path(REPO_ROOT, options.config)
  options.out = _resolve_cli_path(REPO_ROOT, options.out)
  if options.project_root ~= nil then
    options.project_root = _resolve_cli_path(REPO_ROOT, options.project_root)
  end
  return options
end

local function _parse_viewer_args(args)
  local options = {
    in_json = nil,
    out_dir = DEFAULT_VIEW_DIR,
    open = false,
  }
  local index = 1
  while index <= #args do
    local token = args[index]
    if token == "--in-json" then
      index = index + 1
      options.in_json = args[index]
    elseif token == "--out-dir" then
      index = index + 1
      options.out_dir = args[index]
    elseif token == "--open" then
      options.open = true
    else
      error("unknown flag: " .. tostring(token))
    end
    index = index + 1
  end
  if options.in_json ~= nil then
    options.in_json = _resolve_cli_path(REPO_ROOT, options.in_json)
  end
  options.out_dir = _resolve_cli_path(REPO_ROOT, options.out_dir)
  return options
end

local function _parse_dry_run_args(args)
  local options = {
    config = DEFAULT_CONFIG_PATH,
    lane = "behavior",
    runner = nil,
  }
  local index = 1
  while index <= #args do
    local token = args[index]
    if token == "--config" then
      index = index + 1
      options.config = args[index]
    elseif token == "--lane" then
      index = index + 1
      options.lane = args[index]
    elseif token == "--runner" then
      index = index + 1
      options.runner = args[index]
    else
      error("unknown flag: " .. tostring(token))
    end
    index = index + 1
  end
  options.config = _resolve_cli_path(REPO_ROOT, options.config)
  return options
end

local function _ensure_bridge_package_paths(repo_root)
  package_path_helper.install_monopoly_package_paths({
    repo_root = repo_root,
  })
  local patterns = {
    common.join_path(repo_root, "vendor/crap4lua/lib/?.lua"),
    common.join_path(repo_root, "vendor/crap4lua/lib/?/?.lua"),
  }
  for _, pattern in ipairs(patterns) do
    if not tostring(package.path):find(pattern, 1, true) then
      package.path = pattern .. ";" .. package.path
    end
  end
end

local function _copy_array(values)
  local copied = {}
  for _, value in ipairs(values or {}) do
    copied[#copied + 1] = value
  end
  return copied
end

local function _write_success_path(stdout, output, label, path)
  local text = tostring(output or "")
  if text ~= "" then
    stdout:write(text)
    if text:sub(-1) ~= "\n" then
      stdout:write("\n")
    end
  end
  stdout:write(tostring(label) .. ": " .. common.normalize_path(path) .. "\n")
end

local function _is_array_table(value)
  return type(value) == "table" and #value > 0
end

local function _load_raw_crap_config(config_path)
  local ok, loaded = pcall(dofile, config_path)
  if not ok then
    return nil, loaded
  end
  if type(loaded) ~= "table" then
    return nil, "crap config must return a table"
  end
  return loaded, nil
end

local function _resolve_collect_lanes(raw_coverage, cli_lanes)
  if _is_array_table(cli_lanes) then
    return _copy_array(cli_lanes)
  end
  local lanes_cfg = raw_coverage and raw_coverage.lanes or nil
  if _is_array_table(lanes_cfg) then
    return _copy_array(lanes_cfg)
  end
  if type(lanes_cfg) == "table" then
    if lanes_cfg.behavior ~= nil then
      return { "behavior" }
    end
    local keys = common.sorted_keys(lanes_cfg)
    if #keys > 0 then
      return { keys[1] }
    end
  end
  return { "default" }
end

local function _resolve_adapter_from_config(raw_coverage, config_dir, lane, runner)
  local adapter_setting = nil
  if runner ~= nil and runner ~= "" then
    if runner == "busted" then
      adapter_setting = "busted_adapter.lua"
    else
      return nil, "unsupported runner: " .. tostring(runner)
    end
  end

  if adapter_setting == nil and type(raw_coverage and raw_coverage.lanes or nil) == "table"
      and #raw_coverage.lanes == 0 and lane ~= nil and lane ~= "" then
    adapter_setting = raw_coverage.lanes[lane]
  end
  if adapter_setting == nil then
    adapter_setting = raw_coverage and raw_coverage.adapter or nil
  end
  if adapter_setting == nil then
    return nil, "coverage adapter is required"
  end

  local adapter = adapter_setting
  if type(adapter) == "string" then
    local adapter_path = common.resolve_path(config_dir, adapter)
    local ok, loaded = pcall(dofile, adapter_path)
    if not ok then
      return nil, loaded
    end
    adapter = loaded
  elseif type(adapter) == "function" then
    adapter = adapter()
  end

  if type(adapter) ~= "table" then
    return nil, "coverage adapter must resolve to a table"
  end
  return adapter, nil
end

local function _collect_with_host_config(options)
  _ensure_bridge_package_paths(REPO_ROOT)
  local coverage = require("crap4lua.coverage")
  local raw, load_err = _load_raw_crap_config(options.config)
  if raw == nil then
    return nil, load_err
  end

  local config_dir = common.parent_dir(options.config) or REPO_ROOT
  local raw_coverage = raw.coverage or {}
  local lanes = _resolve_collect_lanes(raw_coverage, options.lanes)
  local selected_lane = lanes[1]
  local adapter, adapter_err = _resolve_adapter_from_config(raw_coverage, config_dir, selected_lane, options.runner)
  if adapter == nil then
    return nil, adapter_err
  end

  local project_root = common.resolve_path(config_dir, raw.project_root or ".")
  if options.project_root ~= nil and options.project_root ~= "" then
    project_root = options.project_root
  end

  local source_roots = _copy_array(raw.source_roots or {})
  local collect_result = coverage.collect({
    project_root = project_root,
    tracked_sources = _copy_array(raw_coverage.tracked_sources or {}),
    source_roots = source_roots,
    lanes = lanes,
    mode = raw_coverage.mode,
    adapter = adapter,
  })

  return {
    project_root = project_root,
    project_name = raw.project_name or "Monopoly",
    source_roots = source_roots,
    coverage_result = collect_result,
  }, nil
end

local function _collect_bridge_result(options, env)
  if type(env.collect_bridge_result) == "function" then
    return env.collect_bridge_result(options)
  end
  return _collect_with_host_config(options)
end

local function _write_collect_output(options, env)
  local result, err = _collect_bridge_result(options, env)
  if result == nil then
    return nil, err
  end
  local ok, write_err = common.write_file(options.out, json_writer.encode(result))
  if not ok then
    return nil, write_err
  end
  return result, nil
end

local function _prepare_report_request(options, env)
  if type(env.prepare_report_request) == "function" then
    return env.prepare_report_request(options)
  end

  local collect_result, err = _collect_bridge_result(options, env)
  if collect_result == nil then
    return nil, err
  end

  local request_path = common.make_temp_path("crap_request", ".json")
  local request_payload = {
    project_root = collect_result.project_root,
    project_name = collect_result.project_name,
    source_roots = collect_result.source_roots,
    coverage_result = collect_result.coverage_result,
    top = options.top,
    strict_tests = options.strict_tests == true,
  }
  local ok, write_err = common.write_file(request_path, json_writer.encode(request_payload))
  if not ok then
    common.remove_path(request_path)
    return nil, write_err
  end
  return request_path, nil
end

local function _launcher_source()
  return table.concat({
    "package main",
    "",
    "import (",
    '\t"os"',
    "",
    '\t"github.com/billyq/crap4lua/internal/cli"',
    ")",
    "",
    "func main() {",
    '\tos.Exit(cli.Main(os.Args))',
    "}",
    "",
  }, "\n")
end

function M.default_tmp_root()
  return _default_tmp_root()
end

function M.default_config_path()
  return DEFAULT_CONFIG_PATH
end

function M.resolve_cli_path(base, path)
  return _resolve_cli_path(base, path)
end

function M.ensure_binary(repo_root, env)
  env = env or {}
  local workspace_root = env.workspace_root or repo_root or REPO_ROOT
  local binary_path = _binary_path(workspace_root)
  if type(env.ensure_binary) == "function" then
    return env.ensure_binary(binary_path)
  end
  if common.path_exists(binary_path) == true then
    return binary_path, nil
  end
  if common.command_exists("go") ~= true then
    return nil, common.bilingual("未找到 go 命令", "go command not found")
  end
  local ok, err = common.ensure_parent_dir(binary_path)
  if not ok then
    return nil, err
  end
  local launcher_dir = common.join_path(CRAP4LUA_ROOT, TMP_BUILD_DIR)
  local launcher_path = common.join_path(launcher_dir, "main.go")
  ok, err = common.write_file(launcher_path, _launcher_source())
  if not ok then
    return nil, err
  end
  local result = common.run_command({ "go", "build", "-o", binary_path, "./" .. TMP_BUILD_DIR }, {
    cwd = CRAP4LUA_ROOT,
  })
  common.remove_path(common.join_path(CRAP4LUA_ROOT, ".monopoly_tmp"))
  if result.ok ~= true then
    return nil, result.output
  end
  return binary_path, nil
end

local function _run_report(options, env)
  local binary_path, build_err = M.ensure_binary(REPO_ROOT, env)
  if binary_path == nil then
    return { ok = false, code = 1, err = build_err }
  end
  local ensure_parent_dir = env.ensure_parent_dir or common.ensure_parent_dir
  local out_ok, out_err = ensure_parent_dir(options.out)
  if not out_ok then
    return { ok = false, code = 1, err = out_err }
  end
  local request_path, req_err = _prepare_report_request(options, env)
  if request_path == nil then
    return { ok = false, code = 1, err = req_err }
  end
  local command = {
    binary_path,
    "report",
    "--request-json", request_path,
    "--response-json", options.out,
  }
  local result = (env.run_command or common.run_command)(command, {
    cwd = REPO_ROOT,
  })
  common.remove_path(request_path)
  return result
end

local function _run_collect(options, env)
  local result, err = _write_collect_output(options, env)
  if result == nil then
    return { ok = false, code = 1, err = err }
  end
  return { ok = true, code = 0, output = "" }
end

local function _run_dry_run(options, env)
  env = env or {}
  local stdout = env.stdout or io.stdout
  local raw, load_err = _load_raw_crap_config(options.config)
  if raw == nil then
    return { ok = false, code = 1, err = load_err }
  end

  local config_dir = common.parent_dir(options.config) or REPO_ROOT
  local raw_coverage = raw.coverage or {}
  local adapter, adapter_err = _resolve_adapter_from_config(raw_coverage, config_dir, options.lane, options.runner)
  if adapter == nil then
    return { ok = false, code = 1, err = adapter_err }
  end

  if type(adapter.discover_specs) ~= "function" then
    return {
      ok = false,
      code = 1,
      err = "adapter does not support dry-run discover_specs(lane)",
    }
  end

  local ok, spec_files_or_err = pcall(adapter.discover_specs, options.lane)
  if not ok then
    return { ok = false, code = 1, err = spec_files_or_err }
  end
  local spec_files = spec_files_or_err or {}
  for _, spec_file in ipairs(spec_files) do
    stdout:write(tostring(spec_file), "\n")
  end
  return { ok = true, code = 0 }
end

local function _run_viewer(options, env)
  local binary_path, build_err = M.ensure_binary(REPO_ROOT, env)
  if binary_path == nil then
    return { ok = false, code = 1, err = build_err }
  end
  local ensure_dir = env.ensure_dir or common.ensure_dir
  local out_ok, out_err = ensure_dir(options.out_dir)
  if not out_ok then
    return { ok = false, code = 1, err = out_err }
  end
  local command = {
    binary_path,
    "viewer",
    "--in-json", options.in_json,
    "--out-dir", options.out_dir,
  }
  if options.open then
    command[#command + 1] = "--open"
  end
  return (env.run_command or common.run_command)(command, {
    cwd = REPO_ROOT,
  })
end

local function _parse_summary_args(args)
  local options = {
    in_json = nil,
    tier_config = common.join_path(REPO_ROOT, "tools/quality/crap/coverage_tiers.lua"),
    out = nil,
    gate = false,
    top = 10,
    lanes = {},
  }
  local index = 1
  while index <= #args do
    local token = args[index]
    if token == "--in-json" then
      index = index + 1
      options.in_json = args[index]
    elseif token == "--tier-config" then
      index = index + 1
      options.tier_config = args[index]
    elseif token == "--out" then
      index = index + 1
      options.out = args[index]
    elseif token == "--gate" then
      options.gate = true
    elseif token == "--top" then
      index = index + 1
      options.top = common.to_integer(args[index]) or 10
    elseif token == "--lane" then
      index = index + 1
      options.lanes[#options.lanes + 1] = args[index]
    else
      error("unknown flag: " .. tostring(token))
    end
    index = index + 1
  end
  if options.in_json ~= nil then
    options.in_json = _resolve_cli_path(REPO_ROOT, options.in_json)
  end
  if options.tier_config ~= nil then
    options.tier_config = _resolve_cli_path(REPO_ROOT, options.tier_config)
  end
  if options.out ~= nil then
    options.out = _resolve_cli_path(REPO_ROOT, options.out)
  end
  return options
end

local function _load_tiers(tier_config_path)
  local ok, result = pcall(dofile, tier_config_path)
  if not ok then
    return nil, common.bilingual("无法加载 tier 配置: ", "Cannot load tier config: ") .. tostring(result)
  end
  if type(result) ~= "table" or type(result.tiers) ~= "table" then
    return nil, common.bilingual(
      "tier 配置格式错误，期望 { tiers = { ... } }",
      "tier config must return { tiers = { ... } }")
  end
  return result.tiers, nil
end

local function _file_tier_index(source_path, tiers)
  for i, tier in ipairs(tiers) do
    for _, prefix in ipairs(tier.includes or {}) do
      local norm = prefix:gsub("/+$", "") .. "/"
      if source_path:sub(1, #norm) == norm then
        return i
      end
    end
  end
  return nil
end

local function _aggregate_from_report(report, tiers)
  local tier_stats = {}
  for i, tier in ipairs(tiers) do
    tier_stats[i] = {
      name = tier.name,
      threshold = tier.threshold or 0,
      exec_lines = 0,
      hit_lines = 0,
      file_stats = {},
    }
  end
  local uncategorized = { exec_lines = 0, hit_lines = 0, file_stats = {} }
  for _, func in ipairs(report.functions or {}) do
    local sp = func.source_path or func.source_name
    if sp ~= nil then
      local exec = func.executable_line_count or 0
      local hit = func.hit_line_count or 0
      local ti = _file_tier_index(sp, tiers)
      local bucket = ti ~= nil and tier_stats[ti] or uncategorized
      bucket.exec_lines = bucket.exec_lines + exec
      bucket.hit_lines = bucket.hit_lines + hit
      if bucket.file_stats[sp] == nil then
        bucket.file_stats[sp] = { exec = 0, hit = 0 }
      end
      bucket.file_stats[sp].exec = bucket.file_stats[sp].exec + exec
      bucket.file_stats[sp].hit = bucket.file_stats[sp].hit + hit
    end
  end
  return tier_stats, uncategorized
end

local function _cov_ratio(hit, exec)
  if exec == 0 then return nil end
  return hit / exec
end

local function _pct_str(hit, exec)
  local r = _cov_ratio(hit, exec)
  if r == nil then return "  N/A " end
  return string.format("%5.1f%%", r * 100)
end

local function _print_coverage_table(tier_stats, uncategorized, options, stdout)
  local lane_label = #(options.lanes or {}) > 0
    and table.concat(options.lanes, "+")
    or "behavior"
  stdout:write("\n覆盖率摘要 (lane: " .. lane_label .. ")\n")
  stdout:write(string.rep("=", 70) .. "\n")
  stdout:write(string.format("%-16s %6s %9s %8s %7s %6s  %s\n",
    "Tier", "文件数", "可执行行", "命中行", "覆盖率", "目标", "状态"))
  stdout:write(string.rep("-", 70) .. "\n")
  local all_pass = true
  for _, ts in ipairs(tier_stats) do
    local file_count = 0
    for _ in pairs(ts.file_stats) do file_count = file_count + 1 end
    local ratio = _cov_ratio(ts.hit_lines, ts.exec_lines)
    local pass = ratio ~= nil and ratio >= ts.threshold
    if not pass then all_pass = false end
    stdout:write(string.format("%-16s %6d %9d %8d %7s %5.0f%%  %s\n",
      ts.name, file_count, ts.exec_lines, ts.hit_lines,
      _pct_str(ts.hit_lines, ts.exec_lines),
      ts.threshold * 100, pass and "PASS" or "FAIL"))
  end
  if uncategorized.exec_lines > 0 then
    local unc_files = 0
    for _ in pairs(uncategorized.file_stats) do unc_files = unc_files + 1 end
    stdout:write(string.format("%-16s %6d %9d %8d %7s   ---  ---\n",
      "(other)", unc_files, uncategorized.exec_lines, uncategorized.hit_lines,
      _pct_str(uncategorized.hit_lines, uncategorized.exec_lines)))
  end
  stdout:write(string.rep("=", 70) .. "\n")
  local top_n = options.top or 10
  if top_n > 0 then
    for _, ts in ipairs(tier_stats) do
      local ratio = _cov_ratio(ts.hit_lines, ts.exec_lines)
      if ratio == nil or ratio < ts.threshold then
        local files = {}
        for path, fs in pairs(ts.file_stats) do
          if fs.exec > 0 then
            files[#files + 1] = { path = path, exec = fs.exec, hit = fs.hit }
          end
        end
        table.sort(files, function(a, b)
          return (a.exec - a.hit) > (b.exec - b.hit)
        end)
        local n = math.min(top_n, #files)
        if n > 0 then
          stdout:write("\n未达标 [" .. ts.name .. "] — 未覆盖行最多 top " .. tostring(n) .. ":\n")
          for i = 1, n do
            local f = files[i]
            stdout:write(string.format("  %-52s %5d/%5d 行  %s\n",
              f.path, f.hit, f.exec, _pct_str(f.hit, f.exec)))
          end
        end
      end
    end
  end
  stdout:write("\n")
  return all_pass
end

local function _run_summary(options, env)
  env = env or {}
  local stdout = env.stdout or io.stdout
  local stderr = env.stderr or io.stderr

  local in_json = options.in_json
  if in_json == nil then
    in_json = _resolve_cli_path(REPO_ROOT, DEFAULT_REPORT_JSON)
  end

  if not common.path_exists(in_json) then
    local rargs = { "--out", _resolve_cli_path(REPO_ROOT, DEFAULT_REPORT_JSON) }
    for _, l in ipairs(options.lanes or {}) do
      rargs[#rargs + 1] = "--lane"
      rargs[#rargs + 1] = l
    end
    local report_opts = _parse_report_args(rargs)
    local report_result = _run_report(report_opts, env)
    if report_result.ok ~= true then
      stderr:write(tostring(report_result.err or report_result.output or ""), "\n")
      return { ok = false, code = report_result.code or 1 }
    end
    in_json = report_opts.out
  end

  local json_text, read_err = common.read_file(in_json)
  if json_text == nil then
    stderr:write(common.bilingual("无法读取报告: ", "Cannot read report: ") .. tostring(read_err) .. "\n")
    return { ok = false, code = 1 }
  end
  local json_reader = require("shared.lib.json_reader")
  local ok_parse, report = pcall(json_reader.decode, json_text)
  if not ok_parse or type(report) ~= "table" then
    stderr:write(common.bilingual("JSON 解析失败: ", "JSON parse error: ") .. tostring(report) .. "\n")
    return { ok = false, code = 1 }
  end
  if type(report.functions) ~= "table" then
    stderr:write(common.bilingual(
      "crap_report.json 缺少 functions 字段，请先跑 crap.lua report\n",
      "crap_report.json missing functions field, run crap.lua report first\n"))
    return { ok = false, code = 1 }
  end

  local tier_config_path = options.tier_config
    or common.join_path(REPO_ROOT, "tools/quality/crap/coverage_tiers.lua")
  local tiers, tier_err = _load_tiers(tier_config_path)
  if tiers == nil then
    stderr:write(tostring(tier_err) .. "\n")
    return { ok = false, code = 1 }
  end

  local tier_stats, uncategorized = _aggregate_from_report(report, tiers)
  local all_pass = _print_coverage_table(tier_stats, uncategorized, options, stdout)
  local summary_out = nil

  if options.out ~= nil then
    local out_rows = {}
    for _, ts in ipairs(tier_stats) do
      local fc = 0
      for _ in pairs(ts.file_stats) do fc = fc + 1 end
      local ratio = _cov_ratio(ts.hit_lines, ts.exec_lines)
      out_rows[#out_rows + 1] = {
        name = ts.name,
        threshold = ts.threshold,
        file_count = fc,
        exec_lines = ts.exec_lines,
        hit_lines = ts.hit_lines,
        coverage = ratio or 0,
        pass = ratio ~= nil and ratio >= ts.threshold,
      }
    end
    local ok_w, w_err = common.write_file(options.out, json_writer.encode({ tiers = out_rows }))
    if not ok_w then
      stderr:write(tostring(w_err) .. "\n")
    else
      summary_out = options.out
    end
  end

  if options.gate and not all_pass then
    return { ok = false, code = 1 }
  end
  return { ok = true, code = 0, summary_out = summary_out }
end

local function _run_internal(args, env)
  env = env or {}
  local stdout = env.stdout or io.stdout
  local stderr = env.stderr or io.stderr
  local command_name = env.command_name or "tools/quality/crap.lua"
  local argv = _copy_args(args or arg or {})

  if #argv == 0 then
    local report_options = _parse_report_args({ "--out", DEFAULT_REPORT_JSON })
    local report_result = _run_report(report_options, env)
    if report_result.ok ~= true then
      stderr:write(tostring(report_result.err or report_result.output or ""), "\n")
      return { ok = false, code = report_result.code or 1 }
    end
    _write_success_path(stdout, report_result.output, "crap report json", report_options.out)
    local viewer_result = _run_viewer(_parse_viewer_args({ "--in-json", DEFAULT_REPORT_JSON, "--out-dir", DEFAULT_VIEW_DIR, "--open" }), env)
    if viewer_result.ok ~= true then
      stderr:write(tostring(viewer_result.err or viewer_result.output or ""), "\n")
      return { ok = false, code = viewer_result.code or 1 }
    end
    _write_success_path(stdout, viewer_result.output, "crap viewer index",
      common.join_path(_resolve_cli_path(REPO_ROOT, DEFAULT_VIEW_DIR), "index.html"))
    return { ok = true, code = 0 }
  end

  local first = argv[1]
  if first == "help" or first == "--help" or first == "-h" then
    stdout:write(_help_text(command_name))
    return { ok = true, code = 0 }
  end

  if first == "collect" then
    local ok, options_or_err = pcall(_parse_collect_args, { select(2, table.unpack(argv)) })
    if not ok then
      stderr:write(tostring(options_or_err), "\n")
      stderr:write(_help_text(command_name))
      return { ok = false, code = 1 }
    end
    local result = _run_collect(options_or_err, env)
    if result.ok ~= true then
      stderr:write(tostring(result.err or result.output or ""), "\n")
      return { ok = false, code = result.code or 1 }
    end
    _write_success_path(stdout, result.output, "crap collect json", options_or_err.out)
    return { ok = true, code = result.code or 0 }
  end

  if first == "dry-run" then
    local ok, options_or_err = pcall(_parse_dry_run_args, { select(2, table.unpack(argv)) })
    if not ok then
      stderr:write(tostring(options_or_err), "\n")
      stderr:write(_help_text(command_name))
      return { ok = false, code = 1 }
    end
    local result = _run_dry_run(options_or_err, env)
    if result.ok ~= true then
      stderr:write(tostring(result.err or result.output or ""), "\n")
      return { ok = false, code = result.code or 1 }
    end
    if result.output and result.output ~= "" then
      stdout:write(result.output)
    end
    return { ok = true, code = result.code or 0 }
  end

  if first == "report" then
    local ok, options_or_err = pcall(_parse_report_args, { select(2, table.unpack(argv)) })
    if not ok then
      stderr:write(tostring(options_or_err), "\n")
      stderr:write(_help_text(command_name))
      return { ok = false, code = 1 }
    end
    local result = _run_report(options_or_err, env)
    if result.ok ~= true then
      stderr:write(tostring(result.err or result.output or ""), "\n")
      return { ok = false, code = result.code or 1 }
    end
    _write_success_path(stdout, result.output, "crap report json", options_or_err.out)
    return { ok = true, code = result.code or 0 }
  end

  if first == "viewer" then
    local ok, options_or_err = pcall(_parse_viewer_args, { select(2, table.unpack(argv)) })
    if not ok then
      stderr:write(tostring(options_or_err), "\n")
      stderr:write(_help_text(command_name))
      return { ok = false, code = 1 }
    end
    local options = options_or_err
    if options.in_json == nil then
      local report_options = _parse_report_args({ "--out", DEFAULT_REPORT_JSON })
      local report_result = _run_report(report_options, env)
      if report_result.ok ~= true then
        stderr:write(tostring(report_result.err or report_result.output or ""), "\n")
        return { ok = false, code = report_result.code or 1 }
      end
      options.in_json = _resolve_cli_path(REPO_ROOT, DEFAULT_REPORT_JSON)
    end
    local result = _run_viewer(options, env)
    if result.ok ~= true then
      stderr:write(tostring(result.err or result.output or ""), "\n")
      return { ok = false, code = result.code or 1 }
    end
    _write_success_path(stdout, result.output, "crap viewer index",
      common.join_path(options.out_dir, "index.html"))
    return { ok = true, code = result.code or 0 }
  end

  if first == "summary" then
    local ok, options_or_err = pcall(_parse_summary_args, { select(2, table.unpack(argv)) })
    if not ok then
      stderr:write(tostring(options_or_err), "\n")
      stderr:write(_help_text(command_name))
      return { ok = false, code = 1 }
    end
    local result = _run_summary(options_or_err, env)
    if result.ok ~= true then
      stderr:write(tostring(result.err or result.output or ""), "\n")
      return { ok = false, code = result.code or 1 }
    end
    if result.summary_out ~= nil then
      stdout:write("crap summary json: " .. common.normalize_path(result.summary_out) .. "\n")
    end
    return { ok = true, code = result.code or 0 }
  end

  stderr:write(common.bilingual("未知命令: " .. tostring(first), "Unknown command: " .. tostring(first)), "\n")
  stderr:write(_help_text(command_name))
  return { ok = false, code = 1 }
end

function M.run(args, env)
  return _run_internal(args, env).ok
end

function M.main()
  return _run_internal(arg or {}, nil).code
end

if ... == "quality.crap" then
  return M
end

os.exit(M.main())
