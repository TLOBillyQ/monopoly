local number_utils = require("src.core.utils.number_utils")

local common = {}

local _random_seeded = false
local _temp_counter = 0

local function _seed_random_once()
  if _random_seeded then
    return
  end
  math.randomseed(os.time())
  math.random()
  math.random()
  math.random()
  _random_seeded = true
end

local function _os_execute_success(ok, _, code)
  if ok == true then
    return true, code or 0
  end
  if number_utils.is_numeric(code) and code == 0 then
    return true, 0
  end
  return false, code or 1
end

function common.sorted_pairs(map)
  local keys = {}
  for key in pairs(map or {}) do
    keys[#keys + 1] = key
  end
  table.sort(keys)
  local index = 0
  return function()
    index = index + 1
    local key = keys[index]
    if key == nil then
      return nil
    end
    return key, map[key]
  end
end

function common.sorted_keys(map)
  local keys = {}
  for key in pairs(map or {}) do
    keys[#keys + 1] = key
  end
  table.sort(keys)
  return keys
end

function common.is_windows()
  return package.config:sub(1, 1) == "\\"
end

function common.is_macos()
  if common.is_windows() then
    return false
  end
  local process = io.popen("uname")
  if process == nil then
    return false
  end
  local content = process:read("*l") or ""
  process:close()
  return common.normalize_path(content) == "Darwin"
end

function common.normalize_path(path)
  return tostring(path or ""):gsub("\\", "/")
end

function common.split(text, delimiter)
  local parts = {}
  local source = tostring(text or "")
  if source == "" then
    return parts
  end
  local start_index = 1
  while true do
    local hit_start, hit_end = string.find(source, delimiter, start_index, true)
    if hit_start == nil then
      parts[#parts + 1] = string.sub(source, start_index)
      break
    end
    parts[#parts + 1] = string.sub(source, start_index, hit_start - 1)
    start_index = hit_end + 1
  end
  return parts
end

function common.join(parts, delimiter)
  return table.concat(parts or {}, delimiter or "")
end

function common.simplify_path(path)
  local normalized = common.normalize_path(path)
  local prefix = ""
  local remainder = normalized

  if normalized:match("^%a:/") then
    prefix = normalized:sub(1, 2)
    remainder = normalized:sub(4)
  elseif normalized:sub(1, 1) == "/" then
    prefix = "/"
    remainder = normalized:sub(2)
  end

  local parts = {}
  for _, segment in ipairs(common.split(remainder, "/")) do
    if segment ~= "" and segment ~= "." then
      if segment == ".." then
        if #parts > 0 and parts[#parts] ~= ".." then
          parts[#parts] = nil
        elseif prefix == "" then
          parts[#parts + 1] = segment
        end
      else
        parts[#parts + 1] = segment
      end
    end
  end

  local simplified = table.concat(parts, "/")
  if prefix == "" then
    return simplified
  end
  if simplified == "" then
    if prefix == "/" then
      return "/"
    end
    return prefix .. "/"
  end
  if prefix == "/" then
    return "/" .. simplified
  end
  return prefix .. "/" .. simplified
end

function common.current_dir()
  if common.is_windows() then
    local env_path = os.getenv("CD") or os.getenv("PWD")
    if env_path ~= nil and env_path ~= "" then
      return common.normalize_path(env_path)
    end
    local process = io.popen("cd")
    if process ~= nil then
      local path = process:read("*l") or "."
      process:close()
      return common.normalize_path(path)
    end
    return "."
  end

  local process = io.popen("pwd")
  if process == nil then
    return "."
  end
  local path = process:read("*l") or "."
  process:close()
  return common.normalize_path(path)
end

function common.is_absolute_path(path)
  local normalized = common.normalize_path(path)
  if normalized:match("^%a:/") then
    return true
  end
  return normalized:sub(1, 1) == "/"
end

function common.join_path(base, child)
  local normalized_base = common.normalize_path(base)
  local normalized_child = common.normalize_path(child)
  if normalized_base == "" then
    return normalized_child
  end
  if normalized_child == "" then
    return normalized_base
  end
  return normalized_base:gsub("/+$", "") .. "/" .. normalized_child:gsub("^/+", "")
end

function common.resolve_path(base, path)
  local normalized_path = common.normalize_path(path)
  if normalized_path == "" then
    return common.simplify_path(base)
  end
  if common.is_absolute_path(normalized_path) then
    return common.simplify_path(normalized_path)
  end
  return common.simplify_path(common.join_path(base or "", normalized_path))
end

function common.parent_dir(path)
  local normalized = common.normalize_path(path)
  return normalized:match("^(.*)/[^/]+$")
end

function common.system_tmp_dir()
  local env = nil
  if common.is_windows() then
    env = os.getenv("TEMP") or os.getenv("TMP")
  else
    env = os.getenv("TMPDIR")
  end
  if env == nil or env == "" then
    if common.is_windows() then
      env = "C:/Windows/Temp"
    else
      env = "/tmp"
    end
  end
  return common.normalize_path(env)
end

function common.to_integer(value)
  return number_utils.to_integer(value)
end

function common.is_numeric(value)
  return number_utils.is_numeric(value)
end

function common.read_file(path)
  local file = io.open(path, "r")
  if file == nil then
    return nil, "cannot open file: " .. tostring(path)
  end
  local content = file:read("*a")
  file:close()
  return content
end

function common.write_file(path, content)
  local ok, err = common.ensure_parent_dir(path)
  if not ok then
    return nil, err
  end
  local file = io.open(path, "w")
  if file == nil then
    return nil, "cannot write file: " .. tostring(path)
  end
  file:write(content)
  file:close()
  return true
end

function common.append_file(path, content)
  local ok, err = common.ensure_parent_dir(path)
  if not ok then
    return nil, err
  end
  local file = io.open(path, "a")
  if file == nil then
    return nil, "cannot append file: " .. tostring(path)
  end
  file:write(content)
  file:close()
  return true
end

function common.shell_quote(value)
  local text = tostring(value or "")
  if common.is_windows() then
    return '"' .. text:gsub('"', '""') .. '"'
  end
  return "'" .. text:gsub("'", "'\\''") .. "'"
end

function common.build_command(args)
  local parts = {}
  for _, value in ipairs(args or {}) do
    parts[#parts + 1] = common.shell_quote(value)
  end
  return table.concat(parts, " ")
end

function common.make_temp_path(prefix, suffix)
  _seed_random_once()
  _temp_counter = _temp_counter + 1
  local base_dir = common.join_path(common.system_tmp_dir(), "monopoly_script_tools")
  common.ensure_dir(base_dir)
  local name = table.concat({
    tostring(prefix or "tmp"),
    tostring(os.time()),
    tostring(_temp_counter),
    tostring(math.random(100000, 999999))
  }, "_")
  return common.join_path(base_dir, name .. tostring(suffix or ""))
end

function common.ensure_dir(path)
  if path == nil or path == "" then
    return true
  end
  local normalized = common.normalize_path(path)
  local command
  if common.is_windows() then
    command = 'mkdir ' .. common.shell_quote(normalized:gsub("/", "\\")) .. ' >nul 2>nul'
  else
    command = 'mkdir -p ' .. common.shell_quote(normalized)
  end
  local ok, kind, code = os.execute(command)
  return _os_execute_success(ok, kind, code)
end

function common.ensure_parent_dir(path)
  return common.ensure_dir(common.parent_dir(path))
end

function common.path_exists(path)
  local normalized = common.normalize_path(path)
  local command
  if common.is_windows() then
    command = 'if exist ' .. common.shell_quote(normalized:gsub("/", "\\")) .. ' (exit 0) else (exit 1)'
  else
    command = '[ -e ' .. common.shell_quote(normalized) .. ' ]'
  end
  local ok, kind, code = os.execute(command)
  local success = _os_execute_success(ok, kind, code)
  return success
end

function common.is_dir(path)
  local normalized = common.normalize_path(path)
  local command
  if common.is_windows() then
    command = 'if exist ' .. common.shell_quote(normalized:gsub("/", "\\") .. "\\") .. ' (exit 0) else (exit 1)'
  else
    command = '[ -d ' .. common.shell_quote(normalized) .. ' ]'
  end
  local ok, kind, code = os.execute(command)
  local success = _os_execute_success(ok, kind, code)
  return success
end

function common.remove_path(path)
  if not common.path_exists(path) then
    return true
  end
  local normalized = common.normalize_path(path)
  local command
  if common.is_windows() then
    local win_path = normalized:gsub("/", "\\")
    if common.is_dir(normalized) then
      command = 'rmdir /s /q ' .. common.shell_quote(win_path)
    else
      command = 'del /f /q ' .. common.shell_quote(win_path)
    end
  else
    command = 'rm -rf ' .. common.shell_quote(normalized)
  end
  local ok, kind, code = os.execute(command)
  return _os_execute_success(ok, kind, code)
end

function common.copy_file(source_path, target_path)
  local ok, err = common.ensure_parent_dir(target_path)
  if not ok then
    return nil, err
  end
  local source_text, read_err = common.read_file(source_path)
  if source_text == nil then
    return nil, read_err
  end
  return common.write_file(target_path, source_text)
end

function common.copy_tree(source_path, target_path)
  local normalized_source = common.normalize_path(source_path)
  local normalized_target = common.normalize_path(target_path)
  common.remove_path(normalized_target)
  local ok, err = common.ensure_parent_dir(normalized_target)
  if not ok then
    return nil, err
  end

  local command
  if common.is_windows() then
    local win_source = normalized_source:gsub("/", "\\")
    local win_target = normalized_target:gsub("/", "\\")
    command = 'xcopy ' .. common.shell_quote(win_source) .. ' ' .. common.shell_quote(win_target) .. ' /E /I /Y >nul'
  else
    command = 'cp -R ' .. common.shell_quote(normalized_source) .. ' ' .. common.shell_quote(normalized_target)
  end

  local exec_ok, kind, code = os.execute(command)
  local success, exit_code = _os_execute_success(exec_ok, kind, code)
  if not success then
    return nil, 'copy tree failed with exit code ' .. tostring(exit_code)
  end
  return true
end

function common.wrap_command_with_cwd(command, cwd)
  local cwd_path = cwd and common.normalize_path(cwd) or nil
  if cwd_path == nil or cwd_path == "" then
    return tostring(command or "")
  end
  if common.is_windows() then
    return 'cd /d ' .. common.shell_quote(cwd_path:gsub("/", "\\")) .. ' && ' .. tostring(command or "")
  end
  return 'cd ' .. common.shell_quote(cwd_path) .. ' && ' .. tostring(command or "")
end

function common.run_command(command, options)
  local command_text = command
  if type(command) == "table" then
    command_text = common.build_command(command)
  end
  command_text = tostring(command_text or "")
  local output_path = common.make_temp_path("command_output", ".log")
  local wrapped = common.wrap_command_with_cwd(command_text, options and options.cwd or nil)
  local redirected = wrapped .. ' > ' .. common.shell_quote(output_path) .. ' 2>&1'
  local ok, kind, code = os.execute(redirected)
  local success, exit_code = _os_execute_success(ok, kind, code)
  local output = common.read_file(output_path) or ""
  common.remove_path(output_path)
  return {
    ok = success,
    code = exit_code,
    output = output,
  }
end

function common.collect_lua_files(root)
  local normalized_root = common.normalize_path(root)
  local command
  if common.is_windows() then
    command = 'dir /b /s /a-d ' .. common.shell_quote(normalized_root:gsub("/", "\\") .. '\\*.lua') .. ' 2>nul'
  else
    command = 'find ' .. common.shell_quote(normalized_root) .. ' -type f -name "*.lua" 2>/dev/null'
  end
  local result = common.run_command(command)
  if not result.ok then
    return nil, 'cannot collect lua files from: ' .. normalized_root
  end
  local files = {}
  for line in (result.output .. "\n"):gmatch("(.-)\n") do
    if line ~= "" then
      files[#files + 1] = common.normalize_path(line)
    end
  end
  table.sort(files)
  return files
end

return common
