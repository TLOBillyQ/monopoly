local common = {}

local function _sorted_pairs(map)
  local keys = {}
  for key in pairs(map or {}) do
    keys[#keys + 1] = key
  end
  table.sort(keys)
  local index = 0
  return function()
    index = index + 1
    local key = keys[index]
    if key == nil then
      return nil
    end
    return key, map[key]
  end
end

function common.sorted_pairs(map)
  return _sorted_pairs(map)
end

function common.is_windows()
  return package.config:sub(1, 1) == "\\"
end

function common.normalize_path(path)
  return tostring(path or ""):gsub("\\", "/")
end

function common.build_list_command(root)
  local normalized_root = common.normalize_path(root)
  if common.is_windows() then
    local win_root = normalized_root:gsub("/", "\\")
    return 'dir /b /s /a-d "' .. win_root .. '\\*.lua" 2>nul'
  end
  return 'find "' .. normalized_root .. '" -type f -name "*.lua" 2>/dev/null'
end

function common.collect_lua_files(root)
  local process = io.popen(common.build_list_command(root))
  if not process then
    return nil, "cannot run list command for root: " .. tostring(root)
  end

  local files = {}
  for line in process:lines() do
    if line and line ~= "" then
      files[#files + 1] = common.normalize_path(line)
    end
  end

  local ok = process:close()
  if ok == nil or ok == false then
    return nil, "list command failed for root: " .. tostring(root)
  end

  table.sort(files)
  return files
end

function common.read_file(path)
  local file = io.open(path, "r")
  if not file then
    return nil, "cannot open file: " .. tostring(path)
  end
  local content = file:read("*a")
  file:close()
  return content
end

function common.write_file(path, content)
  local file = io.open(path, "w")
  if not file then
    return nil, "cannot write file: " .. tostring(path)
  end
  file:write(content)
  file:close()
  return true
end

function common.parent_dir(path)
  local normalized = common.normalize_path(path)
  return normalized:match("^(.*)/[^/]+$")
end

function common.ensure_dir(path)
  if path == nil or path == "" then
    return true
  end
  local normalized = common.normalize_path(path)
  local cmd
  if common.is_windows() then
    local win_path = normalized:gsub("/", "\\")
    cmd = 'mkdir "' .. win_path .. '" >nul 2>nul'
  else
    cmd = 'mkdir -p "' .. normalized .. '"'
  end
  local ok = os.execute(cmd)
  if ok == nil or ok == false then
    return nil, "failed to create directory: " .. normalized
  end
  return true
end

function common.ensure_parent_dir(path)
  return common.ensure_dir(common.parent_dir(path))
end

function common.split(text, delimiter)
  local parts = {}
  if text == nil or text == "" then
    return parts
  end
  local start_index = 1
  while true do
    local hit_start, hit_end = string.find(text, delimiter, start_index, true)
    if hit_start == nil then
      parts[#parts + 1] = string.sub(text, start_index)
      break
    end
    parts[#parts + 1] = string.sub(text, start_index, hit_start - 1)
    start_index = hit_end + 1
  end
  return parts
end

function common.join(parts, delimiter)
  return table.concat(parts or {}, delimiter or "")
end

function common.copy_array(values)
  local copied = {}
  for index, value in ipairs(values or {}) do
    copied[index] = value
  end
  return copied
end

function common.starts_with_segments(parts, prefix)
  if #prefix > #parts then
    return false
  end
  for index = 1, #prefix do
    if parts[index] ~= prefix[index] then
      return false
    end
  end
  return true
end

function common.sorted_keys(map)
  local keys = {}
  for key in pairs(map or {}) do
    keys[#keys + 1] = key
  end
  table.sort(keys)
  return keys
end

function common.list_to_set(values)
  local set = {}
  for _, value in ipairs(values or {}) do
    set[value] = true
  end
  return set
end

function common.edge_key(from_id, to_id)
  return tostring(from_id) .. "\n" .. tostring(to_id)
end

function common.sorted_edges(edge_map)
  local edges = {}
  for _, edge in _sorted_pairs(edge_map or {}) do
    edges[#edges + 1] = edge
  end
  table.sort(edges, function(left, right)
    if left.from == right.from then
      return tostring(left.to) < tostring(right.to)
    end
    return tostring(left.from) < tostring(right.from)
  end)
  return edges
end

function common.view_key(path_segments)
  if path_segments == nil or #path_segments == 0 then
    return "root"
  end
  return table.concat(path_segments, ".")
end

return common
