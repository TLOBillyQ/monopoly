local filter = {}

local function _module_component(modules, module_id)
  local module_info = modules and modules[module_id] or nil
  return module_info and module_info.component or nil
end

local function _feedback_edge_is_namespace_projection_artifact(architecture, feedback_edge)
  local modules = architecture and architecture.modules or {}
  for _, module_edge in ipairs(feedback_edge.module_edges or {}) do
    local from_component = _module_component(modules, module_edge.from)
    local to_component = _module_component(modules, module_edge.to)
    if from_component == feedback_edge.from and to_component == feedback_edge.to then
      return false
    end
  end
  return true
end

local function _projection_cycle_is_namespace_projection_artifact(architecture, violation)
  if violation.kind ~= "projection_cycle" or violation.view ~= "root" then
    return false
  end
  local feedback_edges = violation.feedback_edges or {}
  if #feedback_edges == 0 then
    return false
  end
  for _, feedback_edge in ipairs(feedback_edges) do
    if not _feedback_edge_is_namespace_projection_artifact(architecture, feedback_edge) then
      return false
    end
  end
  return true
end

function filter.apply(architecture)
  local check = architecture and architecture.check or nil
  if type(check) ~= "table" then
    return architecture
  end

  local kept_violations = {}
  local kept_projection_cycles = {}

  for _, violation in ipairs(check.violations or {}) do
    if not _projection_cycle_is_namespace_projection_artifact(architecture, violation) then
      kept_violations[#kept_violations + 1] = violation
      if violation.kind == "projection_cycle" then
        kept_projection_cycles[#kept_projection_cycles + 1] = {
          view = violation.view,
          feedback_edges = violation.feedback_edges,
        }
      end
    end
  end

  check.violations = kept_violations
  check.projection_cycles = kept_projection_cycles
  check.ok = #kept_violations == 0
  architecture.check = check
  return architecture
end

return filter
