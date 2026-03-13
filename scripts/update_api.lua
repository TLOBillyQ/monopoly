local function _normalize_path(path)
  return tostring(path or ""):gsub("\\", "/")
end

local function _script_dir(script_path)
  local normalized = _normalize_path(script_path)
  return normalized:match("^(.*)/[^/]+$") or "scripts"
end

local _raw_script_path = arg and arg[0] or "scripts/update_api.lua"
local _entry_script_dir = _script_dir(_raw_script_path)
local _entry_parent_dir = _entry_script_dir:match("^(.*)/[^/]+$") or "."
package.path = _entry_script_dir .. "/?.lua;"
  .. _entry_script_dir .. "/?/?.lua;"
  .. _entry_parent_dir .. "/?.lua;"
  .. _entry_parent_dir .. "/?/?.lua;"
  .. package.path

local bootstrap = require("bootstrap")
local env = bootstrap.install(_raw_script_path)
local common = require("lib.common")

local function _text(zh, en)
  return common.bilingual(zh, en)
end

local function _fail(message)
  io.stderr:write(tostring(message), "\n")
  os.exit(1)
end

local DEFAULT_NEW = common.join_path(env.repo_root, "EggyAPI.lua")
local DEFAULT_OLD = common.join_path(env.repo_root, "EggyAPI copy.lua")
local DEFAULT_DOC_DIR = common.join_path(env.repo_root, "docs/eggy/api")
local DEFAULT_CHANGELOG = common.join_path(env.repo_root, "docs/eggy/api_changelog.md")

local function _trim(text)
  local source = tostring(text or "")
  source = source:gsub("^%s+", "")
  source = source:gsub("%s+$", "")
  return source
end

local function _split_lines(text)
  local lines = {}
  for line in (tostring(text or "") .. "\n"):gmatch("(.-)\n") do
    lines[#lines + 1] = line
  end
  return lines
end

local function _split_lines_keepends(text)
  local lines = {}
  local cursor = 1
  local source = tostring(text or "")
  local source_length = #source
  if source_length == 0 then
    return lines
  end

  while cursor <= source_length do
    local newline_index = source:find("\n", cursor, true)
    if newline_index == nil then
      lines[#lines + 1] = source:sub(cursor)
      break
    end
    lines[#lines + 1] = source:sub(cursor, newline_index)
    cursor = newline_index + 1
  end

  return lines
end

local function _remove_deprecated_api(lines)
  local output = {}
  local buffer = {}
  local deprecated_in_buffer = false

  for _, line in ipairs(lines or {}) do
    local stripped = line:gsub("^%s*", "")
    local is_doc = stripped:sub(1, 3) == "---"
    if is_doc then
      buffer[#buffer + 1] = line
      if line:find("@deprecated", 1, true) ~= nil then
        deprecated_in_buffer = true
      end
    else
      if deprecated_in_buffer then
        if line:match("^%s*$") == nil then
          buffer = {}
          deprecated_in_buffer = false
        end
      else
        if #buffer > 0 then
          for _, buffered_line in ipairs(buffer) do
            output[#output + 1] = buffered_line
          end
          buffer = {}
        end
        output[#output + 1] = line
      end
    end
  end

  if not deprecated_in_buffer and #buffer > 0 then
    for _, buffered_line in ipairs(buffer) do
      output[#output + 1] = buffered_line
    end
  end

  return output
end

local function _normalize_params(params, drop_empty)
  local source = _trim(params)
  if source == "" then
    return ""
  end
  local parts = {}
  for part in source:gmatch("[^,]+") do
    local normalized = _trim(part)
    if normalized ~= "" or not drop_empty then
      parts[#parts + 1] = normalized
    end
  end
  return table.concat(parts, ", ")
end

local function _class_base_name(raw)
  local normalized = _trim(raw):gsub("%(partial%)%s*", "")
  return _trim((normalized:match("^([^:]+)") or normalized))
end

local function _extract_class_block(text, class_name)
  local lines = _split_lines(text)
  local capture_index = nil
  local pattern = "^%-%-%-@class%s+" .. class_name:gsub("([^%w])", "%%%1") .. "%f[%W].*$"
  for index, line in ipairs(lines) do
    if line:match(pattern) ~= nil then
      capture_index = index
      break
    end
  end
  if capture_index == nil then
    return ""
  end

  local block = {}
  for index = capture_index, #lines do
    local line = lines[index]
    if index ~= capture_index then
      local is_next_marker = line:match("^%-%-%-@class%s+") ~= nil
        or line:match("^%-%-%-@alias%s+") ~= nil
        or line:match("^%-%-%-@enum%s+") ~= nil
        or line:match("^function%s+") ~= nil
      if is_next_marker then
        break
      end
    end
    block[#block + 1] = line
  end

  return _trim(table.concat(block, "\n"))
end

local function _load_functions(text)
  local entries = {}
  for _, line in ipairs(_split_lines(text)) do
    local name, params = line:match("^function%s+([^%(]+)%(([^)]*)%)%s*end%s*$")
    if name ~= nil then
      local module_name = _trim(name)
      local function_name = ""
      if module_name:find(":", 1, true) ~= nil then
        module_name, function_name = module_name:match("^([^:]+):(.+)$")
      elseif module_name:find(".", 1, true) ~= nil then
        module_name, function_name = module_name:match("^([^.]+)%.(.+)$")
      end
      entries[#entries + 1] = {
        module_name = module_name,
        function_name = function_name or "",
        params = _normalize_params(params),
      }
    end
  end
  return entries
end

local function _write_module_file(path, modules, by_module)
  local lines = {}
  for _, module_name in ipairs(modules or {}) do
    lines[#lines + 1] = "## " .. tostring(module_name)
    lines[#lines + 1] = ""
    for _, entry in ipairs(by_module[module_name] or {}) do
      lines[#lines + 1] = entry
    end
    lines[#lines + 1] = ""
  end
  local ok, err = common.write_file(path, table.concat(lines, "\n"))
  if not ok then
    _fail(err)
  end
end

local function _append_changelog(path, report_lines)
  local entry_lines = {
    "## " .. os.date("%Y-%m-%d"),
    "",
  }
  for _, line in ipairs(report_lines or {}) do
    entry_lines[#entry_lines + 1] = line
  end
  entry_lines[#entry_lines + 1] = ""
  local entry_text = table.concat(entry_lines, "\n")

  local content = nil
  if common.path_exists(path) then
    content = common.read_file(path)
    if content == nil then
      _fail(_text(
        "无法读取变更记录: " .. tostring(path),
        "Cannot read changelog: " .. tostring(path)
      ))
    end
    content = _trim(content)
    if content ~= "" then
      content = content .. "\n\n" .. entry_text .. "\n"
    else
      content = "# EggyAPI 变更记录\n\n" .. entry_text .. "\n"
    end
  else
    content = "# EggyAPI 变更记录\n\n" .. entry_text .. "\n"
  end

  local ok, err = common.write_file(path, content)
  if not ok then
    _fail(err)
  end
end

local function _iter_code_lines(text)
  local lines = {}
  local in_block_comment = false
  local line_no = 0

  for raw in (tostring(text or "") .. "\n"):gmatch("(.-)\n") do
    line_no = line_no + 1
    local line = raw

    if in_block_comment then
      local end_index = line:find("]]", 1, true)
      if end_index == nil then
        goto continue
      end
      line = line:sub(end_index + 2)
      in_block_comment = false
      if _trim(line) == "" then
        goto continue
      end
    end

    local stripped = line:gsub("^%s*", "")
    if stripped:sub(1, 4) == "--[[" then
      in_block_comment = true
      goto continue
    end
    if stripped:sub(1, 2) == "--" then
      goto continue
    end

    local comment_index = line:find("--", 1, true)
    if comment_index ~= nil then
      line = line:sub(1, comment_index - 1)
    end

    line = _trim(line)
    if line ~= "" then
      lines[#lines + 1] = {
        line_no = line_no,
        text = line,
      }
    end

    ::continue::
  end

  return lines
end

local function _parse_symbols(text)
  local symbols = {}
  for _, entry in ipairs(_iter_code_lines(text)) do
    local line = entry.text
    if line:match("^local%s+") == nil then
      local function_name, params = line:match("^function%s+([A-Za-z_][%w_%.:]*)%s*%(([^)]*)%)")
      if function_name ~= nil then
        symbols[function_name] = {
          kind = "function",
          params = _normalize_params(params, true),
          line = entry.line_no,
        }
      else
        local assigned_name, assigned_params = line:match("^([A-Za-z_][%w_%.]*)%s*=%s*function%s*%(([^)]*)%)")
        if assigned_name ~= nil then
          symbols[assigned_name] = {
            kind = "function",
            params = _normalize_params(assigned_params, true),
            line = entry.line_no,
          }
        else
          local field_name = line:match("^([A-Za-z_][%w_%.]*)%s*=")
          if field_name ~= nil then
            symbols[field_name] = {
              kind = "field",
              params = "",
              line = entry.line_no,
            }
          end
        end
      end
    end
  end
  return symbols
end

local function _parse_path(path)
  local text, err = common.read_file(path)
  if text == nil then
    _fail(err)
  end
  return _parse_symbols(text)
end

local function _format_list(title, items, limit)
  local lines = { title .. ": " .. tostring(#items) }
  if #items == 0 then
    return lines
  end

  local max_count = limit
  if max_count == nil or max_count <= 0 then
    max_count = #items
  end

  local upper_bound = math.min(#items, max_count)
  for index = 1, upper_bound do
    lines[#lines + 1] = "  - " .. tostring(items[index])
  end
  return lines
end

local function _format_changes(title, items, limit)
  local lines = { title .. ": " .. tostring(#items) }
  if #items == 0 then
    return lines
  end

  local max_count = limit
  if max_count == nil or max_count <= 0 then
    max_count = #items
  end

  local upper_bound = math.min(#items, max_count)
  for index = 1, upper_bound do
    local item = items[index]
    lines[#lines + 1] = "  - " .. tostring(item[1]) .. ": " .. tostring(item[2]) .. " -> " .. tostring(item[3])
  end
  return lines
end

local function _diff_symbols(old_symbols, new_symbols)
  local added = {}
  local removed = {}
  local changed_params = {}
  local type_changed = {}

  for name in pairs(new_symbols) do
    if old_symbols[name] == nil then
      added[#added + 1] = name
    end
  end
  for name in pairs(old_symbols) do
    if new_symbols[name] == nil then
      removed[#removed + 1] = name
    end
  end

  table.sort(added)
  table.sort(removed)

  for _, name in ipairs(common.sorted_keys(new_symbols)) do
    local old_symbol = old_symbols[name]
    local new_symbol = new_symbols[name]
    if old_symbol ~= nil and new_symbol ~= nil then
      if old_symbol.kind ~= new_symbol.kind then
        type_changed[#type_changed + 1] = { name, old_symbol.kind, new_symbol.kind }
      elseif old_symbol.kind == "function" and old_symbol.params ~= new_symbol.params then
        changed_params[#changed_params + 1] = { name, old_symbol.params, new_symbol.params }
      end
    end
  end

  return added, removed, changed_params, type_changed
end

local function _load_source_entries(text)
  local entries = {}
  for _, entry in ipairs(_load_functions(text)) do
    entries[#entries + 1] = table.concat({
      entry.module_name,
      entry.function_name,
      entry.params,
    }, "|"):gsub("|$", "")
  end
  table.sort(entries)

  local set = {}
  for _, value in ipairs(entries) do
    set[value] = true
  end
  return set
end

local function _collect_markdown_files(doc_dir)
  local paths, err = common.collect_files(doc_dir, ".md")
  if paths == nil then
    return {}
  end
  return paths
end

local function _load_doc_entries(doc_dir)
  local set = {}
  for _, path in ipairs(_collect_markdown_files(doc_dir)) do
    local text = common.read_file(path)
    if text ~= nil then
      for _, line in ipairs(_split_lines(text)) do
        local normalized = _trim(line)
        if normalized ~= "" and normalized:find("|", 1, true) ~= nil and normalized:sub(1, 1) ~= "#" then
          set[normalized] = true
        end
      end
    end
  end
  return set
end

local function _set_to_sorted_list(values)
  local list = {}
  for value in pairs(values or {}) do
    list[#list + 1] = value
  end
  table.sort(list)
  return list
end

local function _build_check_report(source_entries, doc_entries)
  local missing = {}
  local extra = {}

  for value in pairs(source_entries) do
    if not doc_entries[value] then
      missing[#missing + 1] = value
    end
  end
  for value in pairs(doc_entries) do
    if not source_entries[value] then
      extra[#extra + 1] = value
    end
  end

  table.sort(missing)
  table.sort(extra)

  local lines = {
    _text("源码条目数", "Source count") .. ": " .. tostring(#_set_to_sorted_list(source_entries)),
    _text("拆分文档条目数", "Split docs count") .. ": " .. tostring(#_set_to_sorted_list(doc_entries)),
    _text("缺失项", "Missing") .. ": " .. tostring(#missing),
    _text("多余项", "Extra") .. ": " .. tostring(#extra),
  }
  if #missing > 0 then
    local sample = {}
    local upper_bound = math.min(#missing, 10)
    for index = 1, upper_bound do
      sample[#sample + 1] = missing[index]
    end
    lines[#lines + 1] = _text("缺失示例", "Missing sample") .. ": [" .. table.concat(sample, ", ") .. "]"
  end
  if #extra > 0 then
    local sample = {}
    local upper_bound = math.min(#extra, 10)
    for index = 1, upper_bound do
      sample[#sample + 1] = extra[index]
    end
    lines[#lines + 1] = _text("多余示例", "Extra sample") .. ": [" .. table.concat(sample, ", ") .. "]"
  end
  return lines, missing, extra
end

local function _format_diff_report(added, removed, changed_params, type_changed, limit)
  local lines = {}
  for _, line in ipairs(_format_list(_text("新增", "Added"), added, limit)) do
    lines[#lines + 1] = line
  end
  for _, line in ipairs(_format_list(_text("删除", "Removed"), removed, limit)) do
    lines[#lines + 1] = line
  end
  for _, line in ipairs(_format_changes(_text("签名变更", "Signature changed"), changed_params, limit)) do
    lines[#lines + 1] = line
  end
  for _, line in ipairs(_format_changes(_text("类型变更", "Type changed"), type_changed, limit)) do
    lines[#lines + 1] = line
  end
  return lines
end

local function _print_lines(lines)
  for _, line in ipairs(lines or {}) do
    print(line)
  end
end

local function _parse_args(args)
  local options = {
    old = DEFAULT_OLD,
    new = DEFAULT_NEW,
    doc_dir = DEFAULT_DOC_DIR,
    changelog = DEFAULT_CHANGELOG,
    limit = 50,
    skip_generate = false,
    skip_check = false,
    skip_diff = false,
  }

  local index = 1
  while index <= #args do
    local token = args[index]
    if token == "--old" then
      options.old = args[index + 1]
      index = index + 2
    elseif token == "--new" then
      options.new = args[index + 1]
      index = index + 2
    elseif token == "--doc-dir" then
      options.doc_dir = args[index + 1]
      index = index + 2
    elseif token == "--changelog" then
      options.changelog = args[index + 1]
      index = index + 2
    elseif token == "--limit" then
      local parsed = common.to_integer(args[index + 1])
      if parsed == nil then
        _fail(_text(
          "无效的 --limit 参数: " .. tostring(args[index + 1]),
          "Invalid --limit value: " .. tostring(args[index + 1])
        ))
      end
      options.limit = parsed
      index = index + 2
    elseif token == "--skip-generate" then
      options.skip_generate = true
      index = index + 1
    elseif token == "--skip-check" then
      options.skip_check = true
      index = index + 1
    elseif token == "--skip-diff" then
      options.skip_diff = true
      index = index + 1
    elseif token == "--help" or token == "-h" then
      print(_text(
        "用法: lua scripts/update_api.lua [--old PATH] [--new PATH] [--doc-dir PATH] [--changelog PATH] [--limit NUM] [--skip-generate] [--skip-check] [--skip-diff]",
        "Usage: lua scripts/update_api.lua [--old PATH] [--new PATH] [--doc-dir PATH] [--changelog PATH] [--limit NUM] [--skip-generate] [--skip-check] [--skip-diff]"
      ))
      os.exit(0)
    else
      _fail(_text(
        "未知参数: " .. tostring(token),
        "Unknown flag: " .. tostring(token)
      ))
    end
  end

  options.old = common.resolve_path(common.current_dir(), options.old)
  options.new = common.resolve_path(common.current_dir(), options.new)
  options.doc_dir = common.resolve_path(common.current_dir(), options.doc_dir)
  options.changelog = common.resolve_path(common.current_dir(), options.changelog)

  return options
end

local function _validate_file(path, label)
  if not common.path_exists(path) then
    _fail(_text(
      label .. " 文件不存在: " .. tostring(path),
      label .. " file does not exist: " .. tostring(path)
    ))
  end
end

local function _write_text(path, text)
  local ok, err = common.write_file(path, text)
  if not ok then
    _fail(err)
  end
end

local function _cleanup_deprecated_api(path)
  _validate_file(path, "new")

  local original, read_err = common.read_file(path)
  if original == nil then
    _fail(read_err)
  end

  local updated = table.concat(_remove_deprecated_api(_split_lines_keepends(original)))
  _write_text(path, updated)
end

local function _delete_old_api(path)
  if not common.path_exists(path) then
    return
  end

  local ok = common.remove_path(path)
  if not ok then
    _fail(_text(
      "无法删除旧文件: " .. tostring(path),
      "Cannot delete old file: " .. tostring(path)
    ))
  end
end

local function _generate_docs(text, options)
  local ensure_ok, ensure_err = common.ensure_dir(options.doc_dir)
  if not ensure_ok then
    _fail(ensure_err)
  end

  local entries = _load_functions(text)
  local module_set = {}
  for _, entry in ipairs(entries) do
    module_set[entry.module_name] = true
  end
  local modules = _set_to_sorted_list(module_set)

  local basic_types = {
    Vector3 = true,
    Quaternion = true,
    dict = true,
    math = true,
  }
  local api_modules = {
    GlobalAPI = true,
    GameAPI = true,
    LuaAPI = true,
  }
  local component_modules = {}
  for _, module_name in ipairs(modules) do
    if module_name:match("Comp$") ~= nil then
      component_modules[#component_modules + 1] = module_name
    end
  end
  table.sort(component_modules)

  local class_names = {}
  local class_set = {}
  for _, line in ipairs(_split_lines(text)) do
    local class_name = line:match("^%-%-%-@class%s+(.+)%s*$")
    if class_name ~= nil then
      local base_name = _class_base_name(class_name)
      class_names[#class_names + 1] = base_name
      class_set[base_name] = true
    end
  end

  local component_set = {}
  for _, module_name in ipairs(component_modules) do
    component_set[module_name] = true
  end

  local entity_modules = {}
  for _, module_name in ipairs(modules) do
    if class_set[module_name]
      and not basic_types[module_name]
      and not api_modules[module_name]
      and not component_set[module_name]
      and module_name ~= "EVENT"
      and module_name ~= "Enums"
      and module_name ~= "Damage"
      and module_name ~= "Timer"
      and module_name ~= "GoodsInfo"
    then
      entity_modules[#entity_modules + 1] = module_name
    end
  end
  table.sort(entity_modules)

  local by_module = {}
  for _, entry in ipairs(entries) do
    local line = table.concat({
      entry.module_name,
      entry.function_name,
      entry.params,
    }, "|"):gsub("|$", "")
    by_module[entry.module_name] = by_module[entry.module_name] or {}
    by_module[entry.module_name][#by_module[entry.module_name] + 1] = line
  end

  local index_lines = {
    "# EggyAPI 拆分索引",
    "",
    "本目录用于按功能拆分 `EggyAPI.lua`，加速查询并保证 API 完整性。",
    "",
    "## 目录",
    "",
    "- 01_types.md：基础类型与方法清单（Vector3/Quaternion/dict/math）。",
    "- 02_aliases.md：类型别名清单（`---@alias`）。",
    "- 03_enums.md：枚举清单（`---@enum`）。",
    "- 04_global_api.md：GlobalAPI 方法索引。",
    "- 05_game_api.md：GameAPI 方法索引。",
    "- 06_lua_api.md：LuaAPI 方法索引。",
    "- 07_unit_entities.md：实体类方法索引（Unit/Role/Ability 等）。",
    "- 08_components.md：组件类方法索引（*Comp）。",
    "- 09_events.md：事件常量与示例。",
    "",
    "校验方式：运行 `lua scripts/update_api.lua`，默认包含校验。",
    "",
  }
  _write_text(common.join_path(options.doc_dir, "00_index.md"), table.concat(index_lines, "\n"))

  local basic_class_markers = { "Vector3", "Quaternion", "dict", "(partial) math" }
  local type_lines = { "# 基础类型", "" }
  for _, marker in ipairs(basic_class_markers) do
    local block = _extract_class_block(text, marker)
    if block ~= "" then
      type_lines[#type_lines + 1] = block
      type_lines[#type_lines + 1] = ""
    end
  end
  type_lines[#type_lines + 1] = "## 方法清单"
  type_lines[#type_lines + 1] = ""
  for _, entry in ipairs(entries) do
    if basic_types[entry.module_name] then
      type_lines[#type_lines + 1] = table.concat({ entry.module_name, entry.function_name, entry.params }, "|"):gsub("|$", "")
    end
  end
  type_lines[#type_lines + 1] = ""
  type_lines[#type_lines + 1] = "## 其他类型"
  type_lines[#type_lines + 1] = ""
  for _, line in ipairs(_split_lines(text)) do
    local class_name = line:match("^%-%-%-@class%s+(.+)%s*$")
    if class_name ~= nil then
      local raw = _trim(class_name)
      local base = _class_base_name(raw)
      if raw:sub(1, 5) ~= "EVENT" and not basic_types[base] then
        type_lines[#type_lines + 1] = "- " .. raw
      end
    end
  end
  type_lines[#type_lines + 1] = ""
  _write_text(common.join_path(options.doc_dir, "01_types.md"), table.concat(type_lines, "\n"))

  local alias_lines = { "# 类型别名", "" }
  for _, line in ipairs(_split_lines(text)) do
    local alias = line:match("^%-%-%-@alias%s+(.+)%s*$")
    if alias ~= nil and _trim(alias) ~= "" then
      alias_lines[#alias_lines + 1] = _trim(alias)
    end
  end
  alias_lines[#alias_lines + 1] = ""
  _write_text(common.join_path(options.doc_dir, "02_aliases.md"), table.concat(alias_lines, "\n"))

  local enum_lines = { "# 枚举清单", "" }
  for _, line in ipairs(_split_lines(text)) do
    local enum_name = line:match("^%-%-%-@enum%s+(.+)%s*$")
    if enum_name ~= nil and _trim(enum_name) ~= "" then
      enum_lines[#enum_lines + 1] = _trim(enum_name)
    end
  end
  enum_lines[#enum_lines + 1] = ""
  _write_text(common.join_path(options.doc_dir, "03_enums.md"), table.concat(enum_lines, "\n"))

  _write_module_file(common.join_path(options.doc_dir, "04_global_api.md"), { "GlobalAPI" }, by_module)
  _write_module_file(common.join_path(options.doc_dir, "05_game_api.md"), { "GameAPI" }, by_module)
  _write_module_file(common.join_path(options.doc_dir, "06_lua_api.md"), { "LuaAPI" }, by_module)
  _write_module_file(common.join_path(options.doc_dir, "07_unit_entities.md"), entity_modules, by_module)
  _write_module_file(common.join_path(options.doc_dir, "08_components.md"), component_modules, by_module)

  local event_lines = {}
  local capture = false
  for _, line in ipairs(_split_lines(text)) do
    if not capture and line:match("^%-%-%-@class%s+EVENT") ~= nil then
      capture = true
    end
    if capture then
      event_lines[#event_lines + 1] = line
    end
  end
  if #event_lines > 0 then
    _write_text(common.join_path(options.doc_dir, "09_events.md"), table.concat({ "# 事件常量", "", _trim(table.concat(event_lines, "\n")), "" }, "\n"))
  end
end

local function main(args)
  local options = _parse_args(args or {})
  _cleanup_deprecated_api(options.new)

  local text = ""
  if not options.skip_generate or not options.skip_check then
    local read_text, read_err = common.read_file(options.new)
    if read_text == nil then
      _fail(read_err)
    end
    text = read_text
  end

  if not options.skip_generate then
    _generate_docs(text, options)
  end

  local diff_failed = false
  if not options.skip_diff then
    _validate_file(options.old, "old")
    local old_symbols = _parse_path(options.old)
    local new_symbols = _parse_path(options.new)
    local added, removed, changed_params, type_changed = _diff_symbols(old_symbols, new_symbols)
    local diff_lines = _format_diff_report(added, removed, changed_params, type_changed, options.limit)
    _print_lines(diff_lines)
    _append_changelog(options.changelog, _format_diff_report(added, removed, changed_params, type_changed, nil))
    diff_failed = #added > 0 or #removed > 0 or #changed_params > 0 or #type_changed > 0
  end

  local check_failed = false
  if not options.skip_check then
    local source_entries = _load_source_entries(text)
    local doc_entries = _load_doc_entries(options.doc_dir)
    local check_lines, missing, extra = _build_check_report(source_entries, doc_entries)
    if not options.skip_diff then
      print("")
    end
    _print_lines(check_lines)
    check_failed = #missing > 0 or #extra > 0
  end

  if diff_failed or check_failed then
    return 1
  end

  if not options.skip_generate then
    _delete_old_api(options.old)
  end

  return 0
end

os.exit(main(arg or {}))
