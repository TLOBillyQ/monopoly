local runtime = {}

local function _parameters(text)
  local values = {}
  for name in tostring(text or ""):gmatch("<([A-Za-z0-9_]+)>") do
    values[#values + 1] = name
  end
  return values
end

local function _execution_examples(scenario)
  if #(scenario.examples or {}) == 0 then
    return { {} }
  end
  return scenario.examples
end

local function _execution_name(scenario, example_index)
  return tostring(scenario.name or "scenario") .. "/example_" .. tostring(example_index)
end

local function _source_diagnostic(ir, step, message)
  local source_path = ((step or {}).metadata or {}).source_path
    or ((ir or {}).metadata or {}).source_path
  local source_line = ((step or {}).metadata or {}).source_line
  local prefix = ""
  if source_path ~= nil and source_path ~= "" then
    prefix = tostring(source_path) .. ":"
  end
  if source_line ~= nil then
    prefix = prefix .. "第" .. tostring(source_line) .. "行: "
  end
  return prefix .. tostring(message)
end

local function _field_name(ir, parameter)
  return (((ir or {}).metadata or {}).field_names or {})[parameter] or parameter
end

local function _resolve_step(ir, step, example)
  for _, parameter in ipairs(_parameters(step.text)) do
    if example[parameter] == nil then
      return nil, _source_diagnostic(ir, step, "missing example value: " .. tostring(_field_name(ir, parameter)))
    end
  end

  local resolved = tostring(step.text or ""):gsub("<([A-Za-z0-9_]+)>", function(parameter)
    return tostring(example[parameter])
  end)
  return resolved
end

local function _run_step(ir, world, example, step, handlers)
  local handler = (handlers or {})[step.text]
  if handler == nil then
    return nil, _source_diagnostic(ir, step, "unsupported step: " .. tostring(step.text))
  end

  local resolved_text, resolve_err = _resolve_step(ir, step, example)
  if resolved_text == nil then
    return nil, resolve_err
  end

  local ok, success, err = pcall(handler, world, example, step, resolved_text)
  if not ok then
    return nil, success
  end
  if success == false or err ~= nil then
    return nil, err or "step failed: " .. tostring(step.text)
  end
  return true
end

function runtime.run_execution(ir, scenario, example, handlers)
  local world = {}
  local steps = {}
  for _, step in ipairs(ir.background or {}) do
    steps[#steps + 1] = step
  end
  for _, step in ipairs(scenario.steps or {}) do
    steps[#steps + 1] = step
  end

  for _, step in ipairs(steps) do
    local ok, err = _run_step(ir, world, example or {}, step, handlers)
    if not ok then
      return nil, err
    end
  end
  return true
end

function runtime.run_feature(ir, handlers)
  local result = {
    ok = true,
    failures = {},
  }

  for _, scenario in ipairs(ir.scenarios or {}) do
    for example_index, example in ipairs(_execution_examples(scenario)) do
      local ok, err = runtime.run_execution(ir, scenario, example, handlers)
      if not ok then
        result.ok = false
        result.failures[#result.failures + 1] = {
          name = _execution_name(scenario, example_index),
          error = err,
        }
      end
    end
  end

  return result
end

function runtime.format_failures(result)
  local lines = {}
  for _, failure in ipairs((result or {}).failures or {}) do
    lines[#lines + 1] = tostring(failure.name) .. ": " .. tostring(failure.error)
  end
  return table.concat(lines, "\n")
end

function runtime.define_busted_specs(ir, handlers, define_it)
  define_it = define_it or rawget(_G, "it")
  assert(define_it ~= nil, "missing busted it function")
  for _, scenario in ipairs(ir.scenarios or {}) do
    for example_index, example in ipairs(_execution_examples(scenario)) do
      local name = _execution_name(scenario, example_index)
      define_it(name, function()
        local ok, err = runtime.run_execution(ir, scenario, example, handlers)
        assert(ok, err)
      end)
    end
  end
end

return runtime
