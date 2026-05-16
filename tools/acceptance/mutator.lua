local common = require("shared.lib.common")
local generator = require("acceptance.generator")
local gherkin_parser = require("acceptance.gherkin_parser")
local json = require("acceptance.json")
local runner = require("acceptance.runner")

local mutator = {}

local function _sorted_keys(map)
  local keys = {}
  for key in pairs(map or {}) do
    keys[#keys + 1] = key
  end
  table.sort(keys)
  return keys
end

local function _trim(text)
  return tostring(text or ""):match("^%s*(.-)%s*$")
end

local function _deep_copy(value)
  if type(value) ~= "table" then
    return value
  end
  local copy = {}
  for key, item in pairs(value) do
    copy[_deep_copy(key)] = _deep_copy(item)
  end
  return copy
end

local function _stable_hash(text)
  local hash = 2166136261
  for index = 1, #text do
    hash = (hash ~ text:byte(index)) * 16777619
    hash = hash % 2147483647
  end
  return hash
end

local function _signed_delta(seed, magnitude)
  local delta = (seed % magnitude) + 1
  if seed % 2 == 0 then
    return delta
  end
  return -delta
end

local function _split_list(text)
  local values = {}
  for item in tostring(text or ""):gmatch("([^,]+)") do
    values[#values + 1] = _trim(item)
  end
  return values
end

local function _mutate_list_value(trimmed, seed, path)
  if trimmed:find(",", 1, true) == nil then
    return nil
  end

  local values = _split_list(trimmed)
  if #values == 0 then
    return nil
  end

  local index = (seed % #values) + 1
  values[index] = mutator.mutate_value(values[index], tostring(path) .. "/" .. tostring(index))
  return table.concat(values, ", ")
end

local function _dither_string(value, seed)
  local text = tostring(value or "")
  if text == "" then
    return "x"
  end

  local index = (seed % #text) + 1
  local original = text:sub(index, index)
  local byte = original:byte() or 120
  local replacement
  if byte >= 65 and byte <= 89 then
    replacement = string.char(byte + 1)
  elseif byte == 90 then
    replacement = "A"
  elseif byte >= 97 and byte <= 121 then
    replacement = string.char(byte + 1)
  elseif byte == 122 then
    replacement = "a"
  elseif byte >= 48 and byte <= 56 then
    replacement = string.char(byte + 1)
  elseif byte == 57 then
    replacement = "0"
  else
    replacement = "x"
  end
  if replacement == original then
    replacement = "x"
  end
  return text:sub(1, index - 1) .. replacement .. text:sub(index + 1)
end

local function _mutate_date(year, month, day, seed)
  local timestamp = os.time({
    year = tonumber(year),
    month = tonumber(month),
    day = tonumber(day) + math.abs(_signed_delta(seed, 3)),
    hour = 12,
  })
  return os.date("%Y-%m-%d", timestamp)
end

local function _mutate_time(hour, minute, second, seed)
  local total = tonumber(hour) * 3600 + tonumber(minute) * 60 + tonumber(second or "0")
  total = (total + math.abs(_signed_delta(seed, 300))) % (24 * 3600)
  local new_hour = math.floor(total / 3600)
  local new_minute = math.floor((total % 3600) / 60)
  local new_second = total % 60
  if second == nil then
    return string.format("%02d:%02d", new_hour, new_minute)
  end
  return string.format("%02d:%02d:%02d", new_hour, new_minute, new_second)
end

local function _mutate_duration(trimmed, seed)
  local value, suffix = trimmed:match("^(%-?%d+)(ms)$")
  if value == nil then
    value, suffix = trimmed:match("^(%-?%d+)([smhd])$")
  end
  if value ~= nil then
    local mutated = tonumber(value) + _signed_delta(seed, 9)
    if mutated < 0 then
      mutated = 0
    end
    if tostring(mutated) == tostring(value) then
      mutated = mutated + 1
    end
    return tostring(mutated) .. suffix
  end

  value, suffix = trimmed:match("^PT(%d+)([HMS])$")
  if value ~= nil then
    local mutated = tonumber(value) + math.abs(_signed_delta(seed, 9))
    return "PT" .. tostring(mutated) .. suffix
  end
  return nil
end

local function _mutate_keyword(trimmed)
  local lower = trimmed:lower()
  if lower == "true" then
    return "false"
  end
  if lower == "false" then
    return "true"
  end
  if lower == "null" or lower == "nil" or lower == "none" then
    return "value"
  end
  return nil
end

local function _mutate_number(trimmed, seed)
  if trimmed:match("^%-?%d+$") ~= nil then
    return tostring(tonumber(trimmed) + _signed_delta(seed, 9))
  end
  if trimmed:match("^%-?%d+%.%d+$") ~= nil then
    local delta = _signed_delta(seed, 9) / 10
    return tostring(tonumber(trimmed) + delta)
  end
  return nil
end

local function _mutate_datetime(trimmed, seed)
  local dt_year, dt_month, dt_day, dt_hour, dt_minute, dt_second, zulu = trimmed:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)[T ](%d%d):(%d%d):(%d%d)(Z?)$")
  if dt_year ~= nil then
    local date = _mutate_date(dt_year, dt_month, dt_day, seed)
    local time = _mutate_time(dt_hour, dt_minute, dt_second, seed)
    return date .. "T" .. time .. (zulu or "")
  end

  local year, month, day = trimmed:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
  if year ~= nil then
    return _mutate_date(year, month, day, seed)
  end

  local hour, minute, second = trimmed:match("^(%d%d):(%d%d):(%d%d)$")
  if hour ~= nil then
    return _mutate_time(hour, minute, second, seed)
  end
  hour, minute = trimmed:match("^(%d%d):(%d%d)$")
  if hour ~= nil then
    return _mutate_time(hour, minute, nil, seed)
  end
  return nil
end

function mutator.mutate_value(value, path)
  local original = tostring(value or "")
  local trimmed = _trim(original)
  local seed = _stable_hash(tostring(path or "") .. "\0" .. original)

  local mutated = _mutate_list_value(trimmed, seed, path)
  if mutated ~= nil then
    return mutated
  end

  mutated = _mutate_keyword(trimmed)
  if mutated ~= nil then
    return mutated
  end

  mutated = _mutate_number(trimmed, seed)
  if mutated ~= nil then
    return mutated
  end

  mutated = _mutate_datetime(trimmed, seed)
  if mutated ~= nil then
    return mutated
  end

  local duration = _mutate_duration(trimmed, seed)
  if duration ~= nil then
    return duration
  end

  return _dither_string(original, seed)
end

function mutator.build_mutations(ir)
  local mutations = {}
  for scenario_index, scenario in ipairs(ir.scenarios or {}) do
    for example_index, example in ipairs(scenario.examples or {}) do
      for _, key in ipairs(_sorted_keys(example)) do
        local path = "$.scenarios["
          .. tostring(scenario_index - 1)
          .. "].examples["
          .. tostring(example_index - 1)
          .. "]."
          .. tostring(key)
        local original = tostring(example[key] or "")
        local mutated = mutator.mutate_value(original, path)
        if mutated ~= original then
          local id = "m" .. tostring(#mutations + 1)
          mutations[#mutations + 1] = {
            id = id,
            path = path,
            description = path .. ": " .. original .. " -> " .. mutated,
            original = original,
            mutated = mutated,
            scenario_index = scenario_index,
            example_index = example_index,
            key = key,
          }
        end
      end
    end
  end
  return mutations
end

function mutator.apply_mutation(ir, mutation)
  local copy = _deep_copy(ir)
  copy.scenarios[mutation.scenario_index].examples[mutation.example_index][mutation.key] = mutation.mutated
  return copy
end

local function _write_mutation_ir(path, ir)
  local parent = common.parent_dir(path)
  local ok, err = common.ensure_dir(parent)
  if not ok then
    return nil, err
  end
  return common.write_file(path, json.encode(ir))
end

local function _result_for_error(mutation, message, duration)
  return {
    mutation = mutation,
    status = "error",
    output = "",
    error = tostring(message or "mutation infrastructure error"),
    duration = duration or 0,
  }
end

local function _run_one(base_ir, mutation, options)
  local start_time = os.clock()
  local mutation_dir = common.join_path(options.work_dir, mutation.id)
  local ir_path = common.join_path(mutation_dir, "feature.json")
  local generated_path = common.join_path(mutation_dir, "generated/feature_acceptance_spec.lua")
  local mutated_ir = mutator.apply_mutation(base_ir, mutation)

  local ok, err = _write_mutation_ir(ir_path, mutated_ir)
  if not ok then
    return _result_for_error(mutation, err, os.clock() - start_time)
  end

  ok, err = generator.generate_file(ir_path, generated_path)
  if not ok then
    return _result_for_error(mutation, err, os.clock() - start_time)
  end

  local run = runner.run_generated(generated_path)
  if run.error ~= "" then
    return _result_for_error(mutation, run.error, run.duration)
  end

  return {
    mutation = mutation,
    status = run.passed and "survived" or "killed",
    output = run.output,
    error = "",
    duration = run.duration,
  }
end

local function _summary(results)
  local summary = {
    total = #results,
    killed = 0,
    survived = 0,
    errors = 0,
  }
  for _, result in ipairs(results) do
    if result.status == "killed" then
      summary.killed = summary.killed + 1
    elseif result.status == "survived" then
      summary.survived = summary.survived + 1
    elseif result.status == "error" then
      summary.errors = summary.errors + 1
    end
  end
  return summary
end

function mutator.run(options)
  options = options or {}
  options.feature = options.feature or "features/a-feature.feature"
  options.work_dir = options.work_dir or "build/acceptance-mutation"
  options.workers = math.max(1, tonumber(options.workers or 1) or 1)

  local base_ir, err = gherkin_parser.parse_file(options.feature)
  if base_ir == nil then
    return nil, err
  end

  local ok
  ok, err = common.ensure_dir(options.work_dir)
  if not ok then
    return nil, err
  end

  local started_at = os.time()
  local mutations = mutator.build_mutations(base_ir)
  local results = {}
  for _, mutation in ipairs(mutations) do
    if options.timeout_seconds ~= nil and os.difftime(os.time(), started_at) >= options.timeout_seconds then
      results[#results + 1] = _result_for_error(mutation, "mutation run timed out", 0)
    else
      results[#results + 1] = _run_one(base_ir, mutation, options)
    end
  end

  local report = {
    summary = _summary(results),
    results = results,
  }
  return report
end

function mutator.format_text_report(report)
  local lines = {}
  local summary = report.summary
  lines[#lines + 1] = "total="
    .. tostring(summary.total)
    .. " killed="
    .. tostring(summary.killed)
    .. " survived="
    .. tostring(summary.survived)
    .. " errors="
    .. tostring(summary.errors)

  for _, result in ipairs(report.results or {}) do
    lines[#lines + 1] = string.format("%-8s %s", result.status, result.mutation.description)
    if result.status == "survived" or result.status == "error" then
      if result.error ~= "" then
        lines[#lines + 1] = "  error: " .. tostring(result.error)
      end
      if result.output ~= "" then
        lines[#lines + 1] = "  output:"
        lines[#lines + 1] = result.output
      end
    end
  end
  return table.concat(lines, "\n") .. "\n"
end

function mutator.format_json_report(report)
  local encoded = {
    summary = {
      Total = report.summary.total,
      Killed = report.summary.killed,
      Survived = report.summary.survived,
      Errors = report.summary.errors,
    },
    results = {},
  }

  for _, result in ipairs(report.results or {}) do
    encoded.results[#encoded.results + 1] = {
      Mutation = {
        ID = result.mutation.id,
        Path = result.mutation.path,
        Description = result.mutation.description,
        Original = result.mutation.original,
        Mutated = result.mutation.mutated,
      },
      Status = result.status,
      Output = result.output,
      Error = result.error,
      Duration = result.duration,
    }
  end

  return json.encode(encoded)
end

return mutator
