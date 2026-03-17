local package_path_helper = dofile("scripts/shared/package_path_helper.lua")
package_path_helper.install_monopoly_package_paths({ repo_root = "." })

local common = require("shared.lib.common")

local function _module_dir()
  local source = debug.getinfo(1, "S").source or "@scripts/quality/scrap.lua"
  local normalized = common.normalize_path(source):gsub("^@", "")
  return normalized:match("^(.*)/[^/]+$") or "scripts"
end

local SCRIPT_DIR = common.resolve_path(common.current_dir(), _module_dir())
local REPO_ROOT = common.resolve_path(SCRIPT_DIR, "../..")
local DEFAULT_CONFIG_PATH = common.join_path(REPO_ROOT, "scripts/quality/scrap/config.lua")
local DEFAULT_INDEX_JSON = "tmp/scrap_index.json"
local DEFAULT_CLUSTER_JSON = "tmp/scrap_clusters.json"
local DEFAULT_VIEW_DIR = "tmp/scrap_view"

local M = {}

local function _default_tmp_root()
  local env_root = os.getenv("MONOPOLY_SCRAP_TMP")
  if env_root ~= nil and env_root ~= "" then
    return common.normalize_path(env_root)
  end
  return common.join_path(common.system_tmp_dir(), "monopoly_scrap")
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

local function _ensure_scrap_package_paths(repo_root)
  local patterns = {
    common.join_path(repo_root, "vendor/scrap4lua/lib/?.lua"),
    common.join_path(repo_root, "vendor/scrap4lua/lib/?/?.lua"),
  }
  for _, pattern in ipairs(patterns) do
    if not tostring(package.path):find(pattern, 1, true) then
      package.path = pattern .. ";" .. package.path
    end
  end
end

local function _help_text(command_name)
  return table.concat({
    "用法:",
    "  lua " .. tostring(command_name) .. " index [--out FILE] [--project-root DIR]",
    "  lua " .. tostring(command_name) .. " find --query TEXT [--limit N] [--out FILE] [--project-root DIR]",
    "  lua " .. tostring(command_name) .. " clusters [--limit N] [--out FILE] [--project-root DIR]",
    "  lua " .. tostring(command_name) .. " viewer [--in-json FILE] [--out-dir DIR] [--project-root DIR] [--open]",
    "  lua " .. tostring(command_name) .. " --help",
    "",
    "Usage:",
    "  lua " .. tostring(command_name) .. " index [--out FILE] [--project-root DIR]",
    "  lua " .. tostring(command_name) .. " find --query TEXT [--limit N] [--out FILE] [--project-root DIR]",
    "  lua " .. tostring(command_name) .. " clusters [--limit N] [--out FILE] [--project-root DIR]",
    "  lua " .. tostring(command_name) .. " viewer [--in-json FILE] [--out-dir DIR] [--project-root DIR] [--open]",
    "  lua " .. tostring(command_name) .. " --help",
    "",
    "Monopoly compatibility:",
    "  tmp/... resolves under monopoly_scrap temp root",
    "  default config is scripts/quality/scrap/config.lua",
  }, "\n") .. "\n"
end

local function _parse_args(args)
  local options = {
    command = nil,
    out = nil,
    out_dir = nil,
    in_json = nil,
    project_root = nil,
    query = nil,
    limit = 10,
    help = false,
    open = false,
  }

  local index = 1
  if args[1] ~= nil and args[1]:sub(1, 2) ~= "--" then
    options.command = args[1]
    index = 2
  end

  while index <= #args do
    local token = args[index]
    if token == "--help" or token == "-h" then
      options.help = true
    elseif token == "--out" then
      index = index + 1
      options.out = args[index]
    elseif token == "--out-dir" then
      index = index + 1
      options.out_dir = args[index]
    elseif token == "--in-json" then
      index = index + 1
      options.in_json = args[index]
    elseif token == "--project-root" then
      index = index + 1
      options.project_root = args[index]
    elseif token == "--query" then
      index = index + 1
      options.query = args[index]
    elseif token == "--limit" then
      index = index + 1
      options.limit = common.to_integer(args[index]) or 10
    elseif token == "--open" then
      options.open = true
    else
      error("unknown flag: " .. tostring(token))
    end
    index = index + 1
  end

  return options
end

function M.default_tmp_root()
  return _default_tmp_root()
end

function M.resolve_cli_path(base, path)
  return _resolve_cli_path(base, path)
end

function M.default_config_path()
  return DEFAULT_CONFIG_PATH
end

function M.run(args, env)
  local stdout = env and env.stdout or io.stdout
  local stderr = env and env.stderr or io.stderr
  local open_path = env and env.open_path or common.open_path
  local options = _parse_args(args or {})
  if options.command == nil then
    options.command = "viewer"
    options.open = true
  end

  if options.help then
    stdout:write(_help_text(arg and arg[0] or "scripts/quality/scrap.lua"))
    return 0
  end

  _ensure_scrap_package_paths(REPO_ROOT)
  local cli = require("scrap4lua.cli")

  local vendor_args = {
    options.command,
    "--config", DEFAULT_CONFIG_PATH,
  }

  if options.project_root ~= nil then
    vendor_args[#vendor_args + 1] = "--project-root"
    vendor_args[#vendor_args + 1] = _resolve_cli_path(REPO_ROOT, options.project_root)
  end

  if options.command == "index" then
    vendor_args[#vendor_args + 1] = "--out"
    vendor_args[#vendor_args + 1] = _resolve_cli_path(REPO_ROOT, options.out or DEFAULT_INDEX_JSON)
  elseif options.command == "find" then
    if options.query == nil or options.query == "" then
      stderr:write("find requires --query TEXT\n")
      return 1
    end
    vendor_args[#vendor_args + 1] = "--query"
    vendor_args[#vendor_args + 1] = options.query
    vendor_args[#vendor_args + 1] = "--limit"
    vendor_args[#vendor_args + 1] = tostring(options.limit)
    if options.out ~= nil then
      vendor_args[#vendor_args + 1] = "--out"
      vendor_args[#vendor_args + 1] = _resolve_cli_path(REPO_ROOT, options.out)
    end
  elseif options.command == "clusters" then
    vendor_args[#vendor_args + 1] = "--limit"
    vendor_args[#vendor_args + 1] = tostring(options.limit)
    if options.out ~= nil then
      vendor_args[#vendor_args + 1] = "--out"
      vendor_args[#vendor_args + 1] = _resolve_cli_path(REPO_ROOT, options.out)
    else
      vendor_args[#vendor_args + 1] = "--out"
      vendor_args[#vendor_args + 1] = _resolve_cli_path(REPO_ROOT, DEFAULT_CLUSTER_JSON)
    end
  elseif options.command == "viewer" then
    if options.in_json ~= nil then
      vendor_args[#vendor_args + 1] = "--in-json"
      vendor_args[#vendor_args + 1] = _resolve_cli_path(REPO_ROOT, options.in_json)
    end
    vendor_args[#vendor_args + 1] = "--out-dir"
    vendor_args[#vendor_args + 1] = _resolve_cli_path(REPO_ROOT, options.out_dir or DEFAULT_VIEW_DIR)
    if options.open then
      vendor_args[#vendor_args + 1] = "--open"
    end
  else
    stderr:write("unknown command: " .. tostring(options.command) .. "\n")
    return 1
  end

  return cli.run(vendor_args, {
    stdout = stdout,
    stderr = stderr,
    command_name = "scripts/quality/scrap.lua",
    open_path = open_path,
  })
end

function M.main()
  return M.run(arg or {})
end

if ... == "quality.scrap" then
  return M
end

os.exit(M.main())
