local common = require("shared.lib.common")
local json_reader = require("shared.lib.json_reader")
local analyzer = require("crap4lua.analyzer")

local report_io = {}

local _CRAP_TMP_ENV = "MONOPOLY_CRAP_TMP"

local function _tmp_root()
  local value = os.getenv(_CRAP_TMP_ENV)
  if value ~= nil and value ~= "" then
    return common.normalize_path(value)
  end
  return common.join_path(common.system_tmp_dir(), "monopoly_crap")
end

function report_io.resolve_path(repo_root, path)
  local normalized = common.normalize_path(path)
  if normalized == "tmp" or normalized:match("^tmp/") then
    local suffix = normalized == "tmp" and "" or normalized:sub(5)
    return common.resolve_path(_tmp_root(), suffix)
  end
  return common.resolve_path(repo_root, normalized)
end

function report_io.coerce_line_hits(line_hits)
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

function report_io.load_collect(path)
  local content, read_err = common.read_file(path)
  if content == nil then
    return nil, "cannot read collect JSON: " .. tostring(read_err)
  end
  local ok_parse, collected = pcall(json_reader.decode, content)
  if not ok_parse or type(collected) ~= "table" then
    return nil, "collect JSON parse error: " .. tostring(collected)
  end
  if collected.coverage_result then
    collected.coverage_result.line_hits = report_io.coerce_line_hits(collected.coverage_result.line_hits)
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
