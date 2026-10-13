-- 原生 Windows 并行边界:输出关闭后原子发布完成状态,结果按提交顺序返回。
-- 独立最小化控制台提供唯一标题,超时用 taskkill /t 停掉对应进程树。
local env = require("foundation.env")
local fs = require("foundation.fs")
local path = require("foundation.path")
local shell = require("foundation.shell")
local M = {}

local function native(value)
  return (value:gsub("/", "\\"))
end

local function quote(value)
  return shell.shell_quote(native(value))
end

local function status(entry)
  local text = fs.read_raw(entry.status)
  return text and tonumber(text:match("^%s*(%-?%d+)%s*$")) or nil
end

local function pause(seconds)
  -- Lua 5.4 标准库没有阻塞定时器;不引入额外运行依赖。
  local deadline = os.clock() + seconds
  while os.clock() < deadline do end
end

local function launch(entry)
  local command = entry.cmd
  if type(command) == "table" then
    -- Lua argv 落盘绕过 cmd 的 8191 字符限制。数组只接受 Lua解释器+脚本+参数。
    local args = {}
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
  ok, err = fs.write_file(launcher, table.concat({
    "@echo off", "chcp 65001 >nul", "title " .. entry.title,
    'cmd.exe /d /v:off /s /c ""' .. native(command_path) .. '"" > ' .. quote(entry.output) .. " 2>&1",
    "set eggy_code=%errorlevel%",
    "> " .. quote(entry.status .. ".done") .. " echo %eggy_code%",
    "move /y " .. quote(entry.status .. ".done") .. " " .. quote(entry.status) .. " >nul",
    "exit",
  }, "\r\n") .. "\r\n")
  if not ok then return nil, err end
  local exec_ok, kind, code = os.execute('start "" /min cmd.exe /d /v:off /s /c ""' .. native(launcher) .. '""')
  if not shell.exit_status(exec_ok, kind, code) then return nil, "failed to start launcher: " .. tostring(code) end
  return true
end

local function stop(entry)
  local log = entry.dir .. "/stop.log"
  local ok, kind, code = os.execute("taskkill /fi " .. shell.shell_quote("WINDOWTITLE eq " .. entry.title)
    .. " /t /f > " .. quote(log) .. " 2>&1")
  entry.stopped = shell.exit_status(ok, kind, code)
  entry.stop_log = fs.read_raw(log) or "termination returned no diagnostic"
end

-- lanes[i]={label,cmd}; cmd 是 cmd语法字符串,或 Lua解释器/脚本/参数数组。
-- timeout 默认600s,stream 默认true;lane_dir仅用作隔离临时目录的父目录。
function M.run(lanes, opts)
  opts = opts or {}
  local timeout = opts.timeout or 600
  local entries = {}
  local started = os.time()
  for index, lane in ipairs(lanes or {}) do
    local unique = env.make_temp_path("parallel_lane", "")
    local dir = opts.lane_dir and path.join_path(opts.lane_dir, unique:match("[^/]+$")) or unique
    local entry = { label = lane.label, cmd = lane.cmd, dir = dir,
      title = "eggy_parallel_" .. tostring(started) .. "_" .. tostring(index) .. "_" .. tostring({}):gsub("[^%w]", "") }
    entry.output, entry.status = dir .. "/output.log", dir .. "/status.txt"
    entries[#entries + 1] = entry
    local prepared, prepare_err = fs.ensure_dir(dir)
    if prepared then
      local launched, launch_err = launch(entry)
      if not launched then entry.launch_error = tostring(launch_err) end
    else entry.launch_error = tostring(prepare_err) end
  end

  while true do
    local pending = {}
    for _, entry in ipairs(entries) do
      if not entry.launch_error and status(entry) == nil then pending[#pending + 1] = entry end
    end
    if #pending == 0 then break end
    if os.time() >= started + timeout then
      for _, entry in ipairs(pending) do stop(entry) end
      break
    end
    pause(opts.poll_interval or 0.1)
  end

  local all_ok, results = #entries > 0, {}
  for _, entry in ipairs(entries) do
    local code = status(entry)
    local output = fs.read_raw(entry.output) or ""
    local result = { label = entry.label, ok = false, exit_code = code, output = output }
    if entry.launch_error then
      result.reason, result.message = "launch_failed", entry.launch_error
    elseif entry.stop_log then
      result.reason = "timeout"
      result.message = "Lane " .. tostring(entry.label) .. " timed out after " .. timeout .. "s; termination: " .. entry.stop_log
    elseif code == nil then
      result.reason, result.message = "output_incomplete", "Missing completion state for " .. tostring(entry.label)
    elseif code ~= 0 then
      result.reason = code == 9009 and "launch_failed" or "exit"
      result.message = "Lane " .. tostring(entry.label) .. " exited " .. code
    elseif output == "" then
      result.reason, result.message = "output_incomplete", "Lane " .. tostring(entry.label) .. " exited 0 with empty output"
    else result.ok = true end

    -- 无法确认停止时保留产物,不删除仍被子进程使用的目录。
    if entry.stopped == false then
      result.artifact_dir = entry.dir
      result.message = result.message .. "\nTermination not confirmed; retained " .. entry.dir
    else
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
