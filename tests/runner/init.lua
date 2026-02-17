local report = require("runner.report")
local spec_loader = require("runner.spec_loader")
local spec_filter = require("runner.filter")
local post_checks = require("runner.post_checks")

local runner = {}

local function _run_aaa_case(case_def)
  local ctx = nil
  if type(case_def.arrange) == "function" then
    ctx = case_def.arrange()
  end
  if type(case_def.act) == "function" then
    case_def.act(ctx)
  end
  if type(case_def.assert) == "function" then
    case_def.assert(ctx)
  end
end

local function _run_case(case_def)
  if type(case_def.run) == "function" then
    case_def.run()
    return
  end
  _run_aaa_case(case_def)
end

local function _run_specs(specs, filter)
  local total = 0
  local failures = {}

  for _, spec in ipairs(specs) do
    if not spec_filter.allow_spec(spec, filter) then
      goto continue
    end
    local layer = spec.layer or "unknown"
    local domain = spec.domain or "unknown"
    for _, case_def in ipairs(spec.cases or {}) do
      total = total + 1
      math.randomseed(1)
      local ok, err = xpcall(function()
        _run_case(case_def)
      end, debug.traceback)
      if ok then
        report.on_case_ok()
      else
        report.on_case_failed()
        failures[#failures + 1] = {
          layer = layer,
          domain = domain,
          id = case_def.id or case_def.desc or (domain .. "_case_" .. tostring(total)),
          err = err,
        }
      end
    end
    ::continue::
  end

  return total, failures
end

function runner.run(opts)
  opts = opts or {}
  local include_internal = post_checks.resolve_include_internal(opts)
  local specs = spec_loader.collect_all()
  local filter = spec_filter.from_opts(opts)

  if include_internal ~= true then
    local filtered = {}
    for _, spec in ipairs(specs) do
      if spec.domain ~= "internal_dep_rules" and spec.domain ~= "internal_gameplay_loop_no_ui" then
        filtered[#filtered + 1] = spec
      end
    end
    specs = filtered
  end

  local total, failures = _run_specs(specs, filter)
  report.finish(total, failures)
end

return runner
