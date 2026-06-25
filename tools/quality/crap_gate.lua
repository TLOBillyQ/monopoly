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

local json_reader = require("shared.lib.json_reader")
local analyzer = require("crap4lua.analyzer")
local gate = require("quality.crap.gate")

local _CRAP_TMP_ENV = "MONOPOLY_CRAP_TMP"
local _DEFAULT_TMP_ROOT = common.join_path(common.system_tmp_dir(), "monopoly_crap")
local _CONFIG_PATH = common.join_path(REPO_ROOT, "tools/quality/crap/config.lua")
local _BASELINE_PATH = common.join_path(REPO_ROOT, "tools/quality/crap/crap_gate_baseline.lua")

local function _resolve_tmp_root()
  local val = os.getenv(_CRAP_TMP_ENV)
  if val and val ~= "" then return _normalize_path(val) end
  return _DEFAULT_TMP_ROOT
end

local function _resolve_path(path)
  local normalized = _normalize_path(path)
  if normalized == "tmp" or normalized:match("^tmp/") then
    local suffix = normalized == "tmp" and "" or normalized:sub(5)
    return common.resolve_path(_resolve_tmp_root(), suffix)
  end
  return common.resolve_path(REPO_ROOT, normalized)
end

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

local function _build_full_report(in_path)
  local content, read_err = common.read_file(in_path)
  if not content then
    io.stderr:write("cannot read collect JSON: " .. tostring(read_err) .. "\n")
    os.exit(1)
  end
  local ok_parse, collected = pcall(json_reader.decode, content)
  if not ok_parse or type(collected) ~= "table" then
    io.stderr:write("collect JSON parse error: " .. tostring(collected) .. "\n")
    os.exit(1)
  end
  -- JSON encodes line-number keys as strings; coerce back to integers so
  -- analyzer.build_report can look up file_hits[line_no].
  if collected.coverage_result and type(collected.coverage_result.line_hits) == "table" then
    local coerced = {}
    for path, hits in pairs(collected.coverage_result.line_hits) do
      if type(hits) == "table" then
        local inner = {}
        for k, v in pairs(hits) do
          local n = tonumber(k)
          if n then inner[n] = v end
        end
        coerced[path] = inner
      end
    end
    collected.coverage_result.line_hits = coerced
  end
  local report, build_err = analyzer.build_report({
    project_root = collected.project_root,
    project_name = collected.project_name,
    source_roots = collected.source_roots,
    coverage_result = collected.coverage_result,
    top = 0, -- all functions, never truncated
  })
  if not report then
    io.stderr:write("build_report failed: " .. tostring(build_err) .. "\n")
    os.exit(1)
  end
  return report
end

local opts = _parse_args(arg or {})
if opts.help then
  io.write(_usage())
  os.exit(0)
end

local base_threshold = _load_base_threshold()
local baseline_path = opts.baseline_path and _resolve_path(opts.baseline_path) or _BASELINE_PATH
local report = _build_full_report(_resolve_path(opts.in_path))
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
