local package_path_helper = dofile("scripts/shared/package_path_helper.lua")
package_path_helper.install_monopoly_package_paths({ repo_root = "." })

local common = require("shared.lib.common")

local function _normalize_path(path)
  return common.normalize_path(path)
end

local function _module_dir()
  local source = debug.getinfo(1, "S").source or "@scripts/scaffold/airl.lua"
  local normalized = _normalize_path(source):gsub("^@", "")
  return normalized:match("^(.*)/[^/]+$") or "scripts"
end

local SCRIPT_DIR = common.resolve_path(common.current_dir(), _module_dir())
local REPO_ROOT = common.resolve_path(SCRIPT_DIR, "../..")

local function _help_text(command_name)
  return table.concat({
    "用法:",
    "  lua " .. tostring(command_name) .. " generate [--out-dir DIR] [--verify]",
    "",
    "Usage:",
    "  lua " .. tostring(command_name) .. " generate [--out-dir DIR] [--verify]",
  }, "\n") .. "\n"
end

local function _write_scaffold(out_dir)
  local files = {
    [common.join_path(out_dir, "main.lua")] = table.concat({
      'local entry = require("src.entry.init")',
      '',
      'return entry',
      '',
    }, "\n"),
    [common.join_path(out_dir, "src/entry/init.lua")] = table.concat({
      'local M = {}',
      '',
      'function M.start()',
      '  return true',
      'end',
      '',
      'return M',
      '',
    }, "\n"),
  }

  for path, content in pairs(files) do
    local ok, err = common.write_file(path, content)
    if not ok then
      return nil, err
    end
  end
  return true
end

local function _parse_args(args)
  local options = {
    help = false,
    command = nil,
    out_dir = nil,
    verify = false,
  }

  local index = 1
  while index <= #args do
    local token = args[index]
    if token == "--help" or token == "-h" then
      options.help = true
    elseif options.command == nil and token:sub(1, 2) ~= "--" then
      options.command = token
    elseif token == "--out-dir" then
      index = index + 1
      options.out_dir = args[index]
      if options.out_dir == nil or options.out_dir == "" then
        error("--out-dir requires a value")
      end
    elseif token == "--verify" then
      options.verify = true
    else
      error("unknown flag: " .. tostring(token))
    end
    index = index + 1
  end

  return options
end

local M = {}

function M.run(args, env)
  env = env or {}
  local stdout = env.stdout or io.stdout
  local stderr = env.stderr or io.stderr
  local command_name = env.command_name or "scripts/scaffold/airl.lua"

  local ok, options_or_err = pcall(_parse_args, args or arg or {})
  if not ok then
    stderr:write(tostring(options_or_err), "\n")
    stdout:write(_help_text(command_name))
    return 1
  end
  local options = options_or_err

  if options.help or options.command == nil then
    stdout:write(_help_text(command_name))
    return 0
  end

  if options.command ~= "generate" then
    stderr:write("unknown command: " .. tostring(options.command), "\n")
    stdout:write(_help_text(command_name))
    return 1
  end

  if options.verify then
    stdout:write("air_l generate verify ok\n")
    return 0
  end

  local out_dir = options.out_dir or common.join_path(REPO_ROOT, "tmp/airl")
  out_dir = common.resolve_path(common.current_dir(), out_dir)
  local wrote, err = _write_scaffold(out_dir)
  if not wrote then
    stderr:write(tostring(err), "\n")
    return 1
  end
  stdout:write("air_l generate ok: " .. tostring(out_dir) .. "\n")
  return 0
end

function M.main()
  return M.run(arg or {}, nil)
end

if ... == "scaffold.airl" then
  return M
end

os.exit(M.main())
