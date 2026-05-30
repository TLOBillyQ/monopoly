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
local crap4lua_lib = _normalize_path(bootstrap_env.vendor_dir) .. "/crap4lua/lib/?.lua"
if not package.path:find(crap4lua_lib, 1, true) then
  package.path = crap4lua_lib .. ";" .. package.path
end

local json_reader = require("shared.lib.json_reader")
local crap_common = require("crap4lua._internal.common")
local json_writer = require("crap4lua._internal.json_writer")
local analyzer = require("crap4lua.analyzer")

local _CRAP_TMP_ENV = "MONOPOLY_CRAP_TMP"
local _DEFAULT_TMP_ROOT = common.join_path(common.system_tmp_dir(), "monopoly_crap")

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

local in_path = _resolve_path(opts.in_path)
local out_path = _resolve_path(opts.out_path)

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

-- JSON encodes integer line-number keys as strings (e.g. "100"). analyzer.build_report
-- looks up file_hits[line_no] with an integer, so coerce inner keys back to integers.
local function _coerce_line_hits(line_hits)
  if type(line_hits) ~= "table" then return {} end
  local coerced = {}
  for path, hits in pairs(line_hits) do
    if type(hits) == "table" then
      local inner = {}
      for k, v in pairs(hits) do
        local n = tonumber(k)
        if n then inner[n] = v end
      end
      coerced[path] = inner
    end
  end
  return coerced
end

if collected.coverage_result then
  collected.coverage_result.line_hits = _coerce_line_hits(collected.coverage_result.line_hits)
end

local report, build_err = analyzer.build_report({
  project_root = collected.project_root,
  project_name = collected.project_name,
  source_roots = collected.source_roots,
  coverage_result = collected.coverage_result,
  top = opts.top or 20,
})
if not report then
  io.stderr:write("build_report failed: " .. tostring(build_err) .. "\n")
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
