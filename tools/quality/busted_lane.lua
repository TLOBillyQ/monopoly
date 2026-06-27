#!/usr/bin/env lua
local function _normalize_path(path)
  return tostring(path or ""):gsub("\\", "/")
end
local function _module_dir()
  local source = debug.getinfo(1, "S").source or "@tools/quality/busted_lane.lua"
  return _normalize_path(source):gsub("^@", ""):match("^(.*)/[^/]+$") or "tools/quality"
end

local bootstrap = dofile(_module_dir() .. "/../shared/bootstrap.lua")
local bootstrap_env = bootstrap.install((arg and arg[0]) or debug.getinfo(1, "S").source)

local common = require("shared.lib.common")
local tap_summary = require("shared.tap_summary")
local lane_args = require("quality.busted_lane_args")
local lane_tools = require("quality.busted_lane_tools")

local M = {}

function M.parse_args(args)
  return lane_args.parse(args)
end

function M.compress_tap(output)
  return tap_summary.compress(output)
end

function M.run(options)
  options = options or {}
  local ok_tools, tool_err = lane_tools.ensure_for_profile(options.profile, bootstrap, bootstrap_env)
  if ok_tools == nil then
    return { stdout = tostring(tool_err) .. "\n", code = 1, passed = 0, failed = 1 }
  end

  local busted_bin = options.busted_bin or os.getenv("BUSTED_BIN") or "busted"
  local run_command = options.run_command or common.run_command

  local result = run_command({
    busted_bin,
    "--output=TAP",
    "--run",
    options.profile,
  })
  local raw = tostring(result.output or "")

  if options.verbose then
    return { stdout = raw, code = result.code or (result.ok and 0 or 1), passed = 0, failed = 0 }
  end

  local compressed, passed, failed = M.compress_tap(raw)
  local code = result.code or (result.ok and 0 or 1)
  if failed > 0 and code == 0 then
    code = 1
  end
  return { stdout = compressed, code = code, passed = passed, failed = failed }
end

function M.main(args)
  local options, err = M.parse_args(args)
  if not options then
    io.stderr:write(lane_args.usage())
    io.stderr:write(tostring(err) .. "\n")
    return 2
  end
  if options.help then
    io.write(lane_args.usage())
    return 0
  end
  local result = M.run(options)
  io.write(result.stdout)
  return result.code
end

if ... == "quality.busted_lane" then
  return M
end

os.exit(M.main(arg or {}))
