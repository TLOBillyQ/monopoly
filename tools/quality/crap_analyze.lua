local function _normalize_path(path)
  return tostring(path or ""):gsub("\\", "/")
end
local function _module_dir()
  local source = debug.getinfo(1, "S").source or "@tools/quality/crap_analyze.lua"
  return _normalize_path(source):gsub("^@", ""):match("^(.*)/[^/]+$") or "tools/quality"
end

local bootstrap = dofile(_module_dir() .. "/../shared/bootstrap.lua")
local bootstrap_env = bootstrap.install((arg and arg[0]) or debug.getinfo(1, "S").source)
local common = require("shared.lib.common")
local REPO_ROOT = bootstrap_env.repo_root
assert(bootstrap.ensure_tool("crap4lua", bootstrap_env))

local crap_common = require("crap4lua._internal.common")
local json_writer = require("crap4lua._internal.json_writer")
local report_io = require("quality.crap.report_io")

local function _parse_args(args)
  local opts = {}
  local i = 1
  while i <= #args do
    local token = args[i]
    if token == "--in" then
      i = i + 1; opts.in_path = args[i]
    elseif token == "--out" then
      i = i + 1; opts.out_path = args[i]
    elseif token == "--top" then
      i = i + 1; opts.top = crap_common.to_integer(args[i])
    elseif token == "--help" or token == "-h" then
      opts.help = true
    else
      io.stderr:write("unknown flag: " .. tostring(token) .. "\n")
      os.exit(2)
    end
    i = i + 1
  end
  return opts
end

local function _usage()
  return "usage: lua tools/quality/crap_analyze.lua --in COLLECT_JSON --out REPORT_JSON [--top N]\n"
end

local opts = _parse_args(arg or {})
if opts.help then
  io.write(_usage())
  os.exit(0)
end
if not opts.in_path or not opts.out_path then
  io.stderr:write(_usage())
  os.exit(2)
end

local in_path = report_io.resolve_path(REPO_ROOT, opts.in_path)
local out_path = report_io.resolve_path(REPO_ROOT, opts.out_path)

local report, build_err = report_io.build_report(in_path, { top = opts.top or 20 })
if report == nil then
  io.stderr:write(tostring(build_err) .. "\n")
  os.exit(1)
end

local parent = common.parent_dir(out_path)
if parent and parent ~= "" then
  common.ensure_dir(parent)
end

local ok_w, write_err = common.write_file(out_path, json_writer.encode(report))
if not ok_w then
  io.stderr:write("write report failed: " .. tostring(write_err) .. "\n")
  os.exit(1)
end

io.write("crap report json: " .. _normalize_path(out_path) .. "\n")
