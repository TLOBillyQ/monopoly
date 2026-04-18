local function _normalize_path(path)
  return tostring(path or ""):gsub("\\", "/")
end

local function _module_dir()
  local source = debug.getinfo(1, "S").source or "@tools/quality/lint.lua"
  local normalized = _normalize_path(source):gsub("^@", "")
  return normalized:match("^(.*)/[^/]+$") or "tools/quality"
end

local bootstrap = dofile(_module_dir() .. "/../shared/bootstrap.lua")
local env = bootstrap.install((arg and arg[0]) or debug.getinfo(1, "S").source)

local common = require("shared.lib.common")

common.ensure_windows_utf8_console()

local M = {}
local REPO_ROOT = env.repo_root
local CONFIG_PATH = common.join_path(REPO_ROOT, ".luacheckrc")
local DEFAULT_TARGETS = { "src", "tests", "tools" }

local function _text(zh, en)
  return common.bilingual(zh, en)
end

local function _help_text(command_name)
  local name = tostring(command_name or "tools/quality/lint.lua")
  return table.concat({
    "用法:",
    "  lua " .. name .. " [path ...]",
    "  lua " .. name .. " --help",
    "",
    "Usage:",
    "  lua " .. name .. " [path ...]",
    "  lua " .. name .. " --help",
    "",
    "默认检查 src、tests、tools。",
    "Default targets are src, tests, and tools.",
    "需要系统已安装 luacheck。",
    "Requires luacheck to be installed and available on PATH.",
  }, "\n") .. "\n"
end

local function _parse_args(args)
  local options = {
    help = false,
    targets = {},
  }

  for _, token in ipairs(args or {}) do
    if token == "--help" or token == "-h" then
      options.help = true
    else
      options.targets[#options.targets + 1] = common.normalize_path(token)
    end
  end

  if #options.targets == 0 then
    for _, target in ipairs(DEFAULT_TARGETS) do
      options.targets[#options.targets + 1] = target
    end
  end

  return options
end

local function _cli_args(raw_args)
  local args = {}
  for index = 1, #(raw_args or {}) do
    args[#args + 1] = raw_args[index]
  end
  return args
end

local function _validate_targets(targets)
  for _, target in ipairs(targets or {}) do
    local resolved = common.resolve_path(REPO_ROOT, target)
    if not common.path_exists(resolved) then
      return nil, _text(
        "路径不存在: " .. tostring(target),
        "Path does not exist: " .. tostring(target)
      )
    end
  end
  return true
end

function M.run(args)
  local options = _parse_args(_cli_args(args or arg or {}))
  if options.help then
    io.stdout:write(_help_text((arg and arg[0]) or "tools/quality/lint.lua"))
    return 0
  end

  if not common.path_exists(CONFIG_PATH) then
    io.stderr:write(_text(
      "缺少 luacheck 配置: " .. CONFIG_PATH,
      "Missing luacheck config: " .. CONFIG_PATH
    ), "\n")
    return 1
  end

  local ok, err = _validate_targets(options.targets)
  if not ok then
    io.stderr:write(tostring(err), "\n")
    return 1
  end

  if not common.command_exists("luacheck") then
    io.stderr:write(_text(
      "未找到 luacheck，请先安装 luacheck 并确保它在 PATH 中。",
      "luacheck was not found. Install luacheck and make sure it is on PATH."
    ), "\n")
    return 1
  end

  local command = {
    "luacheck",
    "--config",
    common.normalize_path(CONFIG_PATH),
  }
  for _, target in ipairs(options.targets) do
    command[#command + 1] = target
  end

  local result = common.run_command(command, { cwd = REPO_ROOT })
  if result.output and result.output ~= "" then
    io.stdout:write(result.output)
    if result.output:sub(-1) ~= "\n" then
      io.stdout:write("\n")
    end
  end

  if result.ok then
    return 0
  end
  return result.code or 1
end

function M.main()
  local code = M.run(arg or {})
  os.exit(code)
end

if ... == "quality.lint" then
  return M
end

M.main()
