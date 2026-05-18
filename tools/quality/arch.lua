local function _normalize_path(path)
  return tostring(path or ""):gsub("\\", "/")
end

local function _module_dir()
  local source = debug.getinfo(1, "S").source or "@tools/quality/arch.lua"
  local normalized = _normalize_path(source):gsub("^@", "")
  return normalized:match("^(.*)/[^/]+$") or "tools/quality"
end

local bootstrap = dofile(_module_dir() .. "/../shared/bootstrap.lua")
local bootstrap_env = bootstrap.install((arg and arg[0]) or debug.getinfo(1, "S").source)

local common = require("shared.lib.common")
local arch_view = require("arch_view")
local arch_filter = require("quality.arch.filter")

common.ensure_windows_utf8_console()

local REPO_ROOT = bootstrap_env.repo_root
local VENDOR_DIR = bootstrap_env.vendor_dir
local ARCH_VIEW_DIR = common.join_path(VENDOR_DIR, "arch_view")
local ARCH_CONFIG_PATH = common.join_path(REPO_ROOT, "tools/quality/arch/config.json")

local M = {}

local function _is_check_command(args)
  if type(args) ~= "table" then
    return false
  end
  return args[1] == "check"
end

local function _run_filtered_check(_args, env)
  local architecture, err = arch_view.analyze({
    project_root = env.cwd or REPO_ROOT,
    config_path = env.default_config_path or ARCH_CONFIG_PATH,
    engine = env.default_engine or "auto",
  })
  if architecture == nil then
    io.stderr:write("arch_view 检查失败 / arch_view check failed\n")
    io.stderr:write("  " .. tostring(err) .. "\n")
    return 1
  end

  arch_filter.apply(architecture)
  if architecture.check and architecture.check.ok == true then
    print("arch_view 检查通过 / arch_view check ok")
    return 0
  end

  io.stderr:write("arch_view 检查失败 / arch_view check failed\n")
  for _, violation in ipairs((architecture.check and architecture.check.violations) or {}) do
    if violation.kind == "forbidden_dependency" then
      io.stderr:write("  禁止依赖 / forbidden_dependency [" .. tostring(violation.rule) .. "] "
        .. tostring(violation.from) .. " -> " .. tostring(violation.to) .. "\n")
      io.stderr:write("    " .. tostring(violation.description) .. "\n")
    elseif violation.kind == "projection_cycle" then
      io.stderr:write("  投影循环 / projection_cycle " .. tostring(violation.view) .. "\n")
      io.stderr:write("    " .. tostring(violation.description) .. "\n")
    elseif violation.kind == "unclassified_module" then
      io.stderr:write("  未分类模块 / unclassified_module " .. tostring(violation.module_id) .. "\n")
      io.stderr:write("    " .. tostring(violation.description) .. "\n")
    else
      io.stderr:write("  " .. tostring(violation.kind) .. "\n")
      io.stderr:write("    " .. tostring(violation.description) .. "\n")
    end
  end
  return 1
end

function M.run(args, env)
  env = env or {}
  local effective_args = args or arg or {}
  if #effective_args == 0 then
    return _run_filtered_check({ "check" }, env)
  end
  if _is_check_command(effective_args) then
    return _run_filtered_check(effective_args, env)
  end
  return arch_view.run_cli(effective_args, {
    cwd = env.cwd or REPO_ROOT,
    asset_root = env.asset_root or _normalize_path(ARCH_VIEW_DIR .. "/viewer"),
    default_config_path = env.default_config_path or ARCH_CONFIG_PATH,
    default_engine = env.default_engine or "auto",
    open_path = env.open_path,
  })
end

function M.main()
  local code = M.run(arg or {})
  local is_numeric_code = pcall(function()
    return code + 0
  end)
  if is_numeric_code then
    os.exit(code)
  end
  return code
end

if ... == "quality.arch" then
  return M
end

M.main()
