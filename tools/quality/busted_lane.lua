#!/usr/bin/env lua
local function _normalize_path(path)
  return tostring(path or ""):gsub("\\", "/")
end
local function _module_dir()
  local source = debug.getinfo(1, "S").source or "@tools/quality/busted_lane.lua"
  return _normalize_path(source):gsub("^@", ""):match("^(.*)/[^/]+$") or "tools/quality"
end

local bootstrap = dofile(_module_dir() .. "/../shared/bootstrap.lua")
bootstrap.install((arg and arg[0]) or debug.getinfo(1, "S").source)

local common = require("shared.lib.common")

local M = {}

local function _usage()
  return "usage: lua tools/quality/busted_lane.lua --profile <name> [--verbose]\n"
end

function M.parse_args(args)
  local options = { verbose = false }
  local i = 1
  while i <= #(args or {}) do
    local token = args[i]
    if token == "--profile" then
      options.profile = args[i + 1]
      i = i + 2
    elseif token == "--verbose" then
      options.verbose = true
      i = i + 1
    elseif token == "--help" or token == "-h" then
      options.help = true
      i = i + 1
    else
      return nil, "unknown option: " .. tostring(token)
    end
  end
  if not options.help and (not options.profile or options.profile == "") then
    return nil, "missing --profile"
  end
  return options
end

function M.compress_tap(output)
  local passed, failed = 0, 0
  local kept = {}
  for line in (tostring(output or "") .. "\n"):gmatch("([^\n]*)\n") do
    if line:match("^ok%s+%d") then
      passed = passed + 1
    elseif line:match("^not ok%s+%d") then
      failed = failed + 1
      kept[#kept + 1] = line
    elseif not line:match("^%d+%.%.%d+%s*$") then
      kept[#kept + 1] = line
    end
  end
  if failed == 0 then
    return string.format("%d passed\n", passed), passed, failed
  end
  kept[#kept + 1] = string.format("%d passed, %d failed", passed, failed)
  return table.concat(kept, "\n") .. "\n", passed, failed
end

function M.run(options)
  local busted_bin = os.getenv("BUSTED_BIN") or "busted"
  local cmd = common.shell_quote(busted_bin)
    .. " --output=TAP --run " .. common.shell_quote(options.profile)

  local result = common.run_command(cmd)
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
    io.stderr:write(_usage())
    io.stderr:write(tostring(err) .. "\n")
    return 2
  end
  if options.help then
    io.write(_usage())
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
