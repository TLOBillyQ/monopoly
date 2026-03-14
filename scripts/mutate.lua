local function _normalize_path(path)
  return tostring(path or ""):gsub("\\", "/")
end

local function _module_dir()
  local source = debug.getinfo(1, "S").source or "@scripts/mutate.lua"
  local normalized = _normalize_path(source):gsub("^@", "")
  return normalized:match("^(.*)/[^/]+$") or "scripts"
end

local function _append_path(path_pattern)
  if not tostring(package.path):find(path_pattern, 1, true) then
    package.path = path_pattern .. ";" .. package.path
  end
end

local function _join_path(base, child)
  local normalized_base = _normalize_path(base):gsub("/+$", "")
  local normalized_child = _normalize_path(child):gsub("^/+", "")
  if normalized_base == "" then
    return normalized_child
  end
  if normalized_child == "" then
    return normalized_base
  end
  return normalized_base .. "/" .. normalized_child
end

local SCRIPT_DIR = _module_dir()
local REPO_ROOT = _normalize_path(SCRIPT_DIR .. "/..")
local MUTATE4LUA_ROOT = _normalize_path(REPO_ROOT .. "/vendor/mutate4lua")
local DEFAULT_DRIVER_PATH = "scripts/quality/mutate_monopoly_driver.lua"

local function _install_package_paths()
  local patterns = {
    MUTATE4LUA_ROOT .. "/src/?.lua",
    MUTATE4LUA_ROOT .. "/src/?/init.lua",
    REPO_ROOT .. "/?.lua",
    REPO_ROOT .. "/?/?.lua",
    REPO_ROOT .. "/?/init.lua",
    REPO_ROOT .. "/tests/?.lua",
    REPO_ROOT .. "/tests/?/init.lua",
    SCRIPT_DIR .. "/?.lua",
    SCRIPT_DIR .. "/?/?.lua",
  }

  for _, pattern in ipairs(patterns) do
    _append_path(pattern)
  end
end

local function _has_option(args, option_name)
  for _, value in ipairs(args or {}) do
    if value == option_name then
      return true
    end
  end
  return false
end

local function _help_text(command_name, upstream_usage)
  return table.concat({
    "用法: lua " .. tostring(command_name) .. " <file.lua> [--lane behavior|contract] [--mode MODE] [mutate4lua 原生参数]",
    "Usage: lua " .. tostring(command_name) .. " <file.lua> [--lane behavior|contract] [--mode MODE] [upstream mutate4lua args]",
    "",
    "Monopoly 选项 / Monopoly options:",
    "  --lane behavior|contract   默认 behavior；contract 固定走 dev mode",
    "  --mode MODE                仅 behavior lane 使用，常见值 dev / release_trimmed",
    "",
    "默认测试命令 / Default test command:",
    "  lua " .. DEFAULT_DRIVER_PATH .. " --lane behavior --coverage-file <tmp>",
    "",
    "上游 mutate4lua 帮助 / Upstream mutate4lua help:",
    tostring(upstream_usage or ""),
  }, "\n")
end

local function _parse_args(args)
  local options = {
    help = false,
    lane = "behavior",
    mode = nil,
    passthrough = {},
  }

  local index = 1
  while index <= #args do
    local token = args[index]
    if token == "--help" or token == "-h" then
      options.help = true
    elseif token == "--lane" then
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
    else
      options.passthrough[#options.passthrough + 1] = token
    end
    index = index + 1
  end

  return options
end

_install_package_paths()

local M = {}

local mutate_util = require("mutate4lua.util")

function M.build_default_test_command(opts)
  opts = opts or {}
  local lane = opts.lane or "behavior"
  local command = {
    "lua",
    tostring(opts.driver_path or DEFAULT_DRIVER_PATH),
    "--lane",
    lane,
  }

  if lane == "behavior" and opts.mode ~= nil and tostring(opts.mode) ~= "" then
    command[#command + 1] = "--mode"
    command[#command + 1] = tostring(opts.mode)
  end

  return command
end

function M.list_project_hash_files(project_root, env)
  env = env or {}
  if type(env.list_project_files) == "function" then
    return env.list_project_files(project_root)
  end

  local command = table.concat({
    "git",
    "-C",
    mutate_util.shell_quote(project_root),
    "ls-files",
    "--cached",
    "--others",
    "--exclude-standard",
    "--",
    mutate_util.shell_quote("*.lua"),
    mutate_util.shell_quote("*.rockspec"),
  }, " ")
  local output, err = mutate_util.capture(command)
  if output == nil then
    return nil, err
  end

  local files = {}
  for line in tostring(output):gmatch("[^\n]+") do
    local normalized = _normalize_path(line)
    if normalized ~= "" then
      files[#files + 1] = normalized
    end
  end
  return files
end

function M.build_project_hash(project_root, target_file, stripped_source, env)
  env = env or {}
  local original_project_hash = env.original_project_hash
  local files, err = M.list_project_hash_files(project_root, env)
  if files == nil then
    if type(original_project_hash) == "function" then
      return original_project_hash(project_root, target_file, stripped_source)
    end
    error(err or "failed to list project hash files")
  end

  local hash_text = env.hash_text or mutate_util.fnv1a64
  local read_file = env.read_file or mutate_util.read_file
  local normalize_newlines = env.normalize_newlines or mutate_util.normalize_newlines
  local normalized_root = _normalize_path(project_root):gsub("/+$", "")
  local normalized_target = _normalize_path(target_file)
  local prefix = normalized_root .. "/"
  if normalized_target:sub(1, #prefix) ~= prefix then
    if type(original_project_hash) == "function" then
      return original_project_hash(project_root, target_file, stripped_source)
    end
    error("target file is outside project root: " .. tostring(target_file))
  end

  local target_relative = normalized_target:sub(#prefix + 1)
  local parts = {}
  for _, relative_path in ipairs(files) do
    local content = nil
    if relative_path == target_relative then
      content = stripped_source
    else
      content = read_file(_join_path(project_root, relative_path))
    end

    if content == nil then
      if type(original_project_hash) == "function" then
        return original_project_hash(project_root, target_file, stripped_source)
      end
      error("failed to read file for project hash: " .. tostring(relative_path))
    end

    parts[#parts + 1] = relative_path
    parts[#parts + 1] = "\n"
    parts[#parts + 1] = normalize_newlines(content)
    parts[#parts + 1] = "\n\0\n"
  end

  return hash_text(table.concat(parts))
end

function M.run(args, env)
  env = env or {}
  local main_module = env.main_module or require("mutate4lua.main")
  local project_module = env.project_module or require("mutate4lua.project")
  local stdout = env.stdout or io.stdout
  local stderr = env.stderr or io.stderr
  local command_name = env.command_name or "scripts/mutate.lua"
  local workspace_root = env.workspace_root or REPO_ROOT

  local ok, parsed_or_err = pcall(_parse_args, args or arg or {})
  if not ok then
    stderr:write(tostring(parsed_or_err), "\n")
    stdout:write(_help_text(command_name, main_module.usage()))
    return 1
  end

  local options = parsed_or_err
  if options.help then
    stdout:write(_help_text(command_name, main_module.usage()))
    return 0
  end

  local original_default_test_command = project_module.default_test_command
  local original_project_hash = project_module.project_hash
  local has_explicit_test_command = _has_option(options.passthrough, "--test-command")

  if not has_explicit_test_command then
    project_module.default_test_command = function()
      return M.build_default_test_command({
        driver_path = env.driver_path or DEFAULT_DRIVER_PATH,
        lane = options.lane,
        mode = options.mode,
      })
    end
  end

  project_module.project_hash = function(project_root, target_file, stripped_source)
    local project_hash_env = {}
    for key, value in pairs(env.project_hash_env or {}) do
      project_hash_env[key] = value
    end
    project_hash_env.original_project_hash = original_project_hash
    return M.build_project_hash(project_root, target_file, stripped_source, project_hash_env)
  end

  local run_ok, result = xpcall(function()
    return main_module.run(options.passthrough, workspace_root, stdout, stderr)
  end, debug.traceback)
  project_module.default_test_command = original_default_test_command
  project_module.project_hash = original_project_hash

  if not run_ok then
    error(result)
  end

  return result
end

function M.main()
  return M.run(arg or {})
end

if ... == "mutate" then
  return M
end

os.exit(M.main())
