local M = {}

function M.is_windows()
  return package.config:sub(1, 1) == "\\"
end

function M.build_list_command(root)
  if M.is_windows() then
    local win_root = root:gsub("/", "\\")
    return 'dir /b /s /a-d "' .. win_root .. '\\*.lua" 2>nul'
  end
  return 'find "' .. root .. '" -type f -name "*.lua" 2>/dev/null'
end

function M.collect_lua_files(root)
  local process = io.popen(M.build_list_command(root))
  if not process then
    return nil, "cannot run list command for root: " .. tostring(root)
  end

  local files = {}
  for line in process:lines() do
    if line and line ~= "" then
      files[#files + 1] = line
    end
  end

  local ok = process:close()
  if ok == nil or ok == false then
    return nil, "list command failed for root: " .. tostring(root)
  end

  return files
end

function M.normalize_path(path)
  return tostring(path or ""):gsub("\\", "/")
end

function M.to_repo_relpath(path)
  local normalized = M.normalize_path(path)
  return normalized:match(".*(src/.+)")
    or normalized:match(".*(tests/.+)")
    or normalized:match(".*(scripts/.+)")
    or normalized
end

function M.is_comment_line(line)
  return tostring(line or ""):match("^%s*%-%-") ~= nil
end

function M.list_lua_files(roots, opts)
  opts = opts or {}
  local files = {}
  for _, root in ipairs(roots or {}) do
    local root_files, err = M.collect_lua_files(root)
    if not root_files then
      if opts.allow_empty_roots ~= true or not tostring(err):find("no lua files found under", 1, true) then
        return nil, err
      end
    else
      for _, path in ipairs(root_files) do
        local relpath = M.to_repo_relpath(path)
        if opts.skip_path == nil or opts.skip_path(path, relpath) ~= true then
          files[#files + 1] = {
            path = path,
            relpath = relpath,
          }
        end
      end
    end
  end
  return files
end

function M.find_line_violation(opts)
  opts = opts or {}
  local files, err = M.list_lua_files(opts.roots or {}, opts)
  if not files then
    return nil, err
  end

  for _, entry in ipairs(files) do
    local file = io.open(entry.path, "r")
    if not file then
      return nil, "cannot open: " .. tostring(entry.path)
    end

    local line_number = 0
    for line in file:lines() do
      line_number = line_number + 1
      local violation = opts.find_violation(entry.path, entry.relpath, line, line_number)
      if violation then
        file:close()
        return violation
      end
    end

    file:close()
  end

  return nil
end

function M.collect_line_violations(opts)
  opts = opts or {}
  local files, err = M.list_lua_files(opts.roots or {}, opts)
  if not files then
    return nil, err
  end

  local violations = {}
  for _, entry in ipairs(files) do
    local file = io.open(entry.path, "r")
    if not file then
      return nil, "cannot open: " .. tostring(entry.path)
    end

    local line_number = 0
    for line in file:lines() do
      line_number = line_number + 1
      local violation = opts.find_violation(entry.path, entry.relpath, line, line_number)
      if violation then
        violations[#violations + 1] = violation
      end
    end

    file:close()
  end

  return violations
end

return M
