local report = require("runner.report")
local legacy_adapter = require("runner.legacy_adapter")

local runner = {}

local function _split_csv(value)
  if type(value) ~= "string" or value == "" then
    return nil
  end
  local set = {}
  for token in string.gmatch(value, "[^,]+") do
    local normalized = string.gsub(token, "^%s*(.-)%s*$", "%1")
    if normalized ~= "" then
      set[normalized] = true
    end
  end
  return set
end

local function _truthy_env(name)
  local value = os.getenv(name)
  if not value then
    return false
  end
  value = string.lower(value)
  return value == "1" or value == "true" or value == "yes" or value == "on"
end

local function _new_specs()
  return {
    require("contract.ports_contract_spec"),
    require("unit.runtime_phase_flags_spec"),
    require("unit.action_button_timer_spec"),
    require("integration.turn_phase_anim_spec"),
    require("integration.visual_input_lock_spec"),
    require("regression.gameplay_main_flow_spec"),
  }
end

local function _append_all(target, items)
  for _, item in ipairs(items or {}) do
    target[#target + 1] = item
  end
end

local function _allow_spec(spec, filter)
  if not filter then
    return true
  end
  if filter.layers and not filter.layers[spec.layer or "unknown"] then
    return false
  end
  if filter.domains and not filter.domains[spec.domain or "unknown"] then
    return false
  end
  return true
end

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
    if not _allow_spec(spec, filter) then
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
  local specs = {}
  _append_all(specs, _new_specs())

  local include_legacy = opts.include_legacy
  if include_legacy == nil then
    include_legacy = _truthy_env("TEST_INCLUDE_LEGACY")
  end

  local include_internal = opts.include_internal
  if include_internal == nil then
    include_internal = true
  end

  local filter = {
    layers = opts.layers or _split_csv(os.getenv("TEST_LAYERS")),
    domains = opts.domains or _split_csv(os.getenv("TEST_DOMAINS")),
  }
  if filter.layers == nil and filter.domains == nil then
    filter = nil
  end

  if include_legacy == true then
    _append_all(specs, legacy_adapter.collect_legacy_specs())
  end

  local total, failures = _run_specs(specs, filter)
  if include_internal ~= false then
    legacy_adapter.run_legacy_internal_scripts()
  end
  report.finish(total, failures)
end

return runner
