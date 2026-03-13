local function _normalize_path(path)
  return tostring(path or ""):gsub("\\", "/")
end

local function _script_dir()
  local raw_path = arg and arg[0] or "scripts/arch.lua"
  local normalized = _normalize_path(raw_path)
  return normalized:match("^(.*)/[^/]+$") or "scripts"
end

local SCRIPT_DIR = _script_dir()
local ARCH_LIB_DIR = _normalize_path(SCRIPT_DIR .. "/arch")
package.path = ARCH_LIB_DIR .. "/?.lua;"
  .. ARCH_LIB_DIR .. "/?/?.lua;"
  .. SCRIPT_DIR .. "/?.lua;"
  .. SCRIPT_DIR .. "/?/?.lua;"
  .. package.path

local cli = require("arch_view.cli")

local M = {}

function M.run(args, env)
  env = env or {}
  env.script_dir = ARCH_LIB_DIR
  env.default_project_root = _normalize_path(SCRIPT_DIR .. "/..")
  return cli.run(args or arg or {}, env)
end

function M.main()
  return M.run(arg or {})
end

if ... == "arch" then
  return M
end

M.main()
