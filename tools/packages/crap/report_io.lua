local env_lib = require("foundation.env")
local fs_lib = require("foundation.fs")
local path_lib = require("foundation.path")
local json_reader = require("foundation.json_reader")
local analyzer = require("crap4lua.analyzer")

local report_io = {}

local _CRAP_TMP_ENV = "EGGY_CRAP_TMP"

local function _tmp_root()
  local value = os.getenv(_CRAP_TMP_ENV)
  if value ~= nil and value ~= "" then
    return path_lib.normalize_path(value)
  end
  return path_lib.join_path(env_lib.system_tmp_dir(), "eggy_crap")
end

function report_io.resolve_path(repo_root, path)
  local normalized = path_lib.normalize_path(path)
  if normalized == "tmp" or normalized:match("^tmp/") then
    local suffix = normalized == "tmp" and "" or normalized:sub(5)
    return path_lib.resolve_path(_tmp_root(), suffix)
  end
  return path_lib.resolve_path(repo_root, normalized)
end

-- 上游 crap4lua v0.1.0 的 coverage_result.files 是
--   { path -> { exec = { line -> true }, hit = { line -> true } } },
-- collect JSON 往返后行号键是字符串,analyzer 的 _coverage_in_range 做数字比较,
-- 这里统一 tonumber。
local function _coerce_line_set(lines)
  local coerced = {}
  for key, value in pairs(lines or {}) do
    local n = tonumber(key)
    if n then
      coerced[n] = value
    end
  end
  return coerced
end

local function _coerce_files(files)
  local coerced = {}
  for path, entry in pairs(files or {}) do
    if type(entry) == "table" then
      coerced[path] = {
        exec = _coerce_line_set(entry.exec),
        hit = _coerce_line_set(entry.hit),
      }
    end
  end
  return coerced
end

function report_io.load_collect(path)
  local content, read_err = fs_lib.read_file(path)
  if content == nil then
    return nil, "cannot read collect JSON: " .. tostring(read_err)
  end
  local ok_parse, collected = pcall(json_reader.decode, content)
  if not ok_parse or type(collected) ~= "table" then
    return nil, "collect JSON parse error: " .. tostring(collected)
  end
  if type(collected.coverage_result) == "table" then
    collected.coverage_result.files = _coerce_files(collected.coverage_result.files)
  end
  return collected
end

function report_io.build_report(path, opts)
  opts = opts or {}
  local collected, load_err = report_io.load_collect(path)
  if collected == nil then
    return nil, load_err
  end
  local report, build_err = analyzer.build_report({
    project_root = collected.project_root,
    project_name = collected.project_name,
    source_roots = collected.source_roots,
    coverage_result = collected.coverage_result,
    top = opts.top,
  })
  if report == nil then
    return nil, "build_report failed: " .. tostring(build_err)
  end
  return report
end

return report_io
