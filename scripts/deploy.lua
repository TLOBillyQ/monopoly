local function _normalize_path(path)
  return tostring(path or ""):gsub("\\", "/")
end

local function _script_dir(script_path)
  local normalized = _normalize_path(script_path)
  return normalized:match("^(.*)/[^/]+$") or "scripts"
end

local _raw_script_path = arg and arg[0] or "scripts/deploy.lua"
local _entry_script_dir = _script_dir(_raw_script_path)
local _entry_parent_dir = _entry_script_dir:match("^(.*)/[^/]+$") or "."
package.path = _entry_script_dir .. "/?.lua;"
  .. _entry_script_dir .. "/?/?.lua;"
  .. _entry_parent_dir .. "/?.lua;"
  .. _entry_parent_dir .. "/?/?.lua;"
  .. package.path

local bootstrap = require("bootstrap")
local env = bootstrap.install(_raw_script_path)
local common = require("lib.common")
local loc_counter = require("lib.loc_counter")

local function _fail(message)
  io.stderr:write("✗ " .. tostring(message) .. "\n")
  os.exit(1)
end

local function _println(message)
  print(tostring(message or ""))
end

local function _default_sync_target_path()
  if common.is_windows() then
    return "C:/Users/Lzx_8/Desktop/dev/LuaSource_大富翁-开发"
  end
  if common.is_macos() then
    return "/Users/billyq/Documents/eggy/LuaSource_大富翁-开发"
  end
  _fail("当前平台未配置默认同步目录，请先使用 --target-path 指定路径。")
end

local function _normalize_target_path(path)
  local normalized = common.normalize_path(path):gsub("/+$", "")
  if normalized == "" then
    return normalized
  end
  return common.resolve_path(common.current_dir(), normalized)
end

local function _forbidden_deploy_target(path)
  for _, segment in ipairs(common.split(common.normalize_path(path), "/")) do
    if segment ~= "" and segment:find("发布", 1, true) ~= nil then
      return true
    end
  end
  return false
end

local function _escape_lua_string_double_quoted(text)
  local value = tostring(text or "")
  value = value:gsub("\\", "\\\\")
  value = value:gsub('"', '\\"')
  return value
end

local function _write_main_lua(source_path, target_path, startup_profile)
  local source_text, err = common.read_file(source_path)
  if source_text == nil then
    return nil, err
  end
  if startup_profile == nil or tostring(startup_profile) == "" then
    return common.write_file(target_path, source_text)
  end
  local prefix = 'STARTUP_TEST_PROFILE = "' .. _escape_lua_string_double_quoted(startup_profile) .. '"\n'
  return common.write_file(target_path, prefix .. source_text)
end

local function _count_directory_lua_lines(root)
  local files, err = common.collect_lua_files(root)
  if files == nil then
    return nil, err
  end
  local total = 0
  for _, path in ipairs(files) do
    local count, count_err = loc_counter.count_file(path)
    if count == nil then
      return nil, count_err
    end
    total = total + count
  end
  return total
end

local function _count_file_lua_lines(path)
  if path:match("%.lua$") == nil then
    return 0
  end
  local count, err = loc_counter.count_file(path)
  if count == nil then
    return nil, err
  end
  return count
end

local function _deployment_line_breakdown(target_path, directories, files)
  local breakdown = {}
  for _, dir_name in ipairs(directories or {}) do
    local deployed_dir_path = common.join_path(target_path, dir_name)
    local effective_line_count = 0
    if common.is_dir(deployed_dir_path) then
      local dir_count, err = _count_directory_lua_lines(deployed_dir_path)
      if dir_count == nil then
        return nil, err
      end
      effective_line_count = dir_count
    end
    breakdown[#breakdown + 1] = {
      name = dir_name,
      kind = "Directory",
      effective_lua_line_count = effective_line_count,
    }
  end

  for _, file_info in ipairs(files or {}) do
    local deployed_file_path = common.join_path(target_path, file_info.target)
    local effective_line_count = 0
    if common.path_exists(deployed_file_path) then
      local file_count, err = _count_file_lua_lines(deployed_file_path)
      if file_count == nil then
        return nil, err
      end
      effective_line_count = file_count
    end
    breakdown[#breakdown + 1] = {
      name = file_info.target,
      kind = "File",
      effective_lua_line_count = effective_line_count,
    }
  end

  return breakdown
end

local function _total_line_count(breakdown)
  local total = 0
  for _, entry in ipairs(breakdown or {}) do
    total = total + (entry.effective_lua_line_count or 0)
  end
  return total
end

local function _parse_args(args)
  local options = {
    startup_profile = nil,
    target_path = nil,
  }
  local index = 1
  while index <= #args do
    local token = args[index]
    if token == "--startup-profile" or token == "-StartupProfile" then
      options.startup_profile = args[index + 1]
      index = index + 2
    elseif token == "--target-path" or token == "-TargetPath" then
      options.target_path = args[index + 1]
      index = index + 2
    elseif token == "--help" or token == "-h" then
      print("Usage: lua scripts/deploy.lua [--target-path PATH|-TargetPath PATH] [--startup-profile NAME|-StartupProfile NAME]")
      os.exit(0)
    else
      _fail("unknown flag: " .. tostring(token))
    end
  end
  return options
end

local function main(args)
  local options = _parse_args(args or {})
  local project_root = env.repo_root
  local target_path = _normalize_target_path(options.target_path or _default_sync_target_path())

  if _forbidden_deploy_target(target_path) then
    _fail("禁止部署到名称包含“发布”的目录: " .. target_path)
  end

  local directories = { "Config", "src" }
  local files = {
    { source = "main.lua", target = "main.lua" },
    { source = "Data/UIManagerNodes.lua", target = "Data/UIManagerNodes.lua" },
    { source = "Data/Prefab.lua", target = "Data/Prefab.lua" },
  }

  _println("======================================")
  _println("开始部署项目文件")
  _println("======================================")
  _println("项目根目录: " .. project_root)
  _println("目标目录: " .. target_path)
  _println("部署模式: 默认同步目录")
  if options.startup_profile == nil or options.startup_profile == "" then
    _println("启动 Profile: default (未注入 STARTUP_TEST_PROFILE)")
  else
    _println("启动 Profile: " .. options.startup_profile)
  end
  _println("")

  local ensure_ok, ensure_err = common.ensure_dir(target_path)
  if not ensure_ok then
    _fail(ensure_err)
  end

  _println("--------------------------------------")
  _println("部署目标: " .. target_path)
  _println("--------------------------------------")

  for _, dir_name in ipairs(directories) do
    local source_path = common.join_path(project_root, dir_name)
    local dest_path = common.join_path(target_path, dir_name)
    if common.is_dir(source_path) then
      _println("正在拷贝目录: " .. dir_name .. " ...")
      _println("  源: " .. source_path)
      _println("  目: " .. dest_path)
      local ok, err = common.copy_tree(source_path, dest_path)
      if not ok then
        _fail(dir_name .. " 拷贝失败: " .. tostring(err))
      end
      _println("✓ " .. dir_name .. " 拷贝成功")
    else
      _println("⚠ 源目录不存在: " .. source_path)
    end
  end

  for _, file_info in ipairs(files) do
    local source_path = common.join_path(project_root, file_info.source)
    local target_file_path = common.join_path(target_path, file_info.target)
    if common.path_exists(source_path) then
      _println("正在拷贝文件: " .. file_info.source .. " ...")
      _println("  源: " .. source_path)
      _println("  目: " .. target_file_path)
      local ok, err = nil, nil
      if file_info.source == "main.lua" then
        ok, err = _write_main_lua(source_path, target_file_path, options.startup_profile)
      else
        ok, err = common.copy_file(source_path, target_file_path)
      end
      if not ok then
        _fail(file_info.source .. " 拷贝失败: " .. tostring(err))
      end
      _println("✓ " .. file_info.source .. " 拷贝成功")
    else
      _println("⚠ 源文件不存在: " .. source_path)
    end
  end

  _println("")
  local breakdown, breakdown_err = _deployment_line_breakdown(target_path, directories, files)
  if breakdown == nil then
    _fail(breakdown_err)
  end
  local total_effective_line_count = _total_line_count(breakdown)
  _println("有效代码行数: " .. tostring(total_effective_line_count))
  for _, entry in ipairs(breakdown) do
    _println("  - " .. tostring(entry.name) .. ": " .. tostring(entry.effective_lua_line_count))
  end
  _println("")

  _println("======================================")
  _println("部署完成！")
  _println("  " .. target_path .. " -> 有效代码行数 " .. tostring(total_effective_line_count))
  for _, entry in ipairs(breakdown) do
    _println("    - " .. tostring(entry.name) .. ": " .. tostring(entry.effective_lua_line_count))
  end
  _println("======================================")

  return 0
end

os.exit(main(arg or {}))
