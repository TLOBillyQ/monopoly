-- spec-lane 的计数真源与测量证据(#130)。
--
-- 背景:lane 进程把 stdout/stderr 合到同一个文件句柄,stdout 全缓冲而 stderr
-- 无缓冲,stderr 的写入会落在 stdout 两次冲刷之间,把一条 TAP 行从中间切开
-- (实测 `ok 77` 变成 `k 77`)。因此「数 ok 行」会漏计,而 runner 进程内累计的
-- `# COUNTS:` 不受串流影响,是计数的权威一侧。本模块负责:
--   1) 从原始输出解析/汇总 COUNTS;
--   2) 把各 lane 原始输出与汇总值一起落证据目录;
--   3) 仅凭证据目录重算汇总值并核对(recount)。
local fs_lib = require("foundation.fs")
local tap_summary = require("foundation.tap_summary")

local M = {}

local _COUNTS_PATTERN = "files=(%d+)%s+cases=(%d+)%s+passed=(%d+)%s+failed=(%d+)%s+errors=(%d+)"

-- 不匹配行首:上一条没换行的输出可能粘在 COUNTS 前面,计数本身仍完整。
function M.parse_counts(raw)
  local text = tostring(raw or ""):match("# COUNTS: ([^\r\n]+)")
  if text == nil then return nil end
  local files, cases, passed, failed, errors = text:match(_COUNTS_PATTERN)
  if files == nil then return nil end
  return {
    files = tonumber(files),
    cases = tonumber(cases),
    passed = tonumber(passed),
    failed = tonumber(failed),
    errors = tonumber(errors),
  }
end

function M.format_counts(counts)
  return string.format("# COUNTS: files=%d cases=%d passed=%d failed=%d errors=%d",
    counts.files, counts.cases, counts.passed, counts.failed, counts.errors)
end

-- TAP 行计数只是交叉核对口径,与摘要共用 foundation.tap_summary 的唯一实现
-- (含无编号 not ok),不在本模块另存一套正则。
function M.tally_tap(raw)
  return tap_summary.tally(raw)
end

-- entries = { { label=..., raw=... }, ... }。任一条 lane 缺 COUNTS 就不给总账,
-- 由调用方退回 TAP 口径并点名缺失 lane,绝不拿不完整的和冒充总数。
function M.aggregate(entries)
  local counts, missing = nil, {}
  local tally = { passed = 0, failed = 0 }
  for _, entry in ipairs(entries or {}) do
    local own = M.tally_tap(entry.raw)
    tally.passed = tally.passed + own.passed
    tally.failed = tally.failed + own.failed
    local parsed = M.parse_counts(entry.raw)
    if parsed == nil then
      missing[#missing + 1] = entry.label or "?"
    else
      counts = counts or { files = 0, cases = 0, passed = 0, failed = 0, errors = 0 }
      for _, key in ipairs({ "files", "cases", "passed", "failed", "errors" }) do
        counts[key] = counts[key] + parsed[key]
      end
    end
  end
  if #missing > 0 then counts = nil end
  return { counts = counts, tally = tally, missing = missing }
end

function M.mismatch_line(counts, tally)
  if counts == nil then return nil end
  local failed = counts.failed + counts.errors
  if tally.passed == counts.passed and tally.failed == failed then return nil end
  return string.format(
    "[spec-lane] COUNT MISMATCH: tap passed=%d failed=%d; counts passed=%d failed=%d errors=%d"
      .. "(以 COUNTS 为准;TAP 行可能被 stdout/stderr 合流串流切开,#130)",
    tally.passed, tally.failed, counts.passed, counts.failed, counts.errors)
end

local function _safe(label)
  return (tostring(label or "lane"):gsub("[^%w_.%-]", "_"))
end

local function _summary_fields(dir)
  local text = fs_lib.read_raw(dir .. "/summary.txt")
  if text == nil then return nil, "missing evidence summary: " .. dir .. "/summary.txt" end
  local fields = { sources = {} }
  for line in (text .. "\n"):gmatch("([^\n]*)\n") do
    line = line:gsub("\r$", "")
    local key, value = line:match("^([%w_]+)=(.*)$")
    if key == "source" then
      fields.sources[#fields.sources + 1] = value
    elseif key ~= nil then
      fields[key] = value
    end
  end
  return fields
end

-- lanes = { { label=..., raw=..., files={...}? }, ... }
-- 原始输出逐 lane 落盘,汇总值只记录不重算;重算走 recount。
function M.write(dir, spec)
  local ok, err = fs_lib.ensure_dir(dir)
  if not ok then return nil, err end
  local lanes = (spec or {}).lanes or {}
  local lines = {
    "profile=" .. tostring(spec.profile or ""),
    "mode=" .. tostring(spec.mode or ""),
    "exit_code=" .. tostring(spec.exit_code or ""),
  }
  local entries = {}
  for _, lane in ipairs(lanes) do
    local name = _safe(lane.label)
    local written, write_err = fs_lib.write_file(dir .. "/" .. name .. ".tap", tostring(lane.raw or ""))
    if not written then return nil, write_err end
    lines[#lines + 1] = "source=" .. name
    if lane.files ~= nil then
      local listed, list_err = fs_lib.write_file(dir .. "/" .. name .. ".files",
        table.concat(lane.files, "\n") .. (#lane.files > 0 and "\n" or ""))
      if not listed then return nil, list_err end
    end
    entries[#entries + 1] = { label = lane.label, raw = lane.raw }
  end
  local aggregated = M.aggregate(entries)
  lines[#lines + 1] = "counts=" .. (aggregated.counts and M.format_counts(aggregated.counts) or "")
  lines[#lines + 1] = "tap_passed=" .. aggregated.tally.passed
  lines[#lines + 1] = "tap_failed=" .. aggregated.tally.failed
  lines[#lines + 1] = "missing_counts=" .. table.concat(aggregated.missing, ",")
  return fs_lib.write_file(dir .. "/summary.txt", table.concat(lines, "\n") .. "\n")
end

-- 仅凭证据目录重算:原始 .tap → COUNTS 合计 + TAP 行计数,再与 summary.txt 里
-- 当时记录的汇总值逐项核对。match=false 表示证据被改过或当时汇总就不可信。
function M.recount(dir)
  local fields, err = _summary_fields(dir)
  if fields == nil then return nil, err end
  if #fields.sources == 0 then return nil, "evidence has no raw lane output: " .. tostring(dir) end
  local entries = {}
  for _, name in ipairs(fields.sources) do
    local raw = fs_lib.read_raw(dir .. "/" .. name .. ".tap")
    if raw == nil then return nil, "missing raw lane output: " .. dir .. "/" .. name .. ".tap" end
    entries[#entries + 1] = { label = name, raw = raw }
  end
  local aggregated = M.aggregate(entries)
  local expected_counts = fields.counts ~= "" and fields.counts or nil
  local actual_counts = aggregated.counts and M.format_counts(aggregated.counts) or nil
  local differences = {}
  -- nil == nil 不是可重算:汇总或原始输出任一侧缺 COUNTS,都不能给 match。
  if expected_counts == nil or actual_counts == nil then
    if expected_counts == nil then
      differences[#differences + 1] = "summary missing COUNTS"
    end
    if actual_counts == nil then
      differences[#differences + 1] = "raw evidence missing COUNTS from lanes: "
        .. table.concat(aggregated.missing, ",")
    end
  elseif expected_counts ~= actual_counts then
    differences[#differences + 1] = "counts expected=" .. tostring(expected_counts)
      .. " actual=" .. tostring(actual_counts)
  end
  if tonumber(fields.tap_passed) ~= aggregated.tally.passed
      or tonumber(fields.tap_failed) ~= aggregated.tally.failed then
    differences[#differences + 1] = string.format("tap expected=%s/%s actual=%d/%d",
      tostring(fields.tap_passed), tostring(fields.tap_failed),
      aggregated.tally.passed, aggregated.tally.failed)
  end
  return {
    match = #differences == 0,
    detail = table.concat(differences, "; "),
    counts = aggregated.counts,
    tally = aggregated.tally,
    missing = aggregated.missing,
    profile = fields.profile,
    mode = fields.mode,
    exit_code = fields.exit_code,
  }
end

return M
