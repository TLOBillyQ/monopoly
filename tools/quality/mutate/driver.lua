local bootstrap = require("spec.bootstrap")
local catalog = require("tools.quality.shared.test_catalog")
local harness = require("tools.quality.shared.test_harness")
local common = require("shared.lib.common")
local config_reset = require("spec.support.config_reset")

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
    "用法: lua " .. tostring(command_name) .. " --lane behavior|contract [--coverage-file PATH] [--target-file FILE] [--project-hash HASH] [--suite-module NAME] [--suite-list-file PATH] [--list-suites] [--json] [--no-coverage] [--quiet]",
    "Usage: lua " .. tostring(command_name) .. " --lane behavior|contract [--coverage-file PATH] [--target-file FILE] [--project-hash HASH] [--suite-module NAME] [--suite-list-file PATH] [--list-suites] [--json] [--no-coverage] [--quiet]",
    "",
    "behavior 会走 tests/catalog.lua 单一路径回归。",
    "behavior uses tests/catalog.lua in a single regression path.",
    "contract 会走契约套件，不再区分额外运行形态。",
    "contract uses contract suites without alternate runtime variants.",
    "",
  }, "\n")
end

local function _parse_args(args)
  local options = {
    lane = "behavior",
    coverage_file = nil,
    target_file = nil,
    project_hash = nil,
    suite_module = nil,
    suite_list_file = nil,
    list_suites = false,
    emit_suite_file_map_json = false,
    json = false,
    no_coverage = false,
    quiet = false,
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
    elseif token == "--suite-list-file" then
      index = index + 1
      local suite_list_file = args[index]
      if suite_list_file == nil or suite_list_file == "" then
        error("--suite-list-file requires a value")
      end
      options.suite_list_file = suite_list_file
    elseif token == "--list-suites" then
      options.list_suites = true
    elseif token == "--emit-suite-file-map-json" then
      options.emit_suite_file_map_json = true
    elseif token == "--json" then
      options.json = true
    elseif token == "--no-coverage" then
      options.no_coverage = true
    elseif token == "--quiet" then
      options.quiet = true
    elseif token == "--help" or token == "-h" then
      options.help = true
    else
      error("Unknown flag: " .. tostring(token))
    end
    index = index + 1
  end

  if not options.help
    and not options.list_suites
    and not options.emit_suite_file_map_json
    and not options.no_coverage
    and (options.coverage_file == nil or options.coverage_file == "")
  then
    error("--coverage-file requires a value")
  end

  return options
end

local function _resolve_lane_suites(lane)
  if lane == "behavior" then
    return catalog.load_behavior_suites()
  end
  if lane == "contract" then
    return catalog.load_contract_suites()
  end
  error("unsupported lane: " .. tostring(lane))
end

local function _write_coverage(path, lines)
  local keys = {}
  local ok, err = common.ensure_parent_dir(path)
  if not ok then
    return nil, err
  end
  for key in pairs(lines or {}) do
    keys[#keys + 1] = key
  end
  table.sort(keys)

  local handle, open_err = io.open(path, "wb")
  if handle == nil then
    return nil, open_err
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

local function _silent_reporter()
  return {
    case_pass = function() end,
    case_fail = function() end,
    finish = function() end,
  }
end

local function _suite_key(suite, suite_index)
  return tostring((suite and suite.module_name) or (suite and suite.name) or ("suite_" .. tostring(suite_index)))
end

local function _read_suite_list_file(path)
  local handle = io.open(path, "rb")
  if handle == nil then
    return nil, "cannot open suite list: " .. tostring(path)
  end
  local content = handle:read("*a") or ""
  handle:close()
  local selected = {}
  for line in tostring(content):gmatch("[^\r\n]+") do
    if line ~= "" then
      selected[line] = true
    end
  end
  return selected
end

local function _filter_suites(suites, suite_module, suite_list_file)
  local selected_lookup = nil
  if suite_list_file ~= nil then
    local loaded, err = _read_suite_list_file(suite_list_file)
    if loaded == nil then
      error(err)
    end
    selected_lookup = loaded
  end

  if suite_module == nil and selected_lookup == nil then
    return suites
  end

  local filtered = {}
  for suite_index, suite in ipairs(suites or {}) do
    local key = _suite_key(suite, suite_index)
    if suite_module ~= nil then
      if key == suite_module then
        filtered[#filtered + 1] = suite
      end
    elseif selected_lookup[key] == true then
      filtered[#filtered + 1] = suite
    end
  end
  return filtered
end

local function _encode_json_array(values)
  local parts = {}
  for _, value in ipairs(values or {}) do
    parts[#parts + 1] = string.format("%q", tostring(value))
  end
  return "[" .. table.concat(parts, ",") .. "]"
end

local function _encode_json_string_map_of_arrays(map)
  local keys = {}
  for key in pairs(map or {}) do
    keys[#keys + 1] = key
  end
  table.sort(keys)
  local parts = {}
  for _, key in ipairs(keys) do
    parts[#parts + 1] = string.format("%q", tostring(key)) .. ":" .. _encode_json_array(map[key] or {})
  end
  return "{" .. table.concat(parts, ",") .. "}"
end

local function _encode_suite_file_map_payload(payload)
  return "{"
    .. string.format("%q", "lane") .. ":" .. string.format("%q", tostring(payload.lane or ""))
    .. "," .. string.format("%q", "suite_files") .. ":" .. _encode_json_string_map_of_arrays(payload.suite_files or {})
    .. "}"
end

local function _resolve_repo_relative_lua_path(source, project_root)
  if source == nil or source:sub(1, 1) ~= "@" then
    return nil
  end

  local source_path = _normalize_path(source:sub(2))
  if source_path:match("^%a:/") == nil and source_path:sub(1, 1) ~= "/" then
    source_path = _normalize_path(project_root .. "/" .. source_path)
  end

  local prefix = project_root:gsub("/+$", "") .. "/"
  if source_path:sub(1, #prefix) ~= prefix then
    return nil
  end
  if source_path:match("%.lua$") == nil then
    return nil
  end

  return source_path:sub(#prefix + 1)
end

local function _sorted_suite_file_map(suite_files)
  local normalized = {}
  for suite_key, file_lookup in pairs(suite_files or {}) do
    local files = {}
    for path in pairs(file_lookup or {}) do
      files[#files + 1] = path
    end
    table.sort(files)
    normalized[suite_key] = files
  end
  return normalized
end

local function _collect_suite_file_map(current_suite_ref, suite_files, project_root, debug_api)
  return function()
    local suite_key = current_suite_ref.key
    if suite_key == nil then
      return
    end

    local info = debug_api.getinfo(2, "S")
    local relative_path = info and _resolve_repo_relative_lua_path(info.source, project_root) or nil
    if relative_path == nil then
      return
    end

    local file_lookup = suite_files[suite_key]
    if file_lookup == nil then
      file_lookup = {}
      suite_files[suite_key] = file_lookup
    end
    file_lookup[relative_path] = true
  end
end

local M = {}

function M.list_suite_modules(lane, env)
  env = env or {}
  local resolve_lane_suites = env.resolve_lane_suites or _resolve_lane_suites
  local suites = resolve_lane_suites(lane)
  local modules = {}
  for suite_index, suite in ipairs(suites or {}) do
    modules[#modules + 1] = _suite_key(suite, suite_index)
  end
  table.sort(modules)
  return modules
end

function M.run(args, env)
  env = env or {}
  local stdout = env.stdout or io.stdout
  local stderr = env.stderr or io.stderr
  local command_name = env.command_name or "tools/quality/mutate/driver.lua"
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

  if options.list_suites then
    local modules = M.list_suite_modules(options.lane, { resolve_lane_suites = resolve_lane_suites })
    if options.json then
      stdout:write(_encode_json_array(modules), "\n")
    else
      stdout:write(table.concat(modules, "\n"), "\n")
    end
    return 0
  end

  local suites = resolve_lane_suites(options.lane)
  suites = _filter_suites(suites, options.suite_module, options.suite_list_file)

  if options.emit_suite_file_map_json then
    local current_suite = { key = nil }
    local suite_files = {}
    for suite_index, suite in ipairs(suites or {}) do
      suite_files[_suite_key(suite, suite_index)] = {}
    end
    debug_api.sethook(_collect_suite_file_map(current_suite, suite_files, project_root, debug_api), "c")

    local run_ok, run_result = xpcall(function()
      local run_opts = {
        capture_logs = true,
        quiet = true,
        reporter = _silent_reporter(),
        raise_on_failure = false,
        before_case = function(context)
          config_reset.reset_all()
          current_suite.key = context.suite_module or context.suite_name
        end,
        after_case = function()
          current_suite.key = nil
          config_reset.reset_all()
        end,
      }
      return run_all(suites, run_opts)
    end, debug.traceback)

    debug_api.sethook()

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

    stdout:write(_encode_suite_file_map_payload({
      lane = options.lane,
      suite_files = _sorted_suite_file_map(suite_files),
    }), "\n")
    return 0
  end

  local coverage_lines = {}
  if not options.no_coverage then
    debug_api.sethook(_collect_coverage(coverage_lines, project_root, debug_api), "l")
  end

  local run_ok, run_result = xpcall(function()
    local run_opts = {
      capture_logs = true,
      before_case = function() config_reset.reset_all() end,
      after_case = function() config_reset.reset_all() end,
    }
    if options.quiet then
      run_opts.reporter = _silent_reporter()
      run_opts.raise_on_failure = false
      run_opts.quiet = true
    end
    return run_all(suites, run_opts)
  end, debug.traceback)

  if not options.no_coverage then
    debug_api.sethook()
    local write_ok, write_err = _write_coverage(options.coverage_file, coverage_lines)
    if write_ok == nil then
      stderr:write(tostring(write_err), "\n")
      return 1
    end
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

if ... == "quality.mutate.driver" then
  return M
end

os.exit(M.main())
