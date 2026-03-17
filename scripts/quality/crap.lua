local package_path_helper = dofile("scripts/shared/package_path_helper.lua")
package_path_helper.install_monopoly_package_paths({ repo_root = "." })

local common = require("shared.lib.common")
local json_writer = require("shared.lib.json_writer")

common.ensure_windows_utf8_console()

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
    "  lua " .. tostring(command_name) .. " report [--lane NAME] [--out FILE] [--top N] [--strict-tests] [--project-root DIR]",
    "  lua " .. tostring(command_name) .. " collect [--lane NAME] --out FILE [--project-root DIR]",
    "  lua " .. tostring(command_name) .. " viewer [--in-json FILE] [--out-dir DIR] [--open]",
    "  lua " .. tostring(command_name),
    "",
    "Usage:",
    "  lua " .. tostring(command_name) .. " report [--lane NAME] [--out FILE] [--top N] [--strict-tests] [--project-root DIR]",
    "  lua " .. tostring(command_name) .. " collect [--lane NAME] --out FILE [--project-root DIR]",
    "  lua " .. tostring(command_name) .. " viewer [--in-json FILE] [--out-dir DIR] [--open]",
    "  lua " .. tostring(command_name),
    "",
    "Monopoly 兼容项 / Monopoly compatibility:",
    "  tmp/... 路径会映射到系统临时目录下的 monopoly_crap/ 子目录",
    "  report --out 会翻译成 vendor CLI 的 --response-json",
    "  report 先通过 Lua bridge 收集 coverage，再以 --request-json 调上游 CLI",
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

local function _ensure_bridge_package_paths(repo_root)
  package_path_helper.install_monopoly_package_paths({
    repo_root = repo_root,
    arch_view_root = common.join_path(repo_root, "vendor/arch_view"),
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

local function _collect_bridge_result(options, env)
  if type(env.collect_bridge_result) == "function" then
    return env.collect_bridge_result(options)
  end
  _ensure_bridge_package_paths(REPO_ROOT)
  local bridge = require("crap4lua.bridge")
  return bridge.collect({
    config = options.config,
    lanes = options.lanes,
    project_root = options.project_root,
  })
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

local function _run_viewer(options, env)
  local binary_path, build_err = M.ensure_binary(REPO_ROOT, env)
  if binary_path == nil then
    return { ok = false, code = 1, err = build_err }
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

local function _run_internal(args, env)
  env = env or {}
  local stdout = env.stdout or io.stdout
  local stderr = env.stderr or io.stderr
  local command_name = env.command_name or "scripts/quality/crap.lua"
  local argv = _copy_args(args or arg or {})

  if #argv == 0 then
    local report_options = _parse_report_args({ "--out", DEFAULT_REPORT_JSON })
    local report_result = _run_report(report_options, env)
    if report_result.ok ~= true then
      stderr:write(tostring(report_result.err or report_result.output or ""), "\n")
      return { ok = false, code = report_result.code or 1 }
    end
    local viewer_result = _run_viewer(_parse_viewer_args({ "--in-json", DEFAULT_REPORT_JSON, "--out-dir", DEFAULT_VIEW_DIR, "--open" }), env)
    if viewer_result.ok ~= true then
      stderr:write(tostring(viewer_result.err or viewer_result.output or ""), "\n")
      return { ok = false, code = viewer_result.code or 1 }
    end
    if viewer_result.output and viewer_result.output ~= "" then
      stdout:write(viewer_result.output)
    end
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
    if result.output and result.output ~= "" then
      stdout:write(result.output)
    end
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
    if result.output and result.output ~= "" then
      stdout:write(result.output)
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
