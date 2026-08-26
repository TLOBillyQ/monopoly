local _self = debug.getinfo(1, "S").source or "@tools/packages/lint/runner.lua"
local _sb = dofile(_self:gsub("\\", "/"):gsub("^@", ""):match("^(.*)/[^/]+$")
  .. "/../../foundation/script_bootstrap.lua")
local env = _sb.install("tools/packages/lint", _self)

local fs_lib = require("foundation.fs")
local path_lib = require("foundation.path")
local proc_lib = require("foundation.proc")
local text_lib = require("foundation.text")

local M = {}
local REPO_ROOT = env.repo_root
local CONFIG_PATH = path_lib.join_path(REPO_ROOT, "tools/packages/lint/.luacheckrc")
local DEFAULT_TARGETS = { "src", "test", "tools" }

local function _text(zh, en)
  return text_lib.bilingual(zh, en)
end

local function _help_text(command_name)
  local name = tostring(command_name or "tools/packages/lint/runner.lua")
  return table.concat({
    "用法:",
    "  lua " .. name .. " [path ...]",
    "  lua " .. name .. " --help",
    "",
    "Usage:",
    "  lua " .. name .. " [path ...]",
    "  lua " .. name .. " --help",
    "",
    "默认检查 src、test、tools。",
    "Default targets are src, test, and tools.",
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
      options.targets[#options.targets + 1] = path_lib.normalize_path(token)
    end
  end

  if #options.targets == 0 then
    for _, target in ipairs(DEFAULT_TARGETS) do
      options.targets[#options.targets + 1] = target
    end
  end

  return options
end

local function _validate_targets(targets)
  for _, target in ipairs(targets or {}) do
    local resolved = path_lib.resolve_path(REPO_ROOT, target)
    if not fs_lib.path_exists(resolved) then
      return nil, _text(
        "路径不存在: " .. tostring(target),
        "Path does not exist: " .. tostring(target)
      )
    end
  end
  return true
end

function M.run(args)
  local options = _parse_args(args or arg or {})
  if options.help then
    io.stdout:write(_help_text((arg and arg[0]) or "tools/packages/lint/runner.lua"))
    return 0
  end

  if not fs_lib.path_exists(CONFIG_PATH) then
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

  if not proc_lib.command_exists("luacheck") then
    io.stderr:write(_text(
      "未找到 luacheck，请先安装 luacheck 并确保它在 PATH 中。",
      "luacheck was not found. Install luacheck and make sure it is on PATH."
    ), "\n")
    return 1
  end

  local command = {
    "luacheck",
    "--config",
    "tools/packages/lint/.luacheckrc",
    "-j", "4",
  }
  for _, target in ipairs(options.targets) do
    command[#command + 1] = target
  end

  local result = proc_lib.run_command(command, { cwd = REPO_ROOT })
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

if ... == "packages.lint.runner" then
  return M
end

M.main()