local forbidden_patterns = {
  "src%.game%.",
  "src%.core%.",
  "src%.turn%.",
  "src%.visual%.",
  "src%.choice%.",
  "src%.chance%.",
}

local scan_dirs = {
  "game",
  "turn",
  "visual",
  "core",
  "choice",
  "cfg",
}

local function _contains_forbidden(line)
  for _, pattern in ipairs(forbidden_patterns) do
    if line:find(pattern, 1, true) then
      return pattern
    end
  end
  return nil
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
        pattern = hit,
        text = line,
      }
    end
  end
  file:close()
  return nil
end

local function _walk_dir(dir, entries)
  local p = io.popen('ls -1 "' .. dir .. '"')
  if not p then
    return
  end
  for name in p:lines() do
    if name ~= "." and name ~= ".." then
      local full = dir .. "/" .. name
      entries[#entries + 1] = full
    end
  end
  p:close()
end

local function _is_dir(path)
  local p = io.popen('[ -d "' .. path .. '" ] && echo dir')
  if not p then
    return false
  end
  local res = p:read("*l")
  p:close()
  return res == "dir"
end

local function _is_lua(path)
  return path:sub(-4) == ".lua"
end

local function _scan_tree(root)
  local queue = { root }
  while #queue > 0 do
    local current = table.remove(queue, 1)
    if _is_dir(current) then
      local entries = {}
      _walk_dir(current, entries)
      for _, entry in ipairs(entries) do
        queue[#queue + 1] = entry
      end
    elseif _is_lua(current) then
      local hit = _scan_file(current)
      if hit then
        return hit
      end
    end
  end
  return nil
end

for _, dir in ipairs(scan_dirs) do
  local hit = _scan_tree(dir)
  if hit then
    io.stderr:write("dep_rules violation: ", hit.path, ":", hit.line, " contains ", hit.pattern, "\n")
    io.stderr:write(hit.text, "\n")
    os.exit(1)
  end
end

print("dep_rules ok")
