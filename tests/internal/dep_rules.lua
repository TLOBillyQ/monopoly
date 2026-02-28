local rules = {
  {
    root = "src/presentation/interaction",
    forbidden = { "src.game." },
    description = "interaction layer must not require src.game.* directly",
  },
  {
    root = "src/presentation/canvas",
    forbidden = { "src.presentation.shared.UINodes" },
    description = "canvas modules must not depend on legacy shared UINodes directly",
  },
  {
    root = "src/presentation/canvas_runtime",
    forbidden = { "intent_builders" },
    description = "canvas_runtime must not depend on legacy intent_builders",
  },
}

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

  local ok = p:close()
  if ok == nil or ok == false then
    return nil, "list command failed: " .. tostring(cmd)
  end
  if #files == 0 then
    return nil, "no lua files found under: " .. tostring(root)
  end
  return files
end

local function _scan_file(path, forbidden)
  local file = io.open(path, "r")
  if not file then
    return nil, "cannot open: " .. tostring(path)
  end
  local lineno = 0
  for line in file:lines() do
    lineno = lineno + 1
    for _, prefix in ipairs(forbidden) do
      if line:find(prefix, 1, true) then
        file:close()
        return {
          path = path,
          line = lineno,
          prefix = prefix,
          text = line,
        }
      end
    end
  end
  file:close()
  return nil
end

local function _scan_tree(rule)
  local files, files_err = _collect_lua_files(rule.root)
  if not files then
    return nil, files_err
  end
  for _, path in ipairs(files) do
    local hit, scan_err = _scan_file(path, rule.forbidden)
    if hit then
      return hit
    end
    if scan_err then
      return nil, scan_err
    end
  end
  return nil
end

for _, rule in ipairs(rules) do
  local hit, err = _scan_tree(rule)
  if err and not tostring(err):find("no lua files found under", 1, true) then
    io.stderr:write("dep_rules error: ", err, "\n")
    os.exit(1)
  end
  if hit then
    io.stderr:write("dep_rules violation: ", hit.path, ":", hit.line, " contains ", hit.prefix, "\n")
    io.stderr:write("rule: ", rule.description, "\n")
    io.stderr:write(hit.text, "\n")
    os.exit(1)
  end
end

print("dep_rules ok")
