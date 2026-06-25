local function _normalize_path(path)
  return tostring(path or ""):gsub("\\", "/")
end
local function _module_dir()
  local source = debug.getinfo(1, "S").source or "@tools/quality/crap_gate.lua"
  return _normalize_path(source):gsub("^@", ""):match("^(.*)/[^/]+$") or "tools/quality"
end

local bootstrap = dofile(_module_dir() .. "/../shared/bootstrap.lua")
local bootstrap_env = bootstrap.install((arg and arg[0]) or debug.getinfo(1, "S").source)
local common = require("shared.lib.common")
local REPO_ROOT = bootstrap_env.repo_root
assert(bootstrap.ensure_tool("crap4lua", bootstrap_env))

local report_io = require("quality.crap.report_io")
local gate = require("quality.crap.gate")

local _CONFIG_PATH = common.join_path(REPO_ROOT, "tools/quality/crap/config.lua")
local _BASELINE_PATH = common.join_path(REPO_ROOT, "tools/quality/crap/crap_gate_baseline.lua")

local function _parse_args(args)
  local opts = { in_path = "tmp/crap_collect.json" }
  local i = 1
  while i <= #args do
    local token = args[i]
    if token == "--in" then
      i = i + 1; opts.in_path = args[i]
    elseif token == "--baseline" then
      i = i + 1; opts.baseline_path = args[i]
    elseif token == "--update-baseline" then
      opts.update = true
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
  return table.concat({
    "usage: lua tools/quality/crap_gate.lua [--in COLLECT_JSON] [--baseline FILE]",
    "                                       [--update-baseline]",
    "",
    "Complexity-aware CRAP ratchet. Fails when a source file gains CRAP",
    "violations beyond its committed baseline count. A violation is a function",
    "whose crap >= max(crap_threshold, complexity + 1).",
    "",
    "  --update-baseline   freeze the current violation counts as the baseline",
    "",
  }, "\n")
end

local function _load_base_threshold()
  local ok, config = pcall(dofile, _CONFIG_PATH)
  if ok and type(config) == "table" and type(config.crap_threshold) == "number" then
    return config.crap_threshold
  end
  return 7
end

local function _load_baseline(path)
  local ok, data = pcall(dofile, path)
  if ok and type(data) == "table" and type(data.files) == "table" then
    return data
  end
  return { files = {} }
end

local opts = _parse_args(arg or {})
if opts.help then
  io.write(_usage())
  os.exit(0)
end

local base_threshold = _load_base_threshold()
local baseline_path = opts.baseline_path and report_io.resolve_path(REPO_ROOT, opts.baseline_path) or _BASELINE_PATH
local report, report_err = report_io.build_report(report_io.resolve_path(REPO_ROOT, opts.in_path), { top = 0 })
if report == nil then
  io.stderr:write(tostring(report_err) .. "\n")
  os.exit(1)
end
local by_file = gate.violations_by_file(report.functions, base_threshold)
local total = gate.total_violations(by_file)

if opts.update then
  local ok, err = common.write_file(baseline_path, gate.render_baseline(base_threshold, by_file))
  if not ok then
    io.stderr:write("write baseline failed: " .. tostring(err) .. "\n")
    os.exit(1)
  end
  local file_count = 0
  for _ in pairs(by_file) do file_count = file_count + 1 end
  io.write(string.format("crap gate baseline updated: %s (%d files, %d violations)\n",
    _normalize_path(baseline_path), file_count, total))
  os.exit(0)
end

local regressions = gate.evaluate(by_file, _load_baseline(baseline_path))

if #regressions == 0 then
  io.write(string.format(
    "[crap-gate] PASS  violations=%d within baseline (ceiling=max(%d, cx+1))\n",
    total, base_threshold))
  os.exit(0)
end

io.write(string.format(
  "[crap-gate] FAIL  %d file(s) exceed baseline (ceiling=max(%d, cx+1))\n",
  #regressions, base_threshold))
for _, r in ipairs(regressions) do
  io.write(string.format("  %s: %d > baseline %d\n", r.source_path, r.count, r.allowed))
  for _, fn in ipairs(r.functions) do
    io.write(string.format("    crap=%.1f cx=%d cov=%s  %s (line %d)\n",
      fn.crap, fn.complexity, tostring(fn.coverage), tostring(fn.name), fn.start_line or 0))
  end
end
io.write("Reduce complexity or raise coverage; if intentional, rerun with --update-baseline.\n")
os.exit(1)
