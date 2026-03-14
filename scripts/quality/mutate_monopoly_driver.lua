local bootstrap = require("tests.bootstrap")
local catalog = require("tests.catalog")
local harness = require("TestHarness")
local regression_mode = require("tests.support.regression_mode")

bootstrap.install_package_paths()

local function _normalize_path(path)
  return tostring(path or ""):gsub("\\", "/")
end

local function _current_dir()
  local process = io.popen("pwd", "r")
  if process == nil then
    return "."
  end
  local path = process:read("*l") or "."
  process:close()
  return _normalize_path(path)
end

local function _help_text(command_name)
  return table.concat({
    "用法: lua " .. tostring(command_name) .. " --lane behavior|contract [--mode MODE] --coverage-file PATH [--target-file FILE] [--project-hash HASH]",
    "Usage: lua " .. tostring(command_name) .. " --lane behavior|contract [--mode MODE] --coverage-file PATH [--target-file FILE] [--project-hash HASH]",
    "",
    "behavior 会走 tests/catalog.lua + regression_mode。",
    "behavior uses tests/catalog.lua plus regression_mode.",
    "contract 固定跑 dev mode。",
    "contract always runs in dev mode.",
    "",
  }, "\n")
end

local function _parse_args(args)
  local options = {
    lane = "behavior",
    mode = nil,
    coverage_file = nil,
    target_file = nil,
    project_hash = nil,
    suite_module = nil,
    help = false,
  }

  local index = 1
  while index <= #args do
    local token = args[index]
    if token == "--lane" then
      index = index + 1
      local lane = args[index]
      if lane ~= "behavior" and lane ~= "contract" then
        error("unsupported lane: " .. tostring(lane))
      end
      options.lane = lane
    elseif token == "--mode" then
      index = index + 1
      local mode = args[index]
      if mode == nil or mode == "" then
        error("--mode requires a value")
      end
      options.mode = mode
    elseif token == "--coverage-file" then
      index = index + 1
      local path = args[index]
      if path == nil or path == "" then
        error("--coverage-file requires a value")
      end
      options.coverage_file = path
    elseif token == "--target-file" then
      index = index + 1
      local path = args[index]
      if path == nil or path == "" then
        error("--target-file requires a value")
      end
      options.target_file = path
    elseif token == "--project-hash" then
      index = index + 1
      local project_hash = args[index]
      if project_hash == nil or project_hash == "" then
        error("--project-hash requires a value")
      end
      options.project_hash = project_hash
    elseif token == "--suite-module" then
      index = index + 1
      local suite_module = args[index]
      if suite_module == nil or suite_module == "" then
        error("--suite-module requires a value")
      end
      options.suite_module = suite_module
    elseif token == "--help" or token == "-h" then
      options.help = true
    else
      error("Unknown flag: " .. tostring(token))
    end
    index = index + 1
  end

  if not options.help and (options.coverage_file == nil or options.coverage_file == "") then
    error("--coverage-file requires a value")
  end

  return options
end

local function _resolve_lane_suites(lane, mode)
  if lane == "behavior" then
    return catalog.load_behavior_suites(), regression_mode.resolve_behavior_mode(mode)
  end
  if lane == "contract" then
    return catalog.load_contract_suites(), "dev"
  end
  error("unsupported lane: " .. tostring(lane))
end

local function _write_coverage(path, lines)
  local keys = {}
  for key in pairs(lines or {}) do
    keys[#keys + 1] = key
  end
  table.sort(keys)

  local handle, err = io.open(path, "wb")
  if handle == nil then
    return nil, err
  end

  if #keys > 0 then
    handle:write(table.concat(keys, "\n"))
    handle:write("\n")
  end
  handle:close()
  return true
end

local function _collect_coverage(lines, project_root, debug_api)
  return function()
    local info = debug_api.getinfo(2, "Sl")
    if info == nil or info.source == nil or info.source:sub(1, 1) ~= "@" then
      return
    end

    local source_path = _normalize_path(info.source:sub(2))
    if source_path:match("^%a:/") == nil and source_path:sub(1, 1) ~= "/" then
      source_path = _normalize_path(project_root .. "/" .. source_path)
    end

    local prefix = project_root:gsub("/+$", "") .. "/"
    if source_path:sub(1, #prefix) ~= prefix then
      return
    end
    if source_path:match("%.lua$") == nil then
      return
    end

    local relative_path = source_path:sub(#prefix + 1)
    lines[relative_path .. ":" .. tostring(info.currentline)] = true
  end
end

local function _suite_key(suite, suite_index)
  return tostring((suite and suite.module_name) or (suite and suite.name) or ("suite_" .. tostring(suite_index)))
end

local function _filter_suite_module(suites, suite_module)
  if suite_module == nil then
    return suites
  end
  local filtered = {}
  for suite_index, suite in ipairs(suites or {}) do
    if _suite_key(suite, suite_index) == suite_module then
      filtered[#filtered + 1] = suite
    end
  end
  return filtered
end

local function _silent_reporter()
  return {
    case_pass = function() end,
    case_fail = function() end,
    finish = function() end,
  }
end

local M = {}

function M.select_suites_for_target(_project_root, _lane, _mode, _target_file, _project_hash, suites, env)
  env = env or {}
  local load_suite_index = env.load_suite_index
  if type(load_suite_index) ~= "function" then
    return suites
  end
  local suite_index = load_suite_index()
  if type(suite_index) ~= "table" or _target_file == nil or _target_file == "" or _lane ~= "behavior" then
    return suites
  end
  local normalized_target = _normalize_path(_target_file):gsub("^%./", "")
  local selected = {}
  for suite_index_number, suite in ipairs(suites or {}) do
    local suite_key = _suite_key(suite, suite_index_number)
    if suite_index[suite_key] and suite_index[suite_key][normalized_target] then
      selected[#selected + 1] = suite
    end
  end
  return selected
end

function M.run(args, env)
  env = env or {}
  local stdout = env.stdout or io.stdout
  local stderr = env.stderr or io.stderr
  local command_name = env.command_name or "scripts/quality/mutate_monopoly_driver.lua"
  local debug_api = env.debug_api or debug
  local project_root = _normalize_path(env.project_root or _current_dir())
  local resolve_lane_suites = env.resolve_lane_suites or _resolve_lane_suites
  local run_all = env.run_all or harness.run_all

  local ok, parsed_or_err = pcall(_parse_args, args or arg or {})
  if not ok then
    stderr:write(tostring(parsed_or_err), "\n")
    stdout:write(_help_text(command_name))
    return 1
  end

  local options = parsed_or_err
  if options.help then
    stdout:write(_help_text(command_name))
    return 0
  end

  local suites, mode = resolve_lane_suites(options.lane, options.mode)
  suites = _filter_suite_module(suites, options.suite_module)
  local coverage_lines = {}
  debug_api.sethook(_collect_coverage(coverage_lines, project_root, debug_api), "l")

  local run_ok, run_result = xpcall(function()
    local run_opts = {
      mode = mode,
      capture_logs = true,
    }
    if options.suite_module ~= nil then
      run_opts.capture_logs = false
      run_opts.reporter = _silent_reporter()
      run_opts.raise_on_failure = false
      run_opts.quiet = true
    end
    return run_all(suites, run_opts)
  end, debug.traceback)

  debug_api.sethook()

  local write_ok, write_err = _write_coverage(options.coverage_file, coverage_lines)
  if write_ok == nil then
    stderr:write(tostring(write_err), "\n")
    return 1
  end

  if not run_ok then
    stderr:write(tostring(run_result), "\n")
    return 1
  end

  if type(run_result) == "table" and run_result.failed == true then
    stderr:write("regression failed\n")
    return 1
  end
  if run_result == false then
    stderr:write("regression failed\n")
    return 1
  end

  return 0
end

function M.main()
  return M.run(arg or {})
end

if ... == "quality.mutate_monopoly_driver" then
  return M
end

os.exit(M.main())
