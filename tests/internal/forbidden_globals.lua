-- Scans src/tests/scripts for forbidden globals that are unavailable in the game runtime sandbox.
-- Run as part of regression: dofile("tests/internal/forbidden_globals.lua")

local forbidden = {
  { pattern = "%f[%w]tonumber%s*%(", name = "tonumber", replacement = "NumberUtils.to_integer()" },
  { pattern = "%f[%w_]rawget%s*%(", name = "rawget", replacement = "field access with nil-guard (_G and _G.key)" },
  { pattern = "%f[%w_]os%s*%.%s*clock%s*%(", name = "os.clock", replacement = "runtime port clock or injected now_fn" },
  { pattern = "%f[%w_]debug%s*%.%s*traceback%s*%(", name = "debug.traceback", replacement = "traceback() global" },
  { pattern = "type%s*%b()%s*==%s*[\"']number[\"']", name = "type(...) == \"number\"", replacement = "NumberUtils.is_numeric()/to_integer()" },
  { pattern = "type%s*%b()%s*~=%s*[\"']number[\"']", name = "type(...) ~= \"number\"", replacement = "NumberUtils.is_numeric()/to_integer()" },
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

local scan_roots = { "src", "tests", "scripts" }
local files = {}
for _, root in ipairs(scan_roots) do
  local root_files, err = _collect_lua_files(root)
  if root_files then
    for _, path in ipairs(root_files) do
      files[#files + 1] = path
    end
  else
    io.stderr:write("forbidden_globals warn: ", err, "\n")
  end
end
if #files == 0 then
  io.stderr:write("forbidden_globals error: no lua files found in scan roots\n")
  os.exit(1)
end

local violations = {}
for _, path in ipairs(files) do
  local file = io.open(path, "r")
  if file then
    local lineno = 0
    for line in file:lines() do
      lineno = lineno + 1
      if not line:match("^%s*%-%-") then
        for _, rule in ipairs(forbidden) do
          if line:find(rule.pattern) then
            violations[#violations + 1] = {
              path = path, line = lineno, name = rule.name,
              replacement = rule.replacement, text = line,
            }
          end
        end
      end
    end
    file:close()
  end
end

if #violations > 0 then
  for _, v in ipairs(violations) do
    io.stderr:write("forbidden_globals: ", v.path, ":", v.line,
      " uses ", v.name, " (use ", v.replacement, " instead)\n")
    io.stderr:write("  ", v.text, "\n")
  end
  os.exit(1)
end

print("forbidden_globals ok")
