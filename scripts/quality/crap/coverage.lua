local catalog = require("tests.catalog")
local harness = require("TestHarness")
local regression_mode = require("tests.support.regression_mode")
local common = require("crap.common")

local coverage = {}

local function _silent_reporter()
  return {
    case_pass = function() end,
    case_fail = function() end,
    finish = function() end,
  }
end

local function _normalize_debug_source(project_root, source)
  local normalized = common.relative_to(project_root, source)
  return normalized:gsub("^%./", "")
end

local function _make_hook(project_root, tracked_sources, line_hits)
  return function(_, line_no)
    local info = debug.getinfo(2, "S")
    if info == nil or info.source == nil then
      return
    end
    local relative_path = _normalize_debug_source(project_root, info.source)
    if tracked_sources[relative_path] ~= true then
      return
    end
    local hit_lines = line_hits[relative_path]
    if hit_lines == nil then
      hit_lines = {}
      line_hits[relative_path] = hit_lines
    end
    hit_lines[line_no] = true
  end
end

local function _resolve_lane_suites(lane, mode)
  if lane == "behavior" then
    return catalog.load_behavior_suites(), regression_mode.resolve_behavior_mode(mode)
  end
  if lane == "contract" then
    return catalog.load_contract_suites(), "dev"
  end
  error("unsupported lane for CRAP coverage: " .. tostring(lane))
end

function coverage.collect(opts)
  local project_root = common.normalize_path(opts.project_root)
  local tracked_sources = {}
  for _, source_path in ipairs(opts.tracked_sources or {}) do
    tracked_sources[common.normalize_path(source_path)] = true
  end

  local line_hits = {}
  local lane_results = {}

  for _, lane in ipairs(opts.lanes or { "behavior" }) do
    local suites, resolved_mode = _resolve_lane_suites(lane, opts.mode)
    local hook = _make_hook(project_root, tracked_sources, line_hits)
    local result = harness.run_all(suites, {
      mode = resolved_mode,
      capture_logs = true,
      reporter = _silent_reporter(),
      raise_on_failure = false,
      before_case = function()
        debug.sethook(hook, "l")
      end,
      after_case = function()
        debug.sethook()
      end,
    })
    lane_results[#lane_results + 1] = {
      lane = lane,
      mode = resolved_mode,
      total = result.total,
      failed = result.failed,
      failure_count = #result.failures,
      failures = result.failures,
    }
  end

  debug.sethook()

  return {
    line_hits = line_hits,
    lanes = lane_results,
  }
end

return coverage
