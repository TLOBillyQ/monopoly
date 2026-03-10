local common = {}

local _tointeger = math and math.tointeger
local _numeric_type_names = {
    number = true,
    integer = true,
    fixed = true,
}

local function _is_numeric_type_name(value_type)
    return _numeric_type_names[value_type] == true
end

local function _to_integer_safe(value)
    if value == nil then
        return nil
    end
    if _tointeger then
        local ok, as_int = pcall(_tointeger, value)
        if ok and as_int ~= nil then
            return as_int
        end
    end
    if math and math.floor then
        local ok, floored = pcall(math.floor, value)
        if ok and floored ~= nil then
            return floored
        end
    end
    return nil
end

local function _parse_integer_string(value)
    if value == nil then
        return nil
    end
    if not string.match(value, "^-?%d+$") then
        return nil
    end
    local len = #value
    if len == 0 then
        return nil
    end
    local i = 1
    local sign = 1
    if string.sub(value, 1, 1) == "-" then
        sign = -1
        i = 2
        if i > len then
            return nil
        end
    end
    local num = 0
    for idx = i, len do
        local byte = string.byte(value, idx)
        local digit = byte - 48
        if digit < 0 or digit > 9 then
            return nil
        end
        num = num * 10 + digit
    end
    if _tointeger then
        return _tointeger(sign * num)
    end
    return sign * num
end

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

function common.is_macos()
    if common.is_windows() then
        return false
    end
    local process = io.popen("uname")
    if not process then
        return false
    end
    local content = process:read("*l") or ""
    process:close()
    return common.normalize_path(content) == "Darwin"
end

function common.normalize_path(path)
    return tostring(path or ""):gsub("\\", "/")
end

function common.simplify_path(path)
    local normalized = common.normalize_path(path)
    local prefix = ""
    local remainder = normalized
    if normalized:match("^%a:/") then
        prefix = normalized:sub(1, 2)
        remainder = normalized:sub(4)
    elseif normalized:match("^/[A-Za-z]/") then
        prefix = normalized:sub(2, 3)
        remainder = normalized:sub(5)
    elseif normalized:sub(1, 1) == "/" then
        prefix = "/"
        remainder = normalized:sub(2)
    end
    local parts = {}
    for _, segment in ipairs(common.split(remainder, "/")) do
        if segment ~= "" and segment ~= "." then
            if segment == ".." then
                if #parts > 0 and parts[#parts] ~= ".." then
                    parts[#parts] = nil
                elseif prefix == "" then
                    parts[#parts + 1] = segment
                end
            else
                parts[#parts + 1] = segment
            end
        end
    end
    local simplified = table.concat(parts, "/")
    if prefix == "" then
        return simplified
    end
    if simplified == "" then
        return prefix == "/" and "/" or (prefix .. "/")
    end
    if prefix == "/" then
        return "/" .. simplified
    end
    return prefix .. "/" .. simplified
end

function common.current_dir()
    if common.is_windows() then
        local env_path = os.getenv("CD") or os.getenv("PWD")
        if env_path ~= nil and env_path ~= "" then
            return common.normalize_path(env_path)
        end
        return "."
    end

    local process = io.popen("pwd")
    if not process then
        return "."
    end
    local path = process:read("*l") or "."
    process:close()
    return common.normalize_path(path)
end

function common.is_absolute_path(path)
    local normalized = common.normalize_path(path)
    if normalized:match("^%a:/") then
        return true
    end
    if normalized:match("^/[A-Za-z]/") then
        return true
    end
    if normalized:match("^//") then
        return true
    end
    return normalized:sub(1, 1) == "/"
end

function common.join_path(base, child)
    local normalized_base = common.normalize_path(base)
    local normalized_child = common.normalize_path(child)
    if normalized_base == "" then
        return normalized_child
    end
    if normalized_child == "" then
        return normalized_base
    end
    return normalized_base:gsub("/+$", "") .. "/" .. normalized_child:gsub("^/+", "")
end

function common.resolve_path(base, path)
    local normalized_path = common.normalize_path(path)
    if normalized_path == "" then
        return common.simplify_path(base)
    end
    if common.is_windows() and normalized_path:sub(1, 1) == "/" then
        if normalized_path:match("^/[A-Za-z]/") then
            return common.simplify_path(normalized_path:sub(2, 2) .. ":" .. normalized_path:sub(3))
        end
        local tmpdir = common.system_tmp_dir()
        if normalized_path == "/tmp" or normalized_path:match("^/tmp/") then
            local suffix = normalized_path:sub(5)
            return common.simplify_path(common.join_path(tmpdir, suffix))
        end
    end
    if common.is_absolute_path(normalized_path) then
        return common.simplify_path(normalized_path)
    end
    return common.simplify_path(common.join_path(base or "", normalized_path))
end

function common.system_tmp_dir()
    local env = nil
    if common.is_windows() then
        env = os.getenv("TEMP") or os.getenv("TMP")
    else
        env = os.getenv("TMPDIR")
    end
    if env == nil or env == "" then
        if common.is_windows() then
            env = "C:/Windows/Temp"
        else
            env = "/tmp"
        end
    end
    return common.normalize_path(env)
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

function common.build_open_command(path)
    local normalized = common.normalize_path(path)
    if common.is_windows() then
        return 'start "" "' .. normalized:gsub("/", "\\") .. '"'
    end
    if common.is_macos() then
        return 'open "' .. normalized .. '"'
    end
    return 'xdg-open "' .. normalized .. '" >/dev/null 2>&1'
end

function common.open_path(path)
    local ok = os.execute(common.build_open_command(path))
    if ok == nil or ok == false then
        return nil, "failed to open path: " .. common.normalize_path(path)
    end
    return true
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

function common.is_numeric(value)
    local value_type = type(value)
    if value_type == "nil" then
        return false
    end
    if _is_numeric_type_name(value_type) then
        return true
    end
    if value_type == "string" then
        return false
    end
    return _to_integer_safe(value) ~= nil
end

function common.to_integer(value)
    local value_type = type(value)
    if value_type == "string" then
        local parsed = _parse_integer_string(value)
        if parsed ~= nil then
            return parsed
        end
        return nil
    end
    if common.is_numeric(value) then
        local parsed = _to_integer_safe(value)
        if parsed ~= nil then
            return parsed
        end
    end
    if value ~= nil then
        local ok, as_text = pcall(tostring, value)
        if ok and type(as_text) == "string" then
            local parsed = _parse_integer_string(as_text)
            if parsed ~= nil then
                return parsed
            end
        end
    end
    return nil
end

function common.view_key(path_segments)
    if path_segments == nil or #path_segments == 0 then
        return "root"
    end
    return table.concat(path_segments, ".")
end

function common.strip_src_prefix(module_id)
    local text = tostring(module_id or "")
    return (text:gsub("^src%.", ""))
end

function common.source_filename(path)
    local normalized = common.normalize_path(path)
    return normalized:match("([^/]+)$")
end

function common.source_filename_base(path)
    local filename = common.source_filename(path)
    if filename == nil then
        return nil
    end
    return (filename:gsub("%.[^.]+$", ""))
end

return common
