-- Project acceptance runtime (issue #132).
--
-- Dispatches a Gherkin step to a step handler by *shape*: the step text with
-- every `<占位符>` erased. A scenario routinely refers to several instances of
-- the same thing (`<槽位>`, `<新槽位>`, `<验证槽位>`), so one step shape must be
-- able to carry different example columns. The runtime captures the placeholder
-- name used by the step, reads that key from the example, and binds the value to
-- the name the handler declared in its registration key. Handlers therefore
-- register once per shape, not once per placeholder name.
--
-- Exact step text still wins over a shape match, which keeps the handful of
-- steps whose meaning genuinely forks on the placeholder name (skin_shop's
-- assert-only 验证槽位) dispatching to their own handler.

local source = require("acceptance4lua.source")
local number_utils = require("src.foundation.number")

local runtime = {}

local function _shape(text)
  return (tostring(text or ""):gsub("<[^<>]+>", "<>"))
end

-- Index handlers by shape once per handlers table. Two handlers sharing a shape
-- are kept as `ambiguous` rather than silently letting one win: only an exact
-- step-text match can pick between them.
local _shape_indexes = setmetatable({}, { __mode = "k" })

local function _shape_index(handlers)
  local cached = _shape_indexes[handlers]
  if cached ~= nil then
    return cached
  end

  local index = {}
  for key, handler in pairs(handlers) do
    if key ~= "__patterns" then
      local shape = _shape(key)
      local entry = index[shape]
      if entry == nil then
        index[shape] = { handler = handler, parameters = source.extract_parameters(key), keys = { key } }
      else
        entry.ambiguous = true
        entry.keys[#entry.keys + 1] = key
      end
    end
  end
  _shape_indexes[handlers] = index
  return index
end

local function _ambiguous_error(entry, step_text)
  local keys = { table.unpack(entry.keys) }
  table.sort(keys)
  return "ambiguous step shape for: " .. tostring(step_text)
    .. "; registered under " .. table.concat(keys, ", ")
    .. "; register one handler for the shape or add an exact handler for this step"
end

-- Bind the step's placeholder values to the names the handler declared. Every
-- original example column stays readable; only the handler's own parameter names
-- are (re)bound, and only when the step named them differently.
local function _bind_example(example, step_parameters, declared_parameters)
  local bound = {}
  for key, value in pairs(example) do
    bound[key] = value
  end
  for index, declared in ipairs(declared_parameters) do
    bound[declared] = example[step_parameters[index]]
  end
  return bound
end

-- Third dispatch tier: inline-capture patterns (see acceptance.step_dsl). Each
-- entry anchors a Lua pattern against the whole step text; a matched entry binds
-- its captures to the declared names, coercing `:int` captures via NumberUtils.
-- A capture that fails coercion is treated as a non-match so a later pattern can
-- still claim the step.
local function _pattern_binding(entry, text)
  local captures = { text:match(entry.pattern) }
  if captures[1] == nil then
    return nil
  end
  local binding = {}
  for index, name in ipairs(entry.names) do
    local value = captures[index]
    if entry.types[name] == "int" then
      local converted = number_utils.to_integer(value)
      if converted == nil then
        return nil
      end
      value = converted
    end
    binding[name] = value
  end
  return binding
end

-- Hint the nearest pattern when nothing matched: the one sharing the longest
-- literal prefix with the step text, so an author sees which pattern they were
-- close to satisfying.
local function _nearest_pattern_hint(patterns, text)
  local best_source, best_len
  for _, entry in ipairs(patterns) do
    local prefix = tostring(entry.source or ""):match("^([^{]*)") or ""
    local shared = 0
    for byte_index = 1, math.min(#prefix, #text) do
      if prefix:byte(byte_index) == text:byte(byte_index) then
        shared = byte_index
      else
        break
      end
    end
    if best_len == nil or shared > best_len then
      best_len, best_source = shared, entry.source
    end
  end
  if best_source == nil or best_len == 0 then
    return ""
  end
  return "; 最近候选: " .. tostring(best_source)
end

-- Patterns capture example *values*, so they match the resolved step text. A
-- pruned Examples column leaves steps that mix literals with live placeholders
-- (`玩家2附体<神灵>持续3回合`); matching the raw text there would capture the
-- `<神灵>` spelling instead of the example value.
local function _resolve_pattern(ir, step, handlers, resolved_text)
  local patterns = handlers.__patterns
  if patterns == nil or #patterns == 0 then
    return nil, source.step_error(ir, step, "unsupported step: " .. tostring(step.text))
  end

  local hits = {}
  for _, entry in ipairs(patterns) do
    local binding = _pattern_binding(entry, resolved_text)
    if binding ~= nil then
      hits[#hits + 1] = { entry = entry, binding = binding }
    end
  end

  if #hits == 1 then
    return hits[1].entry.fn, hits[1].binding
  end
  if #hits > 1 then
    local sources = {}
    for _, hit in ipairs(hits) do
      sources[#sources + 1] = tostring(hit.entry.source)
    end
    table.sort(sources)
    return nil, source.step_error(ir, step, "ambiguous pattern for: " .. tostring(step.text)
      .. "; matched " .. table.concat(sources, ", "))
  end

  return nil, source.step_error(ir, step, "unsupported step: " .. tostring(step.text)
    .. _nearest_pattern_hint(patterns, resolved_text))
end

-- Resolve a step to (handler, example-view). handlers keyed by exact step text
-- take precedence; otherwise the step's shape selects the handler; failing both,
-- the inline-capture patterns get a turn.
local function _resolve_handler(ir, step, example, handlers, resolved_text)
  handlers = handlers or {}

  local exact = handlers[step.text]
  if exact ~= nil then
    return exact, example
  end

  local entry = _shape_index(handlers)[_shape(step.text)]
  if entry == nil then
    return _resolve_pattern(ir, step, handlers, resolved_text)
  end
  if entry.ambiguous then
    return nil, source.step_error(ir, step, _ambiguous_error(entry, step.text))
  end

  local step_parameters = source.extract_parameters(step.text)
  return entry.handler, _bind_example(example, step_parameters, entry.parameters)
end

local function _resolve_step(ir, step, example)
  for _, parameter in ipairs(source.extract_parameters(step.text)) do
    if example[parameter] == nil then
      return nil, source.step_error(ir, step, "missing example value: " .. tostring(source.field_name(ir, parameter)))
    end
  end

  local resolved = tostring(step.text or ""):gsub("<([^<>]+)>", function(parameter)
    return tostring(example[parameter])
  end)
  return resolved
end

local function _run_step(ir, world, example, step, handlers)
  local resolved_text, resolve_err = _resolve_step(ir, step, example)
  if resolved_text == nil then
    return nil, resolve_err
  end

  local handler, bound_or_err = _resolve_handler(ir, step, example, handlers, resolved_text)
  if handler == nil then
    return nil, bound_or_err
  end

  local ok, success, err = pcall(handler, world, bound_or_err, step, resolved_text)
  if not ok then
    return nil, success
  end
  if success == false or err ~= nil then
    return nil, err or "step failed: " .. tostring(step.text)
  end
  return true
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

function runtime.define_specs(ir, handlers, define_it)
  define_it = define_it or rawget(_G, "it")
  assert(define_it ~= nil, "missing it function")
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
