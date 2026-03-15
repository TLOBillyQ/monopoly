local package_path_helper = dofile("scripts/shared/package_path_helper.lua")
package_path_helper.install_monopoly_package_paths({ repo_root = "." })

local common = require("shared.lib.common")

local function _module_dir()
  local source = debug.getinfo(1, "S").source or "@scripts/quality/crap.lua"
  local normalized = common.normalize_path(source):gsub("^@", "")
  return normalized:match("^(.*)/[^/]+$") or "scripts"
end

local SCRIPT_DIR = common.resolve_path(common.current_dir(), _module_dir())
local REPO_ROOT = common.resolve_path(SCRIPT_DIR, "../..")
local CRAP4LUA_ROOT = common.join_path(REPO_ROOT, "vendor/crap4lua")
local DEFAULT_CONFIG_PATH = common.join_path(REPO_ROOT, "scripts/quality/crap/config.lua")
local DEFAULT_REPORT_JSON = "tmp/crap_report.json"
local DEFAULT_VIEW_DIR = "tmp/crap_view"

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
    "  lua " .. tostring(command_name) .. " report [--lane NAME] [--mode MODE] [--out FILE] [--top N] [--strict-tests] [--project-root DIR]",
    "  lua " .. tostring(command_name) .. " collect [--lane NAME] [--mode MODE] --out FILE [--project-root DIR]",
    "  lua " .. tostring(command_name) .. " viewer [--in-json FILE] [--out-dir DIR] [--open]",
    "  lua " .. tostring(command_name),
    "",
    "Usage:",
    "  lua " .. tostring(command_name) .. " report [--lane NAME] [--mode MODE] [--out FILE] [--top N] [--strict-tests] [--project-root DIR]",
    "  lua " .. tostring(command_name) .. " collect [--lane NAME] [--mode MODE] --out FILE [--project-root DIR]",
    "  lua " .. tostring(command_name) .. " viewer [--in-json FILE] [--out-dir DIR] [--open]",
    "  lua " .. tostring(command_name),
    "",
    "Monopoly 兼容项 / Monopoly compatibility:",
    "  tmp/... 路径会映射到系统临时目录下的 monopoly_crap/ 子目录",
    "  report --out 会翻译成 vendor CLI 的 --response-json",
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

local function _has_flag(args, flag)
  for _, value in ipairs(args or {}) do
    if value == flag then
      return true
    end
  end
  return false
end

local function _rewrite_path_token(base, flag, value, command)
  if flag == "--out" and command == "report" then
    return "--response-json", _resolve_cli_path(base, value)
  end
  if flag == "--config"
      or flag == "--out"
      or flag == "--response-json"
      or flag == "--request-json"
      or flag == "--project-root"
      or flag == "--in-json"
      or flag == "--out-dir" then
    return flag, _resolve_cli_path(base, value)
  end
  return flag, value
end

local function _rewrite_cli_args(base, command, args)
  local rewritten = { command }
  local index = 1
  while index <= #args do
    local token = args[index]
    if token == "--open" or token == "--strict-tests" then
      rewritten[#rewritten + 1] = token
      index = index + 1
    elseif args[index + 1] ~= nil then
      local next_flag, next_value = _rewrite_path_token(base, token, args[index + 1], command)
      rewritten[#rewritten + 1] = next_flag
      rewritten[#rewritten + 1] = next_value
      index = index + 2
    else
      rewritten[#rewritten + 1] = token
      index = index + 1
    end
  end
  return rewritten
end

local function _ensure_default_config(args)
  if _has_flag(args, "--config") then
    return args
  end
  local rewritten = { args[1], "--config", DEFAULT_CONFIG_PATH }
  for index = 2, #args do
    rewritten[#rewritten + 1] = args[index]
  end
  return rewritten
end

local function _with_default_report_json(args)
  if _has_flag(args, "--response-json") or _has_flag(args, "--out") then
    return args
  end
  local rewritten = _copy_args(args)
  rewritten[#rewritten + 1] = "--response-json"
  rewritten[#rewritten + 1] = DEFAULT_REPORT_JSON
  return rewritten
end

local function _viewer_report_args_from_viewer_args(args)
  local report_args = { "report", "--config", DEFAULT_CONFIG_PATH, "--response-json", DEFAULT_REPORT_JSON }
  local index = 1
  while index <= #args do
    local token = args[index]
    if token == "--lane" or token == "--mode" or token == "--project-root" or token == "--top" then
      report_args[#report_args + 1] = token
      report_args[#report_args + 1] = args[index + 1]
      index = index + 2
    elseif token == "--strict-tests" then
      report_args[#report_args + 1] = token
      index = index + 1
    elseif token == "--out-dir" or token == "--open" then
      if token == "--out-dir" then
        index = index + 2
      else
        index = index + 1
      end
    else
      if args[index + 1] ~= nil and token:sub(1, 2) == "--" and args[index + 1]:sub(1, 2) ~= "--" then
        index = index + 2
      else
        index = index + 1
      end
    end
  end
  return report_args
end

local function _viewer_args(args)
  local viewer_args = { "viewer" }
  local has_in_json = false
  local has_out_dir = false
  local has_open = false
  local index = 1
  while index <= #args do
    local token = args[index]
    if token == "--in-json" then
      has_in_json = true
      viewer_args[#viewer_args + 1] = token
      viewer_args[#viewer_args + 1] = args[index + 1]
      index = index + 2
    elseif token == "--out-dir" then
      has_out_dir = true
      viewer_args[#viewer_args + 1] = token
      viewer_args[#viewer_args + 1] = args[index + 1]
      index = index + 2
    elseif token == "--open" then
      has_open = true
      viewer_args[#viewer_args + 1] = token
      index = index + 1
    else
      if args[index + 1] ~= nil and token:sub(1, 2) == "--" and args[index + 1]:sub(1, 2) ~= "--" then
        index = index + 2
      else
        index = index + 1
      end
    end
  end
  if not has_in_json then
    viewer_args[#viewer_args + 1] = "--in-json"
    viewer_args[#viewer_args + 1] = DEFAULT_REPORT_JSON
  end
  if not has_out_dir then
    viewer_args[#viewer_args + 1] = "--out-dir"
    viewer_args[#viewer_args + 1] = DEFAULT_VIEW_DIR
  end
  if not has_open then
    viewer_args[#viewer_args + 1] = "--open"
  end
  return viewer_args
end

local function _build_commands(args)
  local argv = _copy_args(args)
  if #argv == 0 then
    return {
      _rewrite_cli_args(REPO_ROOT, "report", { "--config", DEFAULT_CONFIG_PATH, "--response-json", DEFAULT_REPORT_JSON }),
      _rewrite_cli_args(REPO_ROOT, "viewer", { "--in-json", DEFAULT_REPORT_JSON, "--out-dir", DEFAULT_VIEW_DIR, "--open" }),
    }
  end

  local command = argv[1]
  if command == "report" then
    local prepared = _with_default_report_json(_ensure_default_config(argv))
    return { _rewrite_cli_args(REPO_ROOT, "report", { select(2, table.unpack(prepared)) }) }
  end

  if command == "collect" then
    local prepared = _ensure_default_config(argv)
    return { _rewrite_cli_args(REPO_ROOT, "collect", { select(2, table.unpack(prepared)) }) }
  end

  if command == "viewer" then
    if _has_flag(argv, "--in-json") then
      return { _rewrite_cli_args(REPO_ROOT, "viewer", { select(2, table.unpack(_viewer_args({ select(2, table.unpack(argv)) }))) }) }
    end
    local viewer_tail = { select(2, table.unpack(argv)) }
    return {
      _rewrite_cli_args(REPO_ROOT, "report", { select(2, table.unpack(_viewer_report_args_from_viewer_args(viewer_tail))) }),
      _rewrite_cli_args(REPO_ROOT, "viewer", { select(2, table.unpack(_viewer_args(viewer_tail))) }),
    }
  end

  return nil, common.bilingual(
    "未知命令: " .. tostring(command),
    "Unknown command: " .. tostring(command)
  )
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
  if common.command_exists("go") ~= true then
    return nil, common.bilingual("未找到 go 命令", "go command not found")
  end
  local ok, err = common.ensure_parent_dir(binary_path)
  if not ok then
    return nil, err
  end
  local result = common.run_command({ "go", "build", "-o", binary_path, "./cmd/crap4lua" }, {
    cwd = common.join_path(workspace_root, "vendor/crap4lua"),
  })
  if result.ok ~= true then
    return nil, result.output
  end
  return binary_path, nil
end

local function _run_internal(args, env)
  env = env or {}
  local stdout = env.stdout or io.stdout
  local stderr = env.stderr or io.stderr
  local command_name = env.command_name or "scripts/quality/crap.lua"
  local workspace_root = env.workspace_root or REPO_ROOT
  local argv = _copy_args(args or arg or {})

  if #argv == 0 then
    local binary_path, build_err = M.ensure_binary(workspace_root, env)
    if binary_path == nil then
      stderr:write(tostring(build_err), "\n")
      return { ok = false, code = 1 }
    end
    local commands = _build_commands({})
    for _, command in ipairs(commands) do
      table.insert(command, 1, binary_path)
      local result = (env.run_command or common.run_command)(command, { cwd = workspace_root })
      local output = tostring(result.output or "")
      if output ~= "" then
        if result.ok == true then
          stdout:write(output)
        else
          stderr:write(output)
        end
      end
      if result.ok ~= true then
        return { ok = false, code = result.code or 1 }
      end
    end
    return { ok = true, code = 0 }
  end

  local first = argv[1]
  if first == "help" or first == "--help" or first == "-h" then
    stdout:write(_help_text(command_name))
    return { ok = true, code = 0 }
  end

  local commands, build_err = _build_commands(argv)
  if commands == nil then
    stderr:write(tostring(build_err), "\n")
    stderr:write(_help_text(command_name))
    return { ok = false, code = 1 }
  end

  local binary_path, ensure_err = M.ensure_binary(workspace_root, env)
  if binary_path == nil then
    stderr:write(tostring(ensure_err), "\n")
    return { ok = false, code = 1 }
  end

  for _, command in ipairs(commands) do
    table.insert(command, 1, binary_path)
    local result = (env.run_command or common.run_command)(command, { cwd = workspace_root })
    local output = tostring(result.output or "")
    if output ~= "" then
      if result.ok == true then
        stdout:write(output)
      else
        stderr:write(output)
      end
    end
    if result.ok ~= true then
      return { ok = false, code = result.code or 1 }
    end
  end

  return { ok = true, code = 0 }
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
