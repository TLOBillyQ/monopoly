local common = require("lib.common")

local xlsx_reader = {}

local function _trim(text)
  local source = tostring(text or "")
  source = source:gsub("^%s+", "")
  source = source:gsub("%s+$", "")
  return source
end

local function _xml_unescape(text)
  local value = tostring(text or "")
  value = value:gsub("&#x([0-9A-Fa-f]+);", function(hex)
    local numeric = common.to_integer("0")
    numeric = numeric and numeric or 0
    local source = tostring(hex or "")
    for index = 1, #source do
      local byte = source:byte(index)
      local digit = 0
      if byte >= 48 and byte <= 57 then
        digit = byte - 48
      elseif byte >= 65 and byte <= 70 then
        digit = byte - 55
      elseif byte >= 97 and byte <= 102 then
        digit = byte - 87
      end
      numeric = numeric * 16 + digit
    end
    if utf8 and utf8.char then
      local ok, char = pcall(utf8.char, numeric)
      if ok and char ~= nil then
        return char
      end
    end
    return ""
  end)
  value = value:gsub("&#([0-9]+);", function(decimal)
    local numeric = common.to_integer(decimal)
    if numeric ~= nil and utf8 and utf8.char then
      local ok, char = pcall(utf8.char, numeric)
      if ok and char ~= nil then
        return char
      end
    end
    return ""
  end)
  value = value:gsub("&lt;", "<")
  value = value:gsub("&gt;", ">")
  value = value:gsub("&quot;", '"')
  value = value:gsub("&apos;", "'")
  value = value:gsub("&amp;", "&")
  return value
end

local function _get_attr(tag, attr_name)
  local escaped_name = tostring(attr_name or ""):gsub("([^%w_:])", "%%%1")
  local value = tag:match(escaped_name .. '%s*=%s*"([^"]*)"')
  if value ~= nil then
    return _xml_unescape(value)
  end
  value = tag:match(escaped_name .. "%s*=%s*'([^']*)'")
  if value ~= nil then
    return _xml_unescape(value)
  end
  return nil
end

local function _command_exists(name)
  local result = common.run_command("command -v " .. tostring(name))
  return result.ok and _trim(result.output) ~= ""
end

local function _read_zip_entry(path, entry_name)
  if not _command_exists("unzip") then
    return nil, "missing required command: unzip"
  end
  local result = common.run_command({ "unzip", "-p", path, entry_name })
  if not result.ok then
    return nil, _trim(result.output) ~= "" and _trim(result.output) or ("failed to read zip entry: " .. tostring(entry_name))
  end
  return result.output
end

local function _load_shared_strings(path)
  local xml, err = _read_zip_entry(path, "xl/sharedStrings.xml")
  if xml == nil then
    return {}
  end
  local values = {}
  for si_xml in xml:gmatch("<si[^>]*>.-</si>") do
    local parts = {}
    for text_value in si_xml:gmatch("<t[^>]*>(.-)</t>") do
      parts[#parts + 1] = _xml_unescape(text_value)
    end
    values[#values + 1] = table.concat(parts)
  end
  return values
end

local function _extract_cells(row_xml)
  local cells = {}
  local cursor = 1
  local source = tostring(row_xml or "")
  while true do
    local start_index = source:find("<c", cursor, true)
    if start_index == nil then
      break
    end
    local open_end = source:find(">", start_index, true)
    if open_end == nil then
      break
    end
    local open_tag = source:sub(start_index, open_end)
    if open_tag:sub(-2) == "/>" then
      cells[#cells + 1] = open_tag
      cursor = open_end + 1
    else
      local close_start, close_end = source:find("</c>", open_end + 1, true)
      if close_end == nil then
        break
      end
      cells[#cells + 1] = source:sub(start_index, close_end)
      cursor = close_end + 1
    end
  end
  return cells
end

local function _sheet_map(path)
  local workbook_xml, workbook_err = _read_zip_entry(path, "xl/workbook.xml")
  if workbook_xml == nil then
    return nil, workbook_err
  end
  local rels_xml, rels_err = _read_zip_entry(path, "xl/_rels/workbook.xml.rels")
  if rels_xml == nil then
    return nil, rels_err
  end

  local rid_to_target = {}
  for relationship_tag in rels_xml:gmatch("<Relationship[^>]*/>") do
    local relationship_id = _get_attr(relationship_tag, "Id")
    local target = _get_attr(relationship_tag, "Target")
    if relationship_id ~= nil and target ~= nil then
      rid_to_target[relationship_id] = target
    end
  end

  local sheets = {}
  for sheet_tag in workbook_xml:gmatch("<sheet[^>]*/>") do
    local name = _get_attr(sheet_tag, "name")
    local relationship_id = _get_attr(sheet_tag, "r:id")
    local target = relationship_id and rid_to_target[relationship_id] or nil
    sheets[#sheets + 1] = {
      name = name,
      path = target and ("xl/" .. target) or nil,
    }
  end

  return sheets
end

local function _cell_value(cell_xml, shared_strings)
  local cell_tag = cell_xml:match("^<c([^>]*)>")
  local cell_attrs = cell_tag and ("<c" .. cell_tag .. ">") or ""
  local value_type = _get_attr(cell_attrs, "t")
  local inline_value = cell_xml:match("<is[^>]*>.-<t[^>]*>(.-)</t>.-</is>")
  if inline_value ~= nil then
    return _xml_unescape(inline_value)
  end

  local value = cell_xml:match("<v[^>]*>(.-)</v>")
  if value == nil then
    return nil
  end
  value = _xml_unescape(value)
  if value_type == "s" then
    local index = common.to_integer(value)
    if index ~= nil then
      return shared_strings[index + 1] or value
    end
  end
  return value
end

function xlsx_reader.read_sheet_rows(path, sheet_index)
  local resolved_sheet_index = sheet_index or 1
  local sheets, sheet_err = _sheet_map(path)
  if sheets == nil then
    return nil, sheet_err
  end
  local selected_sheet = sheets[resolved_sheet_index]
  if selected_sheet == nil or selected_sheet.path == nil then
    return {}, nil
  end

  local sheet_xml, xml_err = _read_zip_entry(path, selected_sheet.path)
  if sheet_xml == nil then
    return nil, xml_err
  end

  local shared_strings = _load_shared_strings(path)
  local rows = {}
  for row_xml in sheet_xml:gmatch("<row[^>]*>.-</row>") do
    local cells = {}
    for _, cell_xml in ipairs(_extract_cells(row_xml)) do
      local cell_tag = cell_xml:match("^<c[^>]*>") or ""
      local ref = _get_attr(cell_tag, "r")
      local column = ref and ref:match("([A-Z]+)") or nil
      if column ~= nil then
        cells[column] = _cell_value(cell_xml, shared_strings)
      end
    end
    rows[#rows + 1] = cells
  end
  return rows, nil
end

return xlsx_reader
