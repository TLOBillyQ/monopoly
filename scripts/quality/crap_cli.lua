local function _normalize_path(path)
  return tostring(path or ""):gsub("\\", "/")
end

local function _script_dir()
  local raw_path = arg and arg[0] or "scripts/quality/crap_cli.lua"
  local normalized = _normalize_path(raw_path)
  return normalized:match("^(.*)/[^/]+$") or "scripts/quality"
end

local SCRIPT_DIR = _script_dir()
local ARCH_DIR = _normalize_path(SCRIPT_DIR .. "/../architecture")
package.path = SCRIPT_DIR .. "/?.lua;"
  .. SCRIPT_DIR .. "/?/?.lua;"
  .. ARCH_DIR .. "/?.lua;"
  .. ARCH_DIR .. "/?/?.lua;"
  .. package.path

local cli = require("crap.cli")

local M = {}

function M.run(args, env)
  env = env or {}
  env.script_dir = SCRIPT_DIR
  env.arch_dir = ARCH_DIR
  env.default_project_root = _normalize_path(SCRIPT_DIR .. "/../..")
  return cli.run(args or arg or {}, env)
end

function M.main()
  return M.run(arg or {})
end

if ... == "crap_cli" then
  return M
end

M.main()
