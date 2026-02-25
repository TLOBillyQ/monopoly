local forbidden_prefixes = {
  "src.game.",
}

local function _contains_forbidden(line)
  for _, prefix in ipairs(forbidden_prefixes) do
    if line:find(prefix, 1, true) then
      return prefix
    end
  end
  return nil
end

local function _is_windows()
  return package.config:sub(1, 1) == "\\"
end

local function _build_list_command(root)
  if _is_windows() then
    local win_root = root:gsub("/", "\\")
    return 'dir /b /s /a-d "' .. win_root .. '\\*.lua" 2>nul'
  end
  return 'find "' .. root .. '" -type f -name "*.lua" 2>/dev/null'
end

local function _collect_lua_files(root)
  local cmd = _build_list_command(root)
  local p = io.popen(cmd)
  if not p then
    return nil, "cannot run list command: " .. cmd
  end

  local files = {}
  for line in p:lines() do
    if line and line ~= "" then
      files[#files + 1] = line
    end
  end

  local ok, why, code = p:close()
  if ok == nil or ok == false then
    return nil, "list command failed: " .. tostring(why) .. " " .. tostring(code)
  end
  if #files == 0 then
    return nil, "no lua files found under: " .. tostring(root)
  end
  return files
end

local function _scan_file(path)
  local file = io.open(path, "r")
  if not file then
    return nil, "cannot open: " .. tostring(path)
  end
  local lineno = 0
  for line in file:lines() do
    lineno = lineno + 1
    local hit = _contains_forbidden(line)
    if hit then
      file:close()
      return {
        path = path,
        line = lineno,
        prefix = hit,
        text = line,
      }
    end
  end
  file:close()
  return nil
end

local function _scan_tree(root)
  local files, files_err = _collect_lua_files(root)
  if not files then
    return nil, files_err
  end
  for _, path in ipairs(files) do
    local hit, scan_err = _scan_file(path)
    if hit then
      return hit
    end
    if scan_err then
      return nil, scan_err
    end
  end
  return nil
end

local hit, err = _scan_tree("src/presentation/interaction")
if err then
  io.stderr:write("dep_rules error: ", err, "\n")
  os.exit(1)
end
if hit then
  io.stderr:write("dep_rules violation: ", hit.path, ":", hit.line, " contains ", hit.prefix, "\n")
  io.stderr:write(hit.text, "\n")
  os.exit(1)
end

print("dep_rules ok")
