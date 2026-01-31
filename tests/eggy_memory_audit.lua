dofile("tests/test_bootstrap.lua")

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
  local pipe = io.popen('rg --files -g "*.lua" Components Config Manager Globals')
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
    if line:find("%f[%w]LuaAPI%s*:%s*%w") then
      add_violation(violations, path, line_no, "LuaAPI 使用冒号调用")
    end
    if line:find("%f[%w]GameAPI%s*:%s*%w") then
      add_violation(violations, path, line_no, "GameAPI 使用冒号调用")
    end
    if line:find("%f[%w]GlobalAPI%s*:%s*%w") then
      add_violation(violations, path, line_no, "GlobalAPI 使用冒号调用")
    end
    if line:find("GlobalAPI%.show_tips%([^,]+,%s*%-?%d+%s*[,)]") then
      add_violation(violations, path, line_no, "show_tips 使用整数字面量时长")
    end
    if line:find("LuaAPI%.call_delay_time%(%s*%-?%d+%s*[,)]") then
      add_violation(violations, path, line_no, "call_delay_time 使用整数字面量时长")
    end
    if line:find("math%.Quaternion%(%s*%-?%d+%s*,%s*%-?%d+%s*,%s*%-?%d+%s*%)") then
      add_violation(violations, path, line_no, "Quaternion 使用整数字面量")
    end
    if line:find("math%.Vector3%(%s*%-?%d+%s*,%s*%-?%d+%s*,%s*%-?%d+%s*%)") then
      add_violation(violations, path, line_no, "Vector3 使用整数字面量")
    end
  end
end

local violations = {}
for _, path in ipairs(list_lua_files()) do
  scan_file(path, violations)
end

if #violations > 0 then
  io.stdout:write("[eggy-memory] violations:\n")
  for _, item in ipairs(violations) do
    io.stdout:write("  - " .. item .. "\n")
  end
  os.exit(1)
end

io.stdout:write("ok - eggy memory audit\n")
