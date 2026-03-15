local package_path_helper = dofile("scripts/shared/package_path_helper.lua")
package_path_helper.install_monopoly_package_paths({ repo_root = "." })

local common = require("shared.lib.common")

local function _normalize_path(path)
  return common.normalize_path(path)
end

local function _module_dir()
  local source = debug.getinfo(1, "S").source or "@scripts/quality/mutate.lua"
  local normalized = _normalize_path(source):gsub("^@", "")
  return normalized:match("^(.*)/[^/]+$") or "scripts"
end

local SCRIPT_DIR = common.resolve_path(common.current_dir(), _module_dir())
local REPO_ROOT = common.resolve_path(SCRIPT_DIR, "../..")
local MUTATE4LUA_ROOT = common.join_path(REPO_ROOT, "vendor/mutate4lua")
local DEFAULT_DRIVER_PATH = "scripts/quality/mutate/driver.lua"

local function _binary_path(repo_root)
  local name = "mutate4lua-engine"
  if common.is_windows() then
    name = name .. ".exe"
  end
  return common.join_path(common.join_path(repo_root, "vendor/mutate4lua"), "bin/" .. name)
end

local function _help_text(command_name)
  return table.concat({
    "用法: lua " .. tostring(command_name) .. " <file.lua> [--lane behavior|contract] [--mode MODE] [--scan|--update-manifest|--since-last-run|--mutate-all|--lines N,N] [--max-workers N] [--timeout-factor N] [--test-command CMD] [--json]",
    "Usage: lua " .. tostring(command_name) .. " <file.lua> [--lane behavior|contract] [--mode MODE] [--scan|--update-manifest|--since-last-run|--mutate-all|--lines N,N] [--max-workers N] [--timeout-factor N] [--test-command CMD] [--json]",
    "",
    "Monopoly 选项 / Monopoly options:",
    "  --lane behavior|contract   默认 behavior；contract 固定走 dev mode",
    "  --mode MODE                仅 behavior lane 使用，常见值 dev / release_trimmed",
    "  --index-suites             显式预热 behavior suite index",
  }, "\n")
end

local function _parse_args(args)
  local options = {
    help = false,
    index_suites = false,
    target = nil,
    passthrough = {},
  }

  local index = 1
  while index <= #args do
    local token = args[index]
    if token == "--help" or token == "-h" then
      options.help = true
    elseif token == "--index-suites" then
      options.index_suites = true
      options.passthrough[#options.passthrough + 1] = token
    elseif token == "--lane" or token == "--mode" or token == "--lines" or token == "--max-workers" or token == "--timeout-factor" or token == "--test-command" then
      options.passthrough[#options.passthrough + 1] = token
      index = index + 1
      local value = args[index]
      if value == nil or value == "" then
        error(token .. " requires a value")
      end
      options.passthrough[#options.passthrough + 1] = value
    elseif options.target == nil and token:sub(1, 2) ~= "--" then
      options.target = token
    else
      options.passthrough[#options.passthrough + 1] = token
    end
    index = index + 1
  end

  return options
end

local M = {}

function M.ensure_binary(repo_root, env)
  env = env or {}
  local binary_path = _binary_path(repo_root)
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
  local result = common.run_command({ "go", "build", "-o", binary_path, "./cmd/mutate4lua-engine" }, {
    cwd = env.go_tool_dir or MUTATE4LUA_ROOT,
  })
  if result.ok ~= true then
    return nil, result.output
  end
  return binary_path, nil
end

function M.build_core_command(binary_path, options)
  local args = { binary_path }
  if options.index_suites then
    args[#args + 1] = "index-suites"
    args[#args + 1] = "--driver-script"
    args[#args + 1] = DEFAULT_DRIVER_PATH
    for _, value in ipairs(options.passthrough or {}) do
      if value ~= "--index-suites" then
        args[#args + 1] = value
      end
    end
    return args
  end
  if options.target == nil then
    error("mutate target must be a .lua file")
  end
  local subcommand = "mutate"
  for _, value in ipairs(options.passthrough or {}) do
    if value == "--scan" then
      subcommand = "scan"
      break
    elseif value == "--update-manifest" then
      subcommand = "update-manifest"
      break
    end
  end
  args[#args + 1] = subcommand
  args[#args + 1] = "--target"
  args[#args + 1] = options.target
  args[#args + 1] = "--driver-script"
  args[#args + 1] = DEFAULT_DRIVER_PATH
  for _, value in ipairs(options.passthrough or {}) do
    if value ~= "--scan" and value ~= "--update-manifest" then
      args[#args + 1] = value
    end
  end
  return args
end

function M.run(args, env)
  env = env or {}
  local stdout = env.stdout or io.stdout
  local stderr = env.stderr or io.stderr
  local command_name = env.command_name or "scripts/quality/mutate.lua"
  local workspace_root = env.workspace_root or REPO_ROOT

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
  local binary_path, build_err = M.ensure_binary(workspace_root, env)
  if binary_path == nil then
    stderr:write(tostring(build_err), "\n")
    return 1
  end
  local command = M.build_core_command(binary_path, options)
  local result = (env.run_command or common.run_command)(command, {
    cwd = workspace_root,
  })
  local output = tostring(result.output or "")
  if output ~= "" then
    if result.code == 0 or result.code == 3 then
      stdout:write(output)
    else
      stderr:write(output)
    end
  end
  return result.code or (result.ok and 0 or 1)
end

function M.main()
  return M.run(arg or {})
end

if ... == "quality.mutate" then
  return M
end

os.exit(M.main())
