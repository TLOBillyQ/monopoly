local function read_file(path)
  local file = io.open(path, "rb")
  if not file then
    return nil
  end
  local content = file:read("*a")
  file:close()
  return content
end

local function list_lua_files()
  local files = {}
  local pipe = io.popen('rg --files -g "*.lua" Components Config Manager Globals Data Library/Monopoly')
  if not pipe then
    return files
  end
  for line in pipe:lines() do
    if line ~= "" then
      table.insert(files, line)
    end
  end
  pipe:close()
  local init_file = io.open("init.lua", "rb")
  if init_file then
    init_file:close()
    table.insert(files, "init.lua")
  end
  local main_file = io.open("main.lua", "rb")
  if main_file then
    main_file:close()
    table.insert(files, "main.lua")
  end
  return files
end

local function add_violation(list, file, line_no, message)
  table.insert(list, file .. ":" .. tostring(line_no) .. ": " .. message)
end

local function scan_file(path, violations)
  local content = read_file(path)
  if not content then
    add_violation(violations, path, 0, "无法读取文件")
    return
  end
  local line_no = 0
  for line in content:gmatch("([^\n]*)\n?") do
    line_no = line_no + 1
    if line:find("%f[%w]io%.") then
      add_violation(violations, path, line_no, "使用 io.*")
    end
    if line:find("%f[%w]os%.") then
      add_violation(violations, path, line_no, "使用 os.*")
    end
    if line:find("%f[%w]package%.") then
      add_violation(violations, path, line_no, "使用 package.*")
    end
    if line:find("%f[%w]debug%.") then
      add_violation(violations, path, line_no, "使用 debug.*")
    end
    if line:find("debug%.traceback") then
      add_violation(violations, path, line_no, "使用 debug.traceback")
    end
    if line:find("math%.random") then
      add_violation(violations, path, line_no, "使用 math.random")
    end
    if line:find("__gc") then
      add_violation(violations, path, line_no, "使用 __gc")
    end
    if line:find("__mode") then
      add_violation(violations, path, line_no, "使用 __mode")
    end
  end
end

local violations = {}
for _, path in ipairs(list_lua_files()) do
  scan_file(path, violations)
end

if #violations > 0 then
  io.stdout:write("[lua-env] violations:\n")
  for _, item in ipairs(violations) do
    io.stdout:write("  - " .. item .. "\n")
  end
  os.exit(1)
end

io.stdout:write("[lua-env] ok: no violations in runtime paths\n")
