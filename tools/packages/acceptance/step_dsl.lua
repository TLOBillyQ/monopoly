-- Generic step DSL for project acceptance handlers (monopoly#192).
--
-- A project's step handlers are a plain table keyed by step *sentence*. This
-- module turns a more legible authoring form into that table without changing
-- what `acceptance.runtime` dispatches:
--
--   * a plain sentence, or one carrying `<名>` placeholders, passes through
--     verbatim — the runtime binds `<名>` from the Examples table as before;
--   * a `<名:int>` annotation is stripped back to `<名>` (so the dispatch shape
--     is unchanged) and the handler is wrapped to coerce that column to an
--     integer via NumberUtils before the body runs;
--   * an inline-capture sentence using `{名}` / `{名:int}` compiles to an
--     anchored Lua pattern collected under the returned table's `__patterns`
--     array, which the runtime tries after exact- and shape-dispatch miss.
--
-- Numbers go through `number_utils` only — `tonumber` and `type == "number"`
-- are banned here (repo rule), just as in `src/`.

local number_utils = require("src.foundation.number")

local dsl = {}

-- Lua-pattern magic characters that must be escaped when a literal slice of a
-- `{}`-capture sentence is spliced into the compiled pattern.
local _MAGIC = "[%(%)%.%%%+%-%*%?%[%]%^%$]"

local function _escape_literal(text)
  return (tostring(text):gsub(_MAGIC, "%%%1"))
end

-- Strip `<名:int>` annotations back to `<名>` so the dispatch shape is
-- unchanged, recording which placeholder names must be coerced to integers.
local function _strip_int_annotations(sentence)
  local int_params = {}
  local key = sentence:gsub("<([^<>:]+):int>", function(name)
    int_params[name] = true
    return "<" .. name .. ">"
  end)
  return key, int_params
end

-- Wrap a handler so annotated `<名:int>` columns arrive already coerced. The
-- body receives a shallow copy of the example with those keys replaced; every
-- other column passes through untouched. A value that does not read as an
-- integer fails the step with a uniform message rather than reaching the body.
local function _wrap_int(fn, int_params)
  return function(world, example, step, resolved_text)
    local args = {}
    for key, value in pairs(example or {}) do
      args[key] = value
    end
    for name in pairs(int_params) do
      local raw = (example or {})[name]
      local converted = number_utils.to_integer(raw)
      if converted == nil then
        return nil, "invalid <" .. name .. ">: " .. tostring(raw)
      end
      args[name] = converted
    end
    return fn(world, args, step, resolved_text)
  end
end

-- Compile a `{名}` / `{名:int}` sentence into an anchored Lua pattern. `{名}`
-- captures a non-empty, reasonably greedy run (`(.+)`); `{名:int}` captures a
-- signed integer literal (`(-?%d+)`) that the runtime coerces via NumberUtils.
-- The exact greediness is pinned by the spec.
local function _compile_pattern(sentence, fn)
  local names, types = {}, {}
  local parts = { "^" }
  local pos = 1
  while true do
    local start_index, end_index, name, annotation =
      sentence:find("{([^{}:]+):?([^{}]*)}", pos)
    if start_index == nil then
      break
    end
    parts[#parts + 1] = _escape_literal(sentence:sub(pos, start_index - 1))
    names[#names + 1] = name
    if annotation == "int" then
      types[name] = "int"
      parts[#parts + 1] = "(-?%d+)"
    else
      types[name] = "text"
      parts[#parts + 1] = "(.+)"
    end
    pos = end_index + 1
  end
  parts[#parts + 1] = _escape_literal(sentence:sub(pos))
  parts[#parts + 1] = "$"
  return {
    pattern = table.concat(parts),
    names = names,
    types = types,
    fn = fn,
    source = sentence,
  }
end

-- Turn a `["句面"] = fn` table into a runtime handlers table. Plain and `<名>`
-- sentences become exact keys; `{}`-capture sentences are gathered into
-- `__patterns`. Two sentences collapsing to the same dispatch key is a bug in
-- the definitions, so it errors rather than silently dropping one.
function dsl.steps(defs, _opts)
  local handlers = {}
  local patterns = {}
  for sentence, fn in pairs(defs) do
    if sentence:find("{", 1, true) then
      patterns[#patterns + 1] = _compile_pattern(sentence, fn)
    else
      local key, int_params = _strip_int_annotations(sentence)
      if handlers[key] ~= nil then
        error("duplicate step key from DSL definitions: \"" .. tostring(key) .. "\"")
      end
      if next(int_params) == nil then
        handlers[key] = fn
      else
        handlers[key] = _wrap_int(fn, int_params)
      end
    end
  end
  if #patterns > 0 then
    handlers.__patterns = patterns
  end
  return handlers
end

-- Merge `extra` into `base` in place. Ordinary keys must not collide (same
-- contract the hand-written aggregator used); the `__patterns` arrays are
-- concatenated so pattern handlers from several modules coexist.
function dsl.merge(base, extra, module_name)
  for key, value in pairs(extra or {}) do
    if key == "__patterns" then
      local target = base.__patterns
      if target == nil then
        target = {}
        base.__patterns = target
      end
      for _, entry in ipairs(value) do
        target[#target + 1] = entry
      end
    elseif base[key] ~= nil then
      error("handler key collision in " .. tostring(module_name) .. ": \"" .. tostring(key) .. "\"")
    else
      base[key] = value
    end
  end
  return base
end

-- Assertion primitives. Each returns `true` on success or `nil, message`, with
-- a uniform message that names the label, the expectation and the actual value.

function dsl.eq(actual, expected, label)
  if actual == expected then
    return true
  end
  return nil, tostring(label) .. ": 期望 " .. tostring(expected) .. ",实际 " .. tostring(actual)
end

function dsl.ne(actual, expected, label)
  if actual ~= expected then
    return true
  end
  return nil, tostring(label) .. ": 期望不等于 " .. tostring(expected) .. ",实际 " .. tostring(actual)
end

function dsl.range(value, min, max, label)
  if value ~= nil and value >= min and value <= max then
    return true
  end
  return nil, tostring(label) .. ": 期望落在 [" .. tostring(min) .. ", " .. tostring(max)
    .. "],实际 " .. tostring(value)
end

function dsl.contains(haystack, needle, label)
  if type(haystack) == "string" then
    if haystack:find(tostring(needle), 1, true) ~= nil then
      return true
    end
  elseif type(haystack) == "table" then
    for _, item in ipairs(haystack) do
      if item == needle then
        return true
      end
    end
  end
  return nil, tostring(label) .. ": 期望包含 " .. tostring(needle) .. ",实际 " .. tostring(haystack)
end

function dsl.truthy(value, label)
  if value then
    return true
  end
  return nil, tostring(label) .. ": 期望为真,实际 " .. tostring(value)
end

-- Run each zero-arg check in order; return the first failure's `nil, message`,
-- or `true` when all pass. Lets a handler compose several primitives cleanly.
function dsl.all(...)
  local checks = { ... }
  for _, check in ipairs(checks) do
    local ok, message = check()
    if not ok then
      return nil, message
    end
  end
  return true
end

return dsl
