local retired_path_parts = {
  { "src", "core", "runtime_facade" },
  { "src", "game", "turn_engine" },
  { "src", "game", "legacy", "turn_engine" },
  { "src", "presentation", "adapter" },
  { "src", "presentation", "canvas_runtime" },
  { "src", "game", "systems", "market", "service" },
  { "src", "app", "bootstrap", "runtime_install" },
  { "src", "core", "ports", "turn_ui_sync_shared" },
}

local scan_roots = { "src", "tests" }

local function is_windows()
  return package.config:sub(1, 1) == "\\"
end

local function build_list_command(root)
  if is_windows() then
    local win_root = root:gsub("/", "\\")
    return 'dir /b /s /a-d "' .. win_root .. '\\*.lua" 2>nul'
  end
  return 'find "' .. root .. '" -type f -name "*.lua" 2>/dev/null'
end

local function collect_lua_files(root)
  local process = io.popen(build_list_command(root))
  if not process then
    return nil, "cannot run list command for root: " .. root
  end

  local files = {}
  for line in process:lines() do
    if line and line ~= "" then
      files[#files + 1] = line
    end
  end

  local ok = process:close()
  if ok == nil or ok == false then
    return nil, "list command failed for root: " .. root
  end

  return files
end

local function normalize_path(path)
  return path:gsub("\\", "/")
end

local function should_skip(path)
  local normalized = normalize_path(path)
  return normalized:match("^vendor/") ~= nil
    or normalized:match("^Config/") ~= nil
    or normalized:match("^Data/") ~= nil
    or normalized:match("^tests/internal/legacy_path_guard%.lua$") ~= nil
end

local function join_path(parts)
  return table.concat(parts, ".")
end

local retired_paths = {}
for _, parts in ipairs(retired_path_parts) do
  retired_paths[#retired_paths + 1] = join_path(parts)
end

local files = {}
for _, root in ipairs(scan_roots) do
  local root_files, err = collect_lua_files(root)
  if not root_files then
    io.stderr:write("legacy_path_guard error: ", err, "\n")
    os.exit(1)
  end

  for _, path in ipairs(root_files) do
    if not should_skip(path) then
      files[#files + 1] = path
    end
  end
end

local violations = {}
for _, path in ipairs(files) do
  local file = io.open(path, "r")
  if file then
    local line_number = 0
    for line in file:lines() do
      line_number = line_number + 1
      if not line:match("^%s*%-%-") then
        for _, retired_path in ipairs(retired_paths) do
          if line:find(retired_path, 1, true) then
            violations[#violations + 1] = {
              path = normalize_path(path),
              line = line_number,
              retired_path = retired_path,
              text = line,
            }
          end
        end
      end
    end
    file:close()
  end
end

if #violations > 0 then
  io.stderr:write("legacy_path_guard found retired module paths:\n")
  for _, violation in ipairs(violations) do
    io.stderr:write(
      "legacy_path_guard: ",
      violation.path,
      ":",
      tostring(violation.line),
      " contains ",
      violation.retired_path,
      "\n"
    )
    io.stderr:write("  ", violation.text, "\n")
  end
  os.exit(1)
end

print("legacy_path_guard ok")
