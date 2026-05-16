local common = require("shared.lib.common")
local chinese_normalizer = require("acceptance.chinese_normalizer")
local json = require("acceptance.json")

local gherkin_parser = {}

local function _trim(text)
  return tostring(text or ""):match("^%s*(.-)%s*$")
end

local function _parameters(text)
  local values = {}
  for name in tostring(text or ""):gmatch("<([A-Za-z0-9_]+)>") do
    values[#values + 1] = name
  end
  return values
end

local function _split_example_row(line)
  local row = _trim(line)
  if row:sub(1, 1) == "|" then
    row = row:sub(2)
  end
  if row:sub(-1) == "|" then
    row = row:sub(1, -2)
  end

  local cells = {}
  local start_index = 1
  while true do
    local hit = row:find("|", start_index, true)
    if hit == nil then
      cells[#cells + 1] = _trim(row:sub(start_index))
      break
    end
    cells[#cells + 1] = _trim(row:sub(start_index, hit - 1))
    start_index = hit + 1
  end
  return cells
end

local function _source_line(source_map, line_number)
  local lines = (source_map or {}).line_by_normalized_line or {}
  return lines[line_number] or line_number
end

local function _source_path(source_map)
  return (source_map or {}).path
end

local function _format_error(line_number, message, opts)
  opts = opts or {}
  local source_map = opts.source_map or {}
  local source_line = _source_line(source_map, line_number)
  local path = _source_path(source_map)
  local prefix = path and (tostring(path) .. ":") or ""
  return prefix .. "第" .. tostring(source_line) .. "行: " .. tostring(message)
end

local function _step(keyword, text, line_number, source_map)
  return {
    keyword = keyword,
    text = _trim(text),
    parameters = _parameters(text),
    metadata = {
      source_path = _source_path(source_map),
      source_line = _source_line(source_map, line_number),
      original_text = ((source_map or {}).original_step_text_by_line or {})[_source_line(source_map, line_number)],
    },
  }
end

local function _error(line_number, message, opts)
  return nil, _format_error(line_number, message, opts)
end

local function _example_header_message(source_map, header_line_number, base_message)
  local source_header_line = _source_line(source_map, header_line_number)
  local headers = ((source_map or {}).example_headers_by_line or {})[source_header_line]
  if headers == nil or #headers == 0 then
    return base_message
  end
  return base_message .. "；字段: " .. table.concat(headers, ", ")
end

function gherkin_parser.parse_text(text, opts)
  opts = opts or {}
  local source_map = opts.source_map or {}
  local feature = nil
  local current_scenario = nil
  local section = nil
  local example_headers = nil
  local example_header_line_number = nil
  local has_background = false
  local line_number = 0

  for raw_line in (tostring(text or "") .. "\n"):gmatch("(.-)\n") do
    line_number = line_number + 1
    local line = _trim(raw_line)

    if line == "" or line:sub(1, 1) == "#" then
      goto continue
    end

    local feature_name = line:match("^Feature:%s*(.+)$")
    if feature_name ~= nil then
      if feature ~= nil then
        return _error(line_number, "multiple feature declarations are not supported", opts)
      end
      feature = {
        name = _trim(feature_name),
        background = {},
        scenarios = {},
        metadata = {
          source_path = _source_path(source_map),
          language = source_map.language or "aps",
          field_names = source_map.field_names or {},
          field_lines = source_map.field_lines or {},
        },
      }
      current_scenario = nil
      section = nil
      goto continue
    end

    if feature == nil then
      return _error(line_number, "missing feature declaration", opts)
    end

    if line == "Background:" then
      if has_background then
        return _error(line_number, "multiple background sections are not supported", opts)
      end
      has_background = true
      current_scenario = nil
      section = "background"
      goto continue
    end

    local outline_name = line:match("^Scenario Outline:%s*(.+)$")
    local scenario_name = outline_name or line:match("^Scenario:%s*(.+)$")
    if scenario_name ~= nil then
      current_scenario = {
        name = _trim(scenario_name),
        steps = {},
        examples = {},
        metadata = {
          source_path = _source_path(source_map),
          source_line = _source_line(source_map, line_number),
          example_field_lines = {},
        },
      }
      feature.scenarios[#feature.scenarios + 1] = current_scenario
      section = "scenario"
      example_headers = nil
      example_header_line_number = nil
      goto continue
    end

    if line == "Examples:" then
      if current_scenario == nil then
        return _error(line_number, "examples section outside scenario", opts)
      end
      current_scenario.examples = {}
      section = "examples"
      example_headers = nil
      example_header_line_number = nil
      goto continue
    end

    if section == "examples" and line:sub(1, 1) == "|" then
      local cells = _split_example_row(line)
      if example_headers == nil then
        example_headers = cells
        example_header_line_number = line_number
        local source_header_line = _source_line(source_map, line_number)
        current_scenario.metadata.example_field_lines =
          ((source_map.header_field_lines_by_line or {})[source_header_line]) or {}
      else
        if #cells ~= #example_headers then
          local message = _example_header_message(
            source_map,
            example_header_line_number,
            "examples row has " .. tostring(#cells) .. " cells, expected " .. tostring(#example_headers)
          )
          return _error(line_number, message, opts)
        end
        local example = {}
        for index, header in ipairs(example_headers) do
          example[header] = cells[index]
        end
        current_scenario.examples[#current_scenario.examples + 1] = example
      end
      goto continue
    end

    local keyword, step_text = line:match("^(Given)%s+(.+)$")
    if keyword == nil then
      keyword, step_text = line:match("^(When)%s+(.+)$")
    end
    if keyword == nil then
      keyword, step_text = line:match("^(Then)%s+(.+)$")
    end
    if keyword == nil then
      keyword, step_text = line:match("^(And)%s+(.+)$")
    end
    if keyword ~= nil then
      if section == "background" then
        feature.background[#feature.background + 1] = _step(keyword, step_text, line_number, source_map)
      elseif current_scenario ~= nil then
        current_scenario.steps[#current_scenario.steps + 1] = _step(keyword, step_text, line_number, source_map)
        section = "scenario"
      else
        return _error(line_number, "step outside background or scenario", opts)
      end
    end

    ::continue::
  end

  if feature == nil then
    return nil, "missing feature declaration"
  end

  return feature
end

function gherkin_parser.parse_file(path)
  local content, err = common.read_file(path)
  if content == nil then
    return nil, err
  end
  local normalized
  normalized, err = chinese_normalizer.normalize_text(content, {
    path = path,
  })
  if normalized == nil then
    return nil, err
  end
  return gherkin_parser.parse_text(normalized.text, {
    source_map = normalized.source_map,
  })
end

function gherkin_parser.write_json_file(feature_path, output_path)
  local ir, err = gherkin_parser.parse_file(feature_path)
  if ir == nil then
    return nil, err
  end

  local parent = common.parent_dir(output_path)
  local ok
  ok, err = common.ensure_dir(parent)
  if not ok then
    return nil, err
  end
  ok, err = common.write_file(output_path, json.encode(ir))
  if not ok then
    return nil, err
  end
  return true
end

return gherkin_parser
