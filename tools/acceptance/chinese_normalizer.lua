local source = require("acceptance.source")

local chinese_normalizer = {}

local _trim = source.trim

local function _split_lines(text)
  local lines = {}
  for line in (tostring(text or "") .. "\n"):gmatch("(.-)\n") do
    lines[#lines + 1] = line
  end
  return lines
end

local function _is_features_path(path)
  local normalized = tostring(path or ""):gsub("\\", "/")
  return normalized:find("/features/", 1, true) ~= nil or normalized:match("^features/") ~= nil
end

local function _english_keyword(line)
  local keyword = line:match("^(Feature):")
    or line:match("^(Background):")
    or line:match("^(Scenario Outline):")
    or line:match("^(Scenario):")
    or line:match("^(Examples):")
    or line:match("^(Given)%s+")
    or line:match("^(When)%s+")
    or line:match("^(Then)%s+")
    or line:match("^(And)%s+")
  return keyword
end

local function _unsupported_chinese_keyword(line)
  return line:match("^(假设)%s+")
    or line:match("^(假定)%s+")
    or line:match("^(剧本):")
end

local function _make_context(path)
  local context = {
    path = path,
    language = "zh-CN",
    line_by_normalized_line = {},
    field_names = {},
    field_lines = {},
    example_headers_by_line = {},
    header_field_lines_by_line = {},
    original_step_text_by_line = {},
    _canonical_by_original = {},
    _next_parameter_index = 1,
  }

  function context.map_name(original, line_number)
    local source_name = _trim(original)
    local existing = context._canonical_by_original[source_name]
    if existing ~= nil then
      if context.field_lines[existing] == nil then
        context.field_lines[existing] = line_number
      end
      return existing
    end

    local canonical = "p" .. tostring(context._next_parameter_index)
    context._next_parameter_index = context._next_parameter_index + 1
    context._canonical_by_original[source_name] = canonical
    context.field_names[canonical] = source_name
    context.field_lines[canonical] = line_number
    return canonical
  end

  return context
end

local function _normalize_parameters(text, context, line_number)
  return tostring(text or ""):gsub("<([^<>]+)>", function(name)
    return "<" .. context.map_name(name, line_number) .. ">"
  end)
end

local function _normalize_header(line, context, line_number)
  local cells = source.split_table_cells(line)
  local mapped_cells = {}
  local field_lines = {}

  for _, cell in ipairs(cells) do
    if cell == "" then
      return nil, source.format_error(context.path, line_number, "例子表头不能为空")
    end
    local canonical = context.map_name(cell, line_number)
    mapped_cells[#mapped_cells + 1] = canonical
    field_lines[canonical] = line_number
  end

  context.example_headers_by_line[line_number] = cells
  context.header_field_lines_by_line[line_number] = field_lines
  return "| " .. table.concat(mapped_cells, " | ") .. " |"
end

local function _normalize_structure(line)
  local feature_name = line:match("^功能:%s*(.+)$")
  if feature_name ~= nil then
    return "Feature: " .. _trim(feature_name), "feature"
  end

  if line == "背景:" then
    return "Background:", "background"
  end

  local outline_name = line:match("^场景大纲:%s*(.+)$")
  if outline_name ~= nil then
    return "Scenario Outline: " .. _trim(outline_name), "scenario"
  end

  local scenario_name = line:match("^场景:%s*(.+)$")
  if scenario_name ~= nil then
    return "Scenario: " .. _trim(scenario_name), "scenario"
  end

  if line == "例子:" then
    return "Examples:", "examples"
  end

  return nil
end

local STEP_KEYWORDS = {
  ["假如"] = "Given",
  ["当"] = "When",
  ["那么"] = "Then",
  ["并且"] = "And",
  ["但是"] = "And",
}

local function _normalize_step(line, context, line_number)
  local keyword, rest = line:match("^(%S+)%s+(.+)$")
  local aps_keyword = STEP_KEYWORDS[keyword]
  if aps_keyword == nil then
    return nil
  end

  local normalized_text = _normalize_parameters(rest, context, line_number)
  context.original_step_text_by_line[line_number] = rest
  return aps_keyword .. " " .. normalized_text
end

local function _normalize_chinese_lines(lines, context)
  local output = {}
  local section = nil
  local waiting_for_header = false

  for line_number, raw_line in ipairs(lines) do
    local line = _trim(raw_line)
    local indent = raw_line:match("^(%s*)") or ""
    context.line_by_normalized_line[line_number] = line_number

    if line == "" or line:sub(1, 1) == "#" then
      output[#output + 1] = raw_line
      goto continue
    end

    local english = _english_keyword(line)
    if english ~= nil then
      return nil, source.format_error(context.path, line_number, "业务源文件不能使用英文结构关键字 " .. english)
    end

    local unsupported = _unsupported_chinese_keyword(line)
    if unsupported ~= nil then
      return nil, source.format_error(context.path, line_number, "不支持的中文关键字 " .. unsupported)
    end

    if section == "examples" and waiting_for_header and line:sub(1, 1) == "|" then
      local normalized_header, err = _normalize_header(line, context, line_number)
      if normalized_header == nil then
        return nil, err
      end
      output[#output + 1] = indent .. normalized_header
      waiting_for_header = false
      goto continue
    end

    local normalized, next_section = _normalize_structure(line)
    if normalized ~= nil then
      output[#output + 1] = indent .. normalized
      section = next_section
      waiting_for_header = next_section == "examples"
      goto continue
    end

    normalized = _normalize_step(line, context, line_number)
    if normalized ~= nil then
      output[#output + 1] = indent .. normalized
      goto continue
    end

    output[#output + 1] = raw_line

    ::continue::
  end

  return table.concat(output, "\n")
end

function chinese_normalizer.normalize_text(text, opts)
  opts = opts or {}
  local lines = _split_lines(text)
  local first_line = lines[1] or ""
  local path = opts.path
  local is_chinese = _trim(first_line) == "# language: zh-CN"

  if _is_features_path(path) and not is_chinese then
    return nil, source.format_error(path, 1, "features/ 下的业务源文件首行必须是 # language: zh-CN")
  end

  if not is_chinese then
    return {
      text = tostring(text or ""),
      source_map = {
        path = path,
        language = "aps",
        line_by_normalized_line = {},
        field_names = {},
        field_lines = {},
      },
    }
  end

  local context = _make_context(path)
  local normalized, err = _normalize_chinese_lines(lines, context)
  if normalized == nil then
    return nil, err
  end

  context._canonical_by_original = nil
  context._next_parameter_index = nil
  return {
    text = normalized,
    source_map = context,
  }
end

return chinese_normalizer
