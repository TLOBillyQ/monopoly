local function _normalize_path(path)
  return tostring(path or ""):gsub("\\", "/")
end
local function _module_dir()
  local source = debug.getinfo(1, "S").source or "@tools/packages/coverage/crap_gate.lua"
  return _normalize_path(source):gsub("^@", ""):match("^(.*)/[^/]+$") or "tools/packages/coverage"
end

local bootstrap = dofile(_module_dir() .. "/../../foundation/bootstrap.lua")
local bootstrap_env = bootstrap.install((arg and arg[0]) or debug.getinfo(1, "S").source)
local path_lib = require("foundation.path")
local REPO_ROOT = bootstrap_env.repo_root
assert(bootstrap.ensure_tool("crap4lua", bootstrap_env))

local report_io = require("packages.crap.report_io")
local gate = require("packages.crap.gate")

local _CONFIG_PATH = path_lib.join_path(REPO_ROOT, "tools/packages/crap/config.lua")
local _DEFAULT_THRESHOLD = 5.0

local function _parse_args(args)
  local opts = { in_path = "tmp/crap_collect.json" }
  local i = 1
  while i <= #args do
    local token = args[i]
    if token == "--in" then
      i = i + 1; opts.in_path = args[i]
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
    "usage: lua tools/packages/coverage/crap_gate.lua [--in COLLECT_JSON]",
    "",
    "CRAP gate. Fails when any function scores above the threshold from",
    "tools/packages/crap/config.lua. The bar is flat: no per-file budget and no",
    "complexity-aware exemption. Since CRAP equals complexity at full coverage,",
    "a function above the threshold is fixed by raising coverage, by splitting",
    "it, or by both.",
    "",
  }, "\n")
end

local function _load_threshold()
  local ok, config = pcall(dofile, _CONFIG_PATH)
  if ok and type(config) == "table" and type(config.crap_threshold) == "number" then
    return config.crap_threshold
  end
  return _DEFAULT_THRESHOLD
end

local opts = _parse_args(arg or {})
if opts.help then
  io.write(_usage())
  os.exit(0)
end

local threshold = _load_threshold()
local report, report_err = report_io.build_report(report_io.resolve_path(REPO_ROOT, opts.in_path), { top = 0 })
if report == nil then
  io.stderr:write(tostring(report_err) .. "\n")
  os.exit(1)
end
local by_file = gate.violations_by_file(report.functions, threshold)
local total = gate.total_violations(by_file)
local offenders = gate.evaluate(by_file)

if #offenders == 0 then
  io.write(string.format("[crap-gate] PASS  no function scores above crap %.1f\n", threshold))
  os.exit(0)
end

io.write(string.format(
  "[crap-gate] FAIL  %d violation(s) above crap %.1f in %d file(s)\n",
  total, threshold, #offenders))
for _, offender in ipairs(offenders) do
  io.write(string.format("  %s: %d\n", offender.source_path, offender.count))
  for _, fn in ipairs(offender.functions) do
    -- N/A(crap 为 null 或 json_writer.null 哨兵)显示为字符串,不能进 %.1f。
    local crap_text = type(fn.crap) == "number" and string.format("%.1f", fn.crap) or "N/A"
    io.write(string.format("    crap=%s cx=%d cov=%s  %s (line %d)\n",
      crap_text, fn.complexity, tostring(fn.coverage), tostring(fn.name), fn.start_line or 0))
  end
end
io.write("Reduce complexity or raise coverage.\n")
-- 退出码语义跟上游 `summary --gate` 对齐：gate 违例退出 2。
os.exit(2)
