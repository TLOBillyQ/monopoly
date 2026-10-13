-- Deploy lane (map #1 / #23 / #73):这是仓库内唯一部署脚本的 Lua 等价实现,把 payload
-- 按原样拷到本地 Eggy 目录。无 build-mode 概念;release 裁切是人工步骤,无专用脚本。
--
-- 行为真源:本文件自身(deploy.lua)。历史来源 deploy.ps1(373 行)已随 #384 删除,
-- 整体由本文件取代(ADR 0030);正文中 deploy.ps1 行号仅作历史坐标保留。
-- 仅支持原生 Windows(ADR 0066 / #95),以 Lua 5.4 标准库和 cmd 原生命令
-- 保留目标解析、目录镜像与逐文件复制语义;不加载额外文件系统依赖。
--
-- CLI 面:零参数、零开关、无 --help(继承被取代的 deploy.ps1 空 param(),#384);任何参数 → ERROR + exit 1。
-- 子命令入口:lua tools/cli.lua deploy 经 tools/packages/ops/cli.lua 壳转发,仅 --help/-h 在壳内
-- 消费返回 usage,其余参数原样透传,本语义不变。

local M = {}

local function _trim(value)
  return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function _is_blank(value)
  return _trim(value) == ""
end

local function _normalize_path(value)
  return tostring(value or ""):gsub("\\", "/")
end

-- 原生运行平台以 Lua 的路径分隔符判定。
local function _actual_is_windows()
  return package.config:sub(1, 1) == "\\"
end

local function _exit_status(ok, _, code)
  if type(ok) == "number" then
    return ok == 0, ok
  end
  if ok == true then
    return true, code or 0
  end
  return false, code or 1
end

local function _popen(command)
  local handle = io.popen(command, "r")
  if handle == nil then
    return ""
  end
  local output = handle:read("*a") or ""
  handle:close()
  return output
end

local function _current_dir()
  return _normalize_path(_trim(_popen("chcp 65001 >nul & cd")))
end

-- cmd 路径参数;拒绝引号、变量展开与换行,避免路径被解释成命令。
local function _cmd_arg(value)
  local text = tostring(value or ""):gsub("/", "\\")
  assert(not text:find('["\r\n%%!]'), "Unsupported command path")
  return '"' .. text .. '"'
end

local function _path_exists(path)
  if path == nil or path == "" then
    return false
  end
  local ok, kind, code = os.execute("if exist " .. _cmd_arg(path) .. " (exit /b 0) else (exit /b 1)")
  return _exit_status(ok, kind, code)
end

local function _path_is_dir(path)
  if path == nil or path == "" then
    return false
  end
  local ok, kind, code = os.execute("if exist " .. _cmd_arg(path .. "/") .. " (exit /b 0) else (exit /b 1)")
  return _exit_status(ok, kind, code)
end

local function _path_is_file(path)
  if path == nil or path == "" then
    return false
  end
  local ok, kind, code = os.execute(
    "if exist " .. _cmd_arg(path)
      .. " (if not exist " .. _cmd_arg(path .. "/")
      .. " (exit /b 0) else (exit /b 1)) else (exit /b 1)"
  )
  return _exit_status(ok, kind, code)
end

local function _ensure_dir(path)
  if path == nil or path == "" then
    return true
  end
  local ok, kind, code = os.execute("if not exist " .. _cmd_arg(path) .. " mkdir " .. _cmd_arg(path))
  local success = _exit_status(ok, kind, code)
  if not success then
    error("Failed to create directory: " .. tostring(path))
  end
  return true
end

local function _remove_path(path)
  if not _path_exists(path) then
    return true
  end
  local ok, kind, code
  if _path_is_dir(path) then
    ok, kind, code = os.execute("rmdir /s /q " .. _cmd_arg(path))
  else
    ok, kind, code = os.execute("del /f /q " .. _cmd_arg(path))
  end
  local success = _exit_status(ok, kind, code)
  if not success then
    error("Failed to remove path: " .. tostring(path))
  end
  return true
end

local function _command_available(name)
  local command = "where " .. tostring(name) .. " >nul 2>&1"
  local ok, kind, code = os.execute(command)
  return _exit_status(ok, kind, code)
end

local function _join_path(...)
  local result = ""
  for index = 1, select("#", ...) do
    local segment = _normalize_path(select(index, ...))
    if result == "" then
      result = segment
    elseif segment ~= "" then
      result = result:gsub("/+$", "") .. "/" .. segment:gsub("^/+", "")
    end
  end
  return result
end

-- GetFullPath 等价(绝对路径的 . 与 .. 折叠);resolve_normalized_path 在调用前
-- 已保证 candidate 绝对化,这里只做演算。

-- 拆出路径前缀:Windows 盘符(如 "C:")、POSIX 根 "/"、或空(相对路径)。
local function _split_path_prefix(normalized)
  if normalized:match("^%a:/") then
    return normalized:sub(1, 3), normalized:sub(4)
  end
  if normalized:sub(1, 1) == "/" then
    return "/", normalized:sub(2)
  end
  return "", normalized
end

-- 折叠 "." 与 ".." 段:相对路径(prefix == "")保留前导 "..",绝对路径在根处截断。
local function _fold_path_segments(remainder, keep_leading_dotdot)
  local parts = {}
  for segment in (remainder .. "/"):gmatch("(.-)/") do
    if segment ~= "" and segment ~= "." then
      if segment == ".." then
        if #parts > 0 and parts[#parts] ~= ".." then
          parts[#parts] = nil
        elseif keep_leading_dotdot then
          parts[#parts + 1] = segment
        end
      else
        parts[#parts + 1] = segment
      end
    end
  end
  return table.concat(parts, "/")
end

-- 前缀与折叠后的段重拼:空段时根 "/" 折叠回 "/",盘符前缀原样返回。
local function _reassemble_path(prefix, simplified)
  if prefix == "" then
    return simplified
  end
  if simplified == "" then
    return prefix == "/" and "/" or prefix
  end
  return prefix == "/" and "/" .. simplified or prefix .. simplified
end

local function _simplify_path(value)
  local normalized = _normalize_path(value)
  local prefix, remainder = _split_path_prefix(normalized)
  return _reassemble_path(prefix, _fold_path_segments(remainder, prefix == ""))
end

local function _get_full_path(value)
  return _simplify_path(value)
end

local function _is_path_rooted(value)
  local normalized = _normalize_path(value)
  return normalized:match("^%a:") ~= nil or normalized:match("^[/\\]") ~= nil
end

-- .NET ExpandEnvironmentVariables 等价:%NAME% 展开,未定义变量原样保留。
local function _expand_environment_variables(value)
  return (tostring(value or ""):gsub("%%([^%%]+)%%", function(name)
    local env_value = os.getenv(name)
    if env_value == nil then
      return "%" .. name .. "%"
    end
    return env_value
  end))
end

local function _script_path()
  local source = debug.getinfo(1, "S").source or ""
  local value = _normalize_path(tostring(source):gsub("^@", ""))
  if value == "" then
    value = tostring(arg and arg[0] or "")
  end
  if not _is_path_rooted(value) then
    value = _join_path(_current_dir(), value)
  end
  return value
end

local function _script_dir()
  local script = _script_path()
  return script:match("^(.*)/[^/]+$") or _current_dir()
end

-- 文本 / 输出 / 错误工具(Get-Text / Write-Info / Exit-WithError 等价)。

function M.get_text(zh, en)
  return tostring(zh or "") .. " / " .. tostring(en or "")
end

function M.write_info(message)
  io.stdout:write(tostring(message or ""), "\n")
end

function M.exit_with_error(message)
  io.stderr:write("ERROR: " .. tostring(message or ""), "\n")
  os.exit(1)
end

-- 路径工具。

function M.normalize_path_text(value)
  return _normalize_path(value)
end

function M.resolve_home_dir()
  local home = os.getenv("HOME")
  if not _is_blank(home) then
    return M.normalize_path_text(home)
  end
  local user_profile = os.getenv("USERPROFILE")
  if not _is_blank(user_profile) then
    return M.normalize_path_text(user_profile)
  end
  return ""
end

function M.resolve_normalized_path(path_text)
  if _is_blank(path_text) then
    return ""
  end

  local candidate = _expand_environment_variables(tostring(path_text))
  if candidate:sub(1, 2) == "~/" or candidate:sub(1, 2) == "~\\" then
    candidate = _join_path(M.resolve_home_dir(), candidate:sub(3))
  end
  if not _is_path_rooted(candidate) then
    candidate = _join_path(_current_dir(), candidate)
  end
  local full = M.normalize_path_text(_get_full_path(candidate))
  return (full:gsub("/+$", ""))
end

-- 平台判定入口。

function M.test_is_windows_host()
  return _actual_is_windows()
end

function M.resolve_platform_name()
  if M.test_is_windows_host() then
    return "win"
  end
  M.exit_with_error("Deploy target is Windows only; run on native Windows.")
end

function M.join_lua_source_dir_name()
  -- "大富翁" = U+5927 U+5BCC U+7FC1(UTF-8),等价历史来源 deploy.ps1 的 [char]0x5927 拼接(已随 #384 删除)。
  return "LuaSource_" .. string.char(0xE5, 0xA4, 0xA7, 0xE5, 0xAF, 0x8C, 0xE7, 0xBF, 0x81)
end

function M.resolve_default_target_path(resolved_platform)
  local home_dir = M.resolve_home_dir()
  if _is_blank(home_dir) then
    M.exit_with_error("Cannot resolve home directory for default deploy target.")
  end

  if resolved_platform == "win" then
    return M.resolve_normalized_path(
      _join_path(_join_path(_join_path(_join_path(home_dir, "Desktop"), "dev"), "eggy"), M.join_lua_source_dir_name())
    )
  end
  M.exit_with_error("No default deploy target is configured for this platform.")
end

function M.test_project_root(path_text)
  return _path_is_file(_join_path(path_text, "main.lua"))
    and _path_is_dir(_join_path(path_text, "src"))
    and _path_is_dir(_join_path(path_text, "tools"))
end

function M.resolve_project_root()
  local candidates = {
    _get_full_path(_join_path(_script_dir(), "../../..")),
    _current_dir(),
  }

  for _, candidate in ipairs(candidates) do
    if not _is_blank(candidate) and M.test_project_root(candidate) then
      return M.resolve_normalized_path(candidate)
    end
  end

  return M.resolve_normalized_path(candidates[1])
end

function M.reset_directory(path_text)
  if _path_exists(path_text) then
    _remove_path(path_text)
  end
  _ensure_dir(path_text)
end

-- dir /a 包含隐藏项;同一 cmd 进程先选 UTF-8,保留中文文件名。
local function _list_names(path, win_switch)
  local output = _popen("chcp 65001 >nul & dir /b " .. win_switch .. " " .. _cmd_arg(path) .. " 2>nul")
  local names = {}
  for line in (output .. "\n"):gmatch("(.-)\n") do
    local name = line:gsub("\r$", "")
    if name ~= "" and name ~= "." and name ~= ".." then
      names[#names + 1] = name
    end
  end
  return names
end

local function _list_files(path)
  return _list_names(path, "/a-d")
end

local function _list_dirs(path)
  return _list_names(path, "/ad")
end

-- 枚举源目录全部条目(含隐藏文件);目录缺失按 PowerShell Get-ChildItem 语义抛错,
-- 由主流程 catch 收成 ERROR + exit 1。
local function _list_entries(path)
  if not _path_exists(path) then
    error("Path does not exist: " .. tostring(path))
  end
  local entries = {}
  for _, name in ipairs(_list_files(path)) do
    entries[#entries + 1] = { name = name, is_dir = false }
  end
  for _, name in ipairs(_list_dirs(path)) do
    entries[#entries + 1] = { name = name, is_dir = true }
  end
  return entries
end

local function _collect_lua_files(path, result)
  for _, entry in ipairs(_list_entries(path)) do
    local full = _join_path(path, entry.name)
    if entry.is_dir then
      _collect_lua_files(full, result)
    elseif entry.name:lower():match("%.lua$") ~= nil then
      result[#result + 1] = full
    end
  end
  return result
end

local function _copy_file_bytes(source, target)
  local in_file, in_err = io.open(source, "rb")
  if in_file == nil then
    error("Cannot open source file: " .. tostring(source) .. " (" .. tostring(in_err or "") .. ")")
  end
  local out_file, out_err = io.open(target, "wb")
  if out_file == nil then
    in_file:close()
    error("Cannot open target file: " .. tostring(target) .. " (" .. tostring(out_err or "") .. ")")
  end
  for chunk in in_file:lines(65536) do
    out_file:write(chunk)
  end
  in_file:close()
  out_file:close()
  return true
end

local function _copy_entry_recursive(source, target)
  if _path_is_dir(source) then
    _ensure_dir(target)
    for _, entry in ipairs(_list_entries(source)) do
      _copy_entry_recursive(_join_path(source, entry.name), _join_path(target, entry.name))
    end
  else
    _copy_file_bytes(source, target)
  end
end

-- robocopy /MIR 增量镜像;退出码 0-7 成功,>=8 或不可用时逐文件回退。
local function _run_robocopy(program, source, target, redirect)
  local robo_flags = "/MIR /NFL /NDL /NJH /NJS /NP /R:2 /W:1"
  local ok, kind, code = os.execute(
    program
      .. " "
      .. _cmd_arg(source)
      .. " "
      .. _cmd_arg(target)
      .. " "
      .. robo_flags
      .. " "
      .. redirect
  )
  local _, exit_code = _exit_status(ok, kind, code)
  return exit_code < 8
end

local function _try_robocopy_mirror(source_dir, target_dir)
  if _command_available("robocopy") then
    return _run_robocopy("robocopy", source_dir, target_dir, ">nul 2>&1")
  end
  return false
end

function M.copy_directory_tree(source_dir, target_dir)
  if not _path_is_dir(source_dir) then
    error("Source directory does not exist: " .. tostring(source_dir))
  end
  if _try_robocopy_mirror(source_dir, target_dir) then
    return
  end

  M.reset_directory(target_dir)
  for _, entry in ipairs(_list_entries(source_dir)) do
    _copy_entry_recursive(_join_path(source_dir, entry.name), _join_path(target_dir, entry.name))
  end
end

function M.copy_file_with_parent_dir(source_path, target_path)
  local target_parent = _normalize_path(target_path):match("^(.*)/[^/]+$")
  if not _is_blank(target_parent) then
    _ensure_dir(target_parent)
  end
  return _copy_file_bytes(source_path, target_path)
end

function M.remove_nested_paths(root_dir, relative_paths)
  for _, relative_path in ipairs(relative_paths or {}) do
    local target = _join_path(root_dir, relative_path)
    if _path_exists(target) then
      _remove_path(target)
    end
  end
end

-- 统计函数。

-- #527:行首块注释(--[[ / --[==[ 等长括号形式)的内部行不是有效代码——
-- 每个 src 文件尾部的 mutate4lua manifest 即此形态,朴素口径曾虚高约 40%。
-- 行内开口(代码行尾的 --[[@as T]] 之类)不做状态跟踪:同仓库内该类注解
-- 均同行闭合,不影响口径。
function M.get_effective_lua_line_count_for_file(path_text)
  if not _path_is_file(path_text) then
    return 0
  end

  local count = 0
  local block_close = nil
  for line in io.lines(path_text) do
    local text = line
    if block_close ~= nil then
      local _, close_end = text:find(block_close, 1, true)
      if close_end == nil then
        text = ""
      else
        text = text:sub(close_end + 1)
        block_close = nil
      end
    end
    local trimmed = _trim(text)
    local _, open_end, equals = trimmed:find("^%-%-%[(=*)%[")
    if open_end ~= nil then
      block_close = "]" .. equals .. "]"
      local _, inline_close_end = trimmed:find(block_close, open_end + 1, true)
      if inline_close_end ~= nil then
        trimmed = _trim(trimmed:sub(inline_close_end + 1))
        block_close = nil
      else
        trimmed = ""
      end
    end
    if trimmed ~= "" and trimmed:sub(1, 2) ~= "--" then
      count = count + 1
    end
  end
  return count
end

function M.get_effective_lua_line_count_for_dir(path_text)
  if not _path_is_dir(path_text) then
    return 0
  end

  local total = 0
  for _, file_path in ipairs(_collect_lua_files(path_text, {})) do
    total = total + M.get_effective_lua_line_count_for_file(file_path)
  end
  return total
end

function M.get_lua_file_count(path_text)
  if not _path_exists(path_text) then
    return 0
  end
  if _path_is_file(path_text) then
    return 1
  end
  return #_collect_lua_files(path_text, {})
end

-- Windows 编码设置(历史坐标 deploy.ps1 #38-50,已随 #384 删除):仅 Windows 宿主上尽力 chcp 65001 +
-- UTF-8 控制台编码;任何失败静默吞掉。Lua 没有 Console 编码的直接等价物,
-- 按行为等价视为尽力而为。
local function _set_windows_encoding()
  if not M.test_is_windows_host() then
    return
  end
  os.execute("chcp 65001 >nul 2>&1")
end

local function _error_text(err)
  if type(err) == "string" then
    return err
  end
  if type(err) == "table" and err.message ~= nil then
    return tostring(err.message)
  end
  return tostring(err)
end

-- 主流程(历史坐标 deploy.ps1 #318-373,已随 #384 删除):顺序与输出逐行复刻。
local function main()
  local project_root = M.resolve_project_root()
  local resolved_platform = M.resolve_platform_name()
  local target_source = M.resolve_default_target_path(resolved_platform)
  local target_path = M.resolve_normalized_path(target_source)

  _ensure_dir(target_path)

  M.write_info("======================================")
  M.write_info("Starting project deployment")
  M.write_info("======================================")
  M.write_info("Project root: " .. tostring(project_root))
  M.write_info("Target path: " .. tostring(target_path))
  M.write_info("Platform: " .. tostring(resolved_platform))
  M.write_info("")
  M.write_info("--------------------------------------")
  M.write_info("Deploy target: " .. tostring(target_path))
  M.write_info("--------------------------------------")

  M.copy_directory_tree(_join_path(project_root, "src"), _join_path(target_path, "src"))
  M.copy_file_with_parent_dir(_join_path(project_root, "main.lua"), _join_path(target_path, "main.lua"))
  M.copy_file_with_parent_dir(
    _join_path(project_root, "Data/UIManagerNodes.lua"),
    _join_path(target_path, "Data/UIManagerNodes.lua")
  )
  M.copy_file_with_parent_dir(
    _join_path(project_root, "Data/Prefab.lua"),
    _join_path(target_path, "Data/Prefab.lua")
  )

  -- 统计读本地源侧:拷贝是 as-is,文件与有效行数量等价。
  local total_files =
    M.get_lua_file_count(_join_path(project_root, "src"))
    + M.get_lua_file_count(_join_path(project_root, "main.lua"))
    + M.get_lua_file_count(_join_path(project_root, "Data/UIManagerNodes.lua"))
    + M.get_lua_file_count(_join_path(project_root, "Data/Prefab.lua"))
  local total_effective_line_count =
    M.get_effective_lua_line_count_for_dir(_join_path(project_root, "src"))
    + M.get_effective_lua_line_count_for_file(_join_path(project_root, "main.lua"))
    + M.get_effective_lua_line_count_for_file(_join_path(project_root, "Data/UIManagerNodes.lua"))
    + M.get_effective_lua_line_count_for_file(_join_path(project_root, "Data/Prefab.lua"))

  M.write_info("")
  M.write_info("Lua Files: " .. tostring(total_files))
  M.write_info("Effective LOC: " .. tostring(total_effective_line_count))
  M.write_info("")
  M.write_info("======================================")
  M.write_info("Deployment completed!")
  M.write_info("  " .. tostring(target_path))
  M.write_info("  Lua Files: " .. tostring(total_files) .. ", Effective LOC: " .. tostring(total_effective_line_count))
  M.write_info("======================================")
  os.exit(0)
end

local function run_cli()
  local extra_args = {}
  for index = 1, #arg do
    extra_args[#extra_args + 1] = arg[index]
  end
  if #extra_args > 0 then
    M.exit_with_error("Unexpected argument: " .. table.concat(extra_args, " "))
  end

  _set_windows_encoding()

  local ok, err = pcall(main)
  if not ok then
    M.exit_with_error(_error_text(err))
  end
  return 0
end

if ... == "tools.packages.ops.deploy" or ... == "packages.ops.deploy" then
  return M
end

os.exit(run_cli())
