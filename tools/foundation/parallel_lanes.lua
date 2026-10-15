-- 原生Windows: start /b启动进程所有者,Job Object精确收容/终止自有子树。
local env = require("foundation.env")
local fs = require("foundation.fs")
local path = require("foundation.path")
local proc = require("foundation.proc")
local shell = require("foundation.shell")
local M = {}
local function native(value) return (value:gsub("/", "\\")) end
local _POWERSHELL = (os.getenv("SystemRoot") or "C:/Windows") .. "/System32/WindowsPowerShell/v1.0/powershell.exe"
local function helper(name)
  local source = debug.getinfo(1, "S").source:gsub("^@", ""):gsub("\\", "/")
  local root = assert(source:match("^(.*)/tools/foundation/parallel_lanes.lua$"))
  if not path.is_absolute_path(root) then root = path.join_path(env.current_dir(), root) end
  local target = root .. "/tools/foundation/" .. name
  if not fs.path_exists(target) then return nil, "Windows lane script missing: " .. target end
  return target
end
local function status(entry)
  local text = fs.read_raw(entry.status)
  if not text then return nil end
  local code, reason = text:match("^(%d+) ([%w_]+)")
  return tonumber(code), reason
end
-- 父进程一次性阻塞等待全部 lane 发布完成(#107):lane_wait.ps1 用 .NET
-- FileSystemWatcher 带超时等待,不轮询自旋、不用 sleep 命令、不依赖网络。
-- 等待器自身失败时不重试(避免热循环),未发布的 lane 照常报 output_incomplete。
local function wait_all(pending, seconds)
  local waiter, err = helper("lane_wait.ps1")
  if not waiter then return nil, err end
  local list = env.make_temp_path("parallel_wait", ".txt")
  local ok, write_err = fs.write_file(list, table.concat(pending, "\n") .. "\n")
  if not ok then return nil, write_err end
  local result = proc.run_command({
    native(_POWERSHELL), "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File",
    native(waiter), native(list), tostring(math.max(0, seconds)),
  })
  fs.remove_path(list)
  return result.ok
end
-- 裸命令名解析成 cmd.exe 语义的完整路径;已是路径形态(含 / \ 或盘符)的原样返回。
-- cmd 先走 CreateProcess(无扩展名时自动补 .exe 全 PATH 查找),找不到才退回
-- PATHEXT 批处理搜索——所以先挑 where.exe 命中里的第一个 .exe,没有再取首个命中
-- (实测:PATH 前段有 lua.cmd shim 时 cmd 仍执行后段目录的 lua.exe)。
local function resolve_exe(name)
  name = tostring(name or "")
  if name == "" or name:find("[/\\]") or name:match("^%a:") then return name end
  local result = proc.run_command({ "where.exe", name })
  if not result.ok then return name end
  local first, first_exe
  for line in (tostring(result.output or "") .. "\n"):gmatch("(.-)\n") do
    line = line:gsub("%s+$", "")
    if line ~= "" then
      if first == nil then first = line end
      if first_exe == nil and line:lower():match("%.exe$") then first_exe = line end
    end
  end
  return first_exe or first or name
end
local function launch(entry, executable, timeout)
  local command = entry.cmd
  if type(command) == "table" then
    -- argv 表必须保住 arg[-1](解释器身份),且与串行路径逐字节一致(#107):
    -- 串行 proc.run_command 经 cmd.exe 执行,裸命令名会被按 PATH 解析成完整路径
    -- 作为 argv[0] 传给子进程(实测 serial arg[-1] 是全路径);lane_process.ps1 的
    -- CreateProcess 不做这层解析,原样转发得到裸名。spec 以 arg[-1] 取解释器身份
    -- 并在剥离 PATH 的环境复用(test_parallel_lanes @144),裸名即断。解析失败时
    -- 保持原值(进程本来也起不来,语义不变)。
    local args = { string.format("[-1]=%q", resolve_exe(command[1])) }
    for index = 2, #command do args[#args + 1] = string.format("[%d]=%q", index - 2, command[index]) end
    local argv = entry.dir .. "/argv.lua"
    local ok, err = fs.write_file(argv, "arg={" .. table.concat(args, ",") .. "}; dofile(arg[0])\n")
    if not ok then return nil, err end
    command = shell.build_command({ command[1], argv })
  end
  local command_path = entry.dir .. "/command.cmd"
  local ok, err = fs.write_file(command_path, "@echo off\r\nchcp 65001 >nul\r\n" .. command .. "\r\nexit /b %errorlevel%\r\n")
  if not ok then return nil, err end
  local launcher = entry.dir .. "/launcher.cmd"
  ok, err = fs.write_file(launcher, "@echo off\r\nchcp 65001 >nul\r\n" .. shell.build_command({
    _POWERSHELL,
    "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", native(executable),
    native(command_path), native(entry.output), native(entry.status), tostring(timeout),
  }) .. ' >"' .. native(entry.dir .. '/owner.log') .. '" 2>&1\r\nexit /b %errorlevel%\r\n')
  if not ok then return nil, err end
  local exec_ok, kind, code = os.execute('start "" /b cmd.exe /d /v:off /s /c ""' .. native(launcher) .. '"" >nul 2>&1')
  if not shell.exit_status(exec_ok, kind, code) then return nil, "failed to start owner: " .. tostring(code) end
  return true
end

function M.run(lanes, opts)
  opts = opts or {}
  local timeout = opts.timeout or 600
  local executable, helper_err = helper("lane_process.ps1")
  local entries = {}
  local started = os.time()
  for _, lane in ipairs(lanes or {}) do
    local unique = env.make_temp_path("parallel_lane", "")
    local dir = opts.lane_dir and path.join_path(opts.lane_dir, unique:match("[^/]+$")) or unique
    local entry = { label = lane.label, cmd = lane.cmd, dir = dir }
    entry.output, entry.status = dir .. "/output.log", dir .. "/status.txt"
    entries[#entries + 1] = entry
    local prepared, prepare_err = fs.ensure_dir(dir)
    if not executable then entry.launch_error = helper_err
    elseif prepared then
      local launched, launch_err = launch(entry, executable, timeout)
      if not launched then entry.launch_error = tostring(launch_err) end
    else entry.launch_error = tostring(prepare_err) end
  end
  local pending = {}
  for _, entry in ipairs(entries) do
    if not entry.launch_error and status(entry) == nil then pending[#pending + 1] = native(entry.status) end
  end
  if #pending > 0 then wait_all(pending, started + timeout + 30 - os.time()) end
  local all_ok, results = #entries > 0, {}
  for _, entry in ipairs(entries) do
    local code, reason = status(entry)
    local result = { label = entry.label, ok = false, exit_code = code, output = fs.read_raw(entry.output) or "" }
    local identity = fs.read_raw(entry.status .. ".pid") or ""
    result.owner_pid, result.child_pid = identity:match("(%d+) (%d+)")
    if entry.launch_error then
      result.reason, result.message = "launch_failed", entry.launch_error
    elseif code == nil then
      result.reason, result.message = "output_incomplete", "Owner did not publish completion state: " .. tostring(entry.label)
      result.artifact_dir = entry.dir
      result.output = result.output .. (fs.read_raw(entry.dir .. "/owner.log") or "")
    elseif reason ~= "exit" then
      result.reason, result.message = reason, "Lane " .. tostring(entry.label) .. " " .. reason .. ": " .. code
      result.output = result.output .. (fs.read_raw(entry.status .. ".error") or "")
      if reason == "termination_failed" then result.artifact_dir = entry.dir end
    elseif code ~= 0 then
      result.reason, result.message = "exit", "Lane " .. tostring(entry.label) .. " exited " .. code
    elseif result.output == "" then
      result.reason, result.message = "output_incomplete", "Lane " .. tostring(entry.label) .. " exited 0 with empty output"
    else result.ok = true end
    if not result.artifact_dir then
      local cleaned, clean_err = fs.remove_path(entry.dir)
      if not cleaned then
        result.ok, result.artifact_dir = false, entry.dir
        result.message = tostring(result.message or "") .. "\n" .. tostring(clean_err)
      end
    end
    if not result.ok then
      all_ok = false
      if result.message and (result.output == "" or result.reason ~= "exit") then
        result.output = result.output .. (result.output == "" and "" or "\n") .. result.message .. "\n"
      end
    end
    results[#results + 1] = result
    if opts.stream ~= false and result.output ~= "" then
      io.write(result.output)
      if result.output:sub(-1) ~= "\n" then io.write("\n") end
    end
  end
  if opts.stream ~= false then io.flush() end
  return all_ok, results
end
return M
