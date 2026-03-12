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

local function _resolve_hit_lines(line_hits, relative_path)
  local hit_lines = line_hits[relative_path]
  if hit_lines == nil then
    hit_lines = {}
    line_hits[relative_path] = hit_lines
  end
  return hit_lines
end

local function _resolve_cached_hit_lines(debug_api, function_cache, project_root, tracked_sources, line_hits)
  local function_info = debug_api.getinfo(3, "f")
  local current_function = function_info and function_info.func or nil
  if current_function == nil then
    return nil
  end

  local cached_hit_lines = function_cache[current_function]
  if cached_hit_lines ~= nil then
    return cached_hit_lines or nil
  end

  local source_info = debug_api.getinfo(3, "Sf")
  if source_info == nil or source_info.source == nil then
    function_cache[current_function] = false
    return nil
  end

  local relative_path = _normalize_debug_source(project_root, source_info.source)
  if tracked_sources[relative_path] ~= true then
    function_cache[current_function] = false
    return nil
  end

  local hit_lines = _resolve_hit_lines(line_hits, relative_path)
  function_cache[current_function] = hit_lines
  return hit_lines
end

local function _make_hook(project_root, tracked_sources, line_hits, debug_api)
  local function_cache = setmetatable({}, { __mode = "k" })
  return function(_, line_no)
    local hit_lines = _resolve_cached_hit_lines(
      debug_api,
      function_cache,
      project_root,
      tracked_sources,
      line_hits
    )
    if hit_lines ~= nil then
      hit_lines[line_no] = true
    end
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

local function _resolve_dependencies(opts)
  return {
    resolve_lane_suites = opts.resolve_lane_suites or _resolve_lane_suites,
    run_all = opts.run_all or harness.run_all,
    debug_api = opts.debug_api or debug,
  }
end

function coverage.collect(opts)
  opts = opts or {}
  local deps = _resolve_dependencies(opts or {})
  local project_root = common.normalize_path(opts.project_root)
  local tracked_sources = {}
  for _, source_path in ipairs(opts.tracked_sources or {}) do
    tracked_sources[common.normalize_path(source_path)] = true
  end

  local line_hits = {}
  local lane_results = {}

  for _, lane in ipairs(opts.lanes or { "behavior" }) do
    local suites, resolved_mode = deps.resolve_lane_suites(lane, opts.mode)
    local hook = _make_hook(project_root, tracked_sources, line_hits, deps.debug_api)
    local result = deps.run_all(suites, {
      mode = resolved_mode,
      capture_logs = true,
      reporter = _silent_reporter(),
      raise_on_failure = false,
      before_case = function()
        deps.debug_api.sethook(hook, "l")
      end,
      after_case = function()
        deps.debug_api.sethook()
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

  deps.debug_api.sethook()

  return {
    line_hits = line_hits,
    lanes = lane_results,
  }
end

return coverage
