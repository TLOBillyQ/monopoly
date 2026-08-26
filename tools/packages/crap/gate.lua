-- Pure logic for the CRAP gate.
-- IO (reading collect JSON, building the report, process exit) lives in
-- tools/packages/coverage/crap_gate.lua; this module is side-effect free so it can be
-- unit tested directly.
local gate = {}

-- A function violates the gate when its CRAP score exceeds the threshold, or
-- when no coverage was measurable for it (N/A, #275-③): without coverage data
-- the score is null, not 0 — an unmeasurable function is treated as a
-- violation, never as free cover. The bar is flat: there is no per-file budget
-- and no complexity-aware escape hatch. Because CRAP equals complexity at 100%
-- coverage, a function whose complexity exceeds the threshold can only pass by
-- being split.
--
-- N/A 有两种存在形态:JSON 往返后 null -> nil,analyzer 内存对象则是
-- json_writer.null 哨兵表。统一按「crap 不是 number」判定不可测,两种形态都
-- 落进违例,不必 require 上游 json_writer。
function gate.is_violation(fn, threshold)
  return type(fn.crap) ~= "number" or fn.crap > threshold
end

-- Group violating functions by source_path. Returns a map
-- source_path -> { count = N, functions = { {name, complexity, crap, ...}, ... } }.
function gate.violations_by_file(functions, threshold)
  local by_file = {}
  for _, fn in ipairs(functions or {}) do
    if gate.is_violation(fn, threshold) then
      local bucket = by_file[fn.source_path]
      if not bucket then
        bucket = { count = 0, functions = {} }
        by_file[fn.source_path] = bucket
      end
      bucket.count = bucket.count + 1
      bucket.functions[#bucket.functions + 1] = {
        name = fn.name,
        complexity = fn.complexity,
        crap = fn.crap,
        coverage = fn.coverage,
        start_line = fn.start_line,
      }
    end
  end
  return by_file
end

function gate.total_violations(by_file)
  local total = 0
  for _, bucket in pairs(by_file or {}) do
    total = total + bucket.count
  end
  return total
end

-- N/A 排序键:crap 非数字(含 json_writer.null 哨兵)排最前,其余按值降序。
local function _crap_sort_key(fn)
  return type(fn.crap) == "number" and fn.crap or -1
end

-- Every violation is a failure. Returns offending files sorted by path, each
-- carrying its violating functions sorted by descending CRAP.
function gate.evaluate(by_file)
  local offenders = {}
  for source_path, bucket in pairs(by_file or {}) do
    local fns = {}
    for _, fn in ipairs(bucket.functions) do fns[#fns + 1] = fn end
    table.sort(fns, function(a, b) return _crap_sort_key(a) > _crap_sort_key(b) end)
    offenders[#offenders + 1] = {
      source_path = source_path,
      count = bucket.count,
      functions = fns,
    }
  end
  table.sort(offenders, function(a, b) return a.source_path < b.source_path end)
  return offenders
end

return gate
