-- 原生Windows: start /b启动进程所有者,Job Object精确收容/终止自有子树。
local env = require("foundation.env")
local fs = require("foundation.fs")
local path = require("foundation.path")
local shell = require("foundation.shell")
local M = {}
local function native(value) return (value:gsub("/", "\\")) end
local function helper()
  local source = debug.getinfo(1, "S").source:gsub("^@", ""):gsub("\\", "/")
  local root = assert(source:match("^(.*)/tools/foundation/parallel_lanes.lua$"))
  if not path.is_absolute_path(root) then root = path.join_path(env.current_dir(), root) end
  local target = root .. "/tools/foundation/lane_process.ps1"
  if not fs.path_exists(target) then return nil, "Windows lane owner script missing: " .. target end
  return target
end
local function status(entry)
  local text = fs.read_raw(entry.status)
  if not text then return nil end
  local code, reason = text:match("^(%d+) ([%w_]+)")
  return tonumber(code), reason
end
local function pause(seconds)
  local deadline = os.clock() + seconds
  while os.clock() < deadline do end
end
local function launch(entry, executable, timeout)
  local command = entry.cmd
  if type(command) == "table" then
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
  ok, err = fs.write_file(launcher, "@echo off\r\nchcp 65001 >nul\r\n" .. shell.build_command({
    (os.getenv("SystemRoot") or "C:/Windows") .. "/System32/WindowsPowerShell/v1.0/powershell.exe",
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
  local executable, helper_err = helper()
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
  while true do
    local pending = false
    for _, entry in ipairs(entries) do
      if not entry.launch_error and status(entry) == nil then pending = true end
    end
    if not pending then break end
    if os.time() > started + timeout + 30 then break end
    pause(opts.poll_interval or 0.1)
  end
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
