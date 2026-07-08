-- autotest 结果的唯一事实源：结构化 entries + log.txt 行格式。
-- 行格式是与 tools/ops/autotest_report.ps1 的解析契约，改动要同步两端与
-- spec/behavior/app/autotest_results_spec.lua。
local results = {}

local LINE_TAG = "[autotest]"

local function _format_seconds(value)
  return string.format("%.1f", value or 0)
end

local function _sanitize_message(text)
  local flat = tostring(text or ""):gsub("[\r\n]+", " ")
  return (flat:gsub('"', "'"))
end

function results.begin_line(selector, total)
  return LINE_TAG .. " begin selector=" .. tostring(selector) .. " total=" .. tostring(total)
end

function results.profile_line(entry)
  local parts = {
    LINE_TAG,
    "profile=" .. tostring(entry.profile),
    "index=" .. tostring(entry.index),
    "result=" .. tostring(entry.result),
    "reason=" .. tostring(entry.reason),
    "turns=" .. tostring(entry.turns or 0),
    "seconds=" .. _format_seconds(entry.seconds),
    "warns=" .. tostring(entry.warns or 0),
  }
  if entry.message ~= nil and entry.message ~= "" then
    parts[#parts + 1] = 'message="' .. _sanitize_message(entry.message) .. '"'
  end
  return table.concat(parts, " ")
end

function results.summary_line(recorder)
  local totals = recorder:totals()
  return LINE_TAG .. " summary total=" .. totals.total
    .. " pass=" .. totals.pass
    .. " fail=" .. totals.fail
    .. " seconds=" .. _format_seconds(totals.seconds)
end

function results.error_line(message)
  return LINE_TAG .. ' error message="' .. _sanitize_message(message) .. '"'
end

local recorder_methods = {}
recorder_methods.__index = recorder_methods

-- entry: { profile, index, result = "pass"|"fail", reason, turns, seconds, warns, message? }
function recorder_methods:record(entry)
  assert(type(entry) == "table" and entry.profile ~= nil, "invalid autotest result entry")
  assert(entry.result == "pass" or entry.result == "fail",
    "invalid autotest result value: " .. tostring(entry.result))
  self.entries[#self.entries + 1] = entry
  return entry
end

function recorder_methods:totals()
  local totals = { total = #self.entries, pass = 0, fail = 0, seconds = 0 }
  for _, entry in ipairs(self.entries) do
    if entry.result == "pass" then
      totals.pass = totals.pass + 1
    else
      totals.fail = totals.fail + 1
    end
    totals.seconds = totals.seconds + (entry.seconds or 0)
  end
  return totals
end

function results.new_recorder()
  return setmetatable({ entries = {} }, recorder_methods)
end

return results
