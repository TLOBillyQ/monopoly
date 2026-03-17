local _raw_script_path = arg and arg[0] or "scripts/ops/deploy.lua"

local bootstrap = require("scripts.shared.bootstrap")
local env = bootstrap.install(_raw_script_path)
local common = require("shared.lib.common")
local loc_counter = require("shared.lib.loc_counter")
local deploy_defaults = require("ops.deploy_defaults")

local function _text(zh, en)
  return common.bilingual(zh, en)
end

local function _fail(message)
  io.stderr:write("✗ " .. tostring(message) .. "\n")
  os.exit(1)
end

local function _println(message)
  print(tostring(message or ""))
end

local function _home_dir()
  return os.getenv("HOME") or os.getenv("USERPROFILE") or ""
end

local function _default_sync_target_path(options)
  local env_target = os.getenv("MONOPOLY_DEPLOY_TARGET")
  if env_target ~= nil and env_target ~= "" then
    return env_target
  end

  local default_target = deploy_defaults.resolve({
    home_dir = _home_dir(),
    is_macos = common.is_macos(),
    is_windows = common.is_windows(),
    mode = options and options.mode or "dev",
  })
  if default_target ~= nil and default_target ~= "" then
    return default_target
  end

  _fail(_text(
    "未配置部署目录，请设置 MONOPOLY_DEPLOY_TARGET、传入 --target-path，或在默认目录下创建 LuaSource_大富翁-开发/发布。",
    "Deploy target is not configured; set MONOPOLY_DEPLOY_TARGET, pass --target-path, or create the default LuaSource_大富翁 dev/release directory."
  ))
end

local function _normalize_target_path(path)
  local normalized = common.normalize_path(path):gsub("/+$", "")
  if normalized == "" then
    return normalized
  end
  return common.resolve_path(common.current_dir(), normalized)
end

local function _escape_lua_string_double_quoted(text)
  local value = tostring(text or "")
  value = value:gsub("\\", "\\\\")
  value = value:gsub('"', '\\"')
  return value
end

local function _read_file_bytes_fast(path)
  local file = io.open(path, "rb")
  if file == nil then
    return nil
  end
  local content = file:read("*a")
  file:close()
  return content
end

local function _os_execute_success(ok, _, code)
  if ok == true and (code == nil or code == 0) then
    return true
  end
  return code == 0
end

local function _write_main_lua(source_path, target_path, startup_profile)
  local source_text, err = common.read_file(source_path)
  if source_text == nil then
    return nil, err
  end
  if startup_profile == nil or tostring(startup_profile) == "" then
    return common.write_file(target_path, source_text)
  end
  local mode = _G and _G.MONO_BUILD_MODE or "dev"
  local prefix = 'MONO_BUILD_MODE = "' .. _escape_lua_string_double_quoted(mode) .. '"\n'
  if startup_profile ~= nil and tostring(startup_profile) ~= "" then
    prefix = prefix .. 'STARTUP_TEST_PROFILE = "' .. _escape_lua_string_double_quoted(startup_profile) .. '"\n'
  end
  return common.write_file(target_path, prefix .. source_text)
end

local function _collect_directory_lua_files(project_root, dir_name)
  if common.command_exists("git") then
    local output_path = common.make_temp_path("deploy_git_ls_files", ".txt")
    local command = common.wrap_command_with_cwd(
      "git ls-files -- " .. common.shell_quote(dir_name) .. " > " .. common.shell_quote(output_path),
      project_root
    )
    local ok, kind, code = os.execute(command)
    local success = _os_execute_success(ok, kind, code)
    if success then
      local output = common.read_file(output_path) or ""
      local files = {}
      for line in (output .. "\n"):gmatch("(.-)\n") do
        local relative_path = common.normalize_path(line)
        if relative_path ~= "" and relative_path:match("%.lua$") ~= nil then
          files[#files + 1] = common.join_path(project_root, relative_path)
        end
      end
      common.remove_path(output_path)
      if #files > 0 then
        table.sort(files)
        return files
      end
    else
      common.remove_path(output_path)
    end
  end

  return common.collect_lua_files(common.join_path(project_root, dir_name))
end

local function _count_directory_lua_lines(project_root, dir_name)
  local files, err = _collect_directory_lua_files(project_root, dir_name)
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
  local content = _read_file_bytes_fast(path)
  if content ~= nil then
    return loc_counter.count_effective_lines(content)
  end
  local count, err = loc_counter.count_file(path)
  if count == nil then
    return nil, err
  end
  return count
end

local function _deployment_line_breakdown(project_root, directories, files, startup_profile)
  local breakdown = {}
  for _, dir_name in ipairs(directories or {}) do
    local source_dir_path = common.join_path(project_root, dir_name)
    local effective_line_count = 0
    if common.is_dir(source_dir_path) then
      local dir_count, err = _count_directory_lua_lines(project_root, dir_name)
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
    local source_file_path = common.join_path(project_root, file_info.source)
    local effective_line_count = 0
    if common.path_exists(source_file_path) then
      local file_count, err = _count_file_lua_lines(source_file_path)
      if file_count == nil then
        return nil, err
      end
      effective_line_count = file_count
      if file_info.source == "main.lua" and startup_profile ~= nil and startup_profile ~= "" then
        effective_line_count = effective_line_count + 1
      end
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

local function _looks_like_project_root(path)
  return common.path_exists(common.join_path(path, "main.lua"))
    and common.is_dir(common.join_path(path, "src"))
    and common.is_dir(common.join_path(path, "scripts"))
end

local function _project_root_from_script_path(script_path)
  local normalized = common.normalize_path(script_path)
  local script_dir = normalized:match("^(.*)/[^/]+$") or ""
  if script_dir == "" then
    return nil
  end
  return common.resolve_path(common.current_dir(), script_dir .. "/../..")
end

local function _resolve_project_root()
  local candidates = {
    _project_root_from_script_path(_raw_script_path),
    common.resolve_path(common.current_dir(), env.repo_root),
    common.current_dir(),
  }

  for _, candidate in ipairs(candidates) do
    if candidate ~= nil and candidate ~= "" and _looks_like_project_root(candidate) then
      return candidate
    end
  end

  return candidates[1] or candidates[2] or candidates[3]
end

local function _should_skip_line_breakdown(options)
  return common.is_windows() and options.mode == "release"
end

local function _parse_args(args)
  local options = {
    mode = "dev",
    startup_profile = nil,
    target_path = nil,
  }
  local index = 1
  while index <= #args do
    local token = args[index]
    if token == "--mode" or token == "-Mode" then
      options.mode = args[index + 1] or "dev"
      index = index + 2
    elseif token == "--startup-profile" or token == "-StartupProfile" then
      options.startup_profile = args[index + 1]
      index = index + 2
    elseif token == "--target-path" or token == "-TargetPath" then
      options.target_path = args[index + 1]
      index = index + 2
    elseif token == "--help" or token == "-h" then
      print(_text(
        "用法: lua scripts/ops/deploy.lua [--mode dev|release|-Mode dev|release] [--target-path PATH|-TargetPath PATH] [--startup-profile NAME|-StartupProfile NAME]",
        "Usage: lua scripts/ops/deploy.lua [--mode dev|release|-Mode dev|release] [--target-path PATH|-TargetPath PATH] [--startup-profile NAME|-StartupProfile NAME]"
      ))
      os.exit(0)
    else
      _fail(_text(
        "未知参数: " .. tostring(token),
        "Unknown flag: " .. tostring(token)
      ))
    end
  end
  if options.mode ~= "dev" and options.mode ~= "release" then
    _fail(_text(
      "无效的 --mode 参数: " .. tostring(options.mode),
      "Invalid --mode value: " .. tostring(options.mode)
    ))
  end
  return options
end

local function main(args)
  local options = _parse_args(args or {})
  local project_root = _resolve_project_root()
  local target_source = options.target_path or _default_sync_target_path(options)
  local target_path = _normalize_target_path(target_source)

  if options.mode == "release" and options.startup_profile ~= nil and options.startup_profile ~= "" then
    _fail(_text(
      "发布部署禁止注入 STARTUP_TEST_PROFILE，请移除 --startup-profile。",
      "Release deploy does not allow STARTUP_TEST_PROFILE injection; remove --startup-profile."
    ))
  end

  local directories = {
    "src",
    "vendor/third_party",
  }
  local files = {
    { source = "main.lua", target = "main.lua" },
    { source = "Data/UIManagerNodes.lua", target = "Data/UIManagerNodes.lua" },
    { source = "Data/Prefab.lua", target = "Data/Prefab.lua" },
  }

  _println("======================================")
  _println(_text("开始部署项目文件", "Starting project deployment"))
  _println("======================================")
  _println(_text("项目根目录: ", "Project root: ") .. project_root)
  _println(_text("目标目录: ", "Target path: ") .. target_path)
  _G.MONO_BUILD_MODE = options.mode
  if options.mode == "release" then
    _println(_text("部署模式: 发布部署", "Deploy mode: release deploy"))
  else
    _println(_text("部署模式: 开发部署", "Deploy mode: dev deploy"))
  end
  if options.startup_profile == nil or options.startup_profile == "" then
    _println(_text(
      "启动 Profile: default（未注入 STARTUP_TEST_PROFILE）",
      "Startup profile: default (STARTUP_TEST_PROFILE not injected)"
    ))
  else
    _println(_text("启动 Profile: ", "Startup profile: ") .. options.startup_profile)
  end
  _println("")

  local ensure_ok, ensure_err = common.ensure_dir(target_path)
  if not ensure_ok then
    _fail(ensure_err)
  end

  _println("--------------------------------------")
  _println(_text("部署目标: ", "Deploy target: ") .. target_path)
  _println("--------------------------------------")

  for _, dir_name in ipairs(directories) do
    local source_path = common.join_path(project_root, dir_name)
    local dest_path = common.join_path(target_path, dir_name)
    if common.is_dir(source_path) then
      _println(_text("正在拷贝目录: ", "Copying directory: ") .. dir_name .. " ...")
      _println("  " .. _text("源", "Source") .. ": " .. source_path)
      _println("  " .. _text("目", "Target") .. ": " .. dest_path)
      local ok, err = common.copy_tree(source_path, dest_path)
      if not ok then
        _fail(_text(
          dir_name .. " 拷贝失败: " .. tostring(err),
          "Failed to copy " .. dir_name .. ": " .. tostring(err)
        ))
      end
      _println("✓ " .. _text(dir_name .. " 拷贝成功", dir_name .. " copied successfully"))
    else
      _println(_text("⚠ 源目录不存在: ", "⚠ Source directory does not exist: ") .. source_path)
    end
  end

  for _, file_info in ipairs(files) do
    local source_path = common.join_path(project_root, file_info.source)
    local target_file_path = common.join_path(target_path, file_info.target)
    if common.path_exists(source_path) then
      _println(_text("正在拷贝文件: ", "Copying file: ") .. file_info.source .. " ...")
      _println("  " .. _text("源", "Source") .. ": " .. source_path)
      _println("  " .. _text("目", "Target") .. ": " .. target_file_path)
      local ok, err = nil, nil
      if file_info.source == "main.lua" then
        ok, err = _write_main_lua(source_path, target_file_path, options.startup_profile)
      else
        ok, err = common.copy_file(source_path, target_file_path)
      end
      if not ok then
        _fail(_text(
          file_info.source .. " 拷贝失败: " .. tostring(err),
          "Failed to copy " .. file_info.source .. ": " .. tostring(err)
        ))
      end
      _println("✓ " .. _text(file_info.source .. " 拷贝成功", file_info.source .. " copied successfully"))
    else
      _println(_text("⚠ 源文件不存在: ", "⚠ Source file does not exist: ") .. source_path)
    end
  end

  _println("")
  local breakdown = {}
  local total_effective_line_count = nil
  if _should_skip_line_breakdown(options) then
    _println(_text(
      "有效代码行数: 跳过（Windows 发布部署避免额外扫描）",
      "Effective LOC: skipped to avoid extra scanning during Windows release deploy"
    ))
    _println("")
  else
    local breakdown_err = nil
    breakdown, breakdown_err = _deployment_line_breakdown(project_root, directories, files, options.startup_profile)
    if breakdown == nil then
      _fail(breakdown_err)
    end
    total_effective_line_count = _total_line_count(breakdown)
    _println(_text("有效代码行数: ", "Effective LOC: ") .. tostring(total_effective_line_count))
    for _, entry in ipairs(breakdown) do
      _println("  - " .. tostring(entry.name) .. ": " .. tostring(entry.effective_lua_line_count))
    end
    _println("")
  end

  _println("======================================")
  _println(_text("部署完成！", "Deployment completed!"))
  local effective_loc_text = total_effective_line_count ~= nil
    and tostring(total_effective_line_count)
    or _text("已跳过统计", "skipped")
  _println("  " .. target_path .. " -> " .. _text("有效代码行数 ", "effective LOC ") .. effective_loc_text)
  for _, entry in ipairs(breakdown or {}) do
    _println("    - " .. tostring(entry.name) .. ": " .. tostring(entry.effective_lua_line_count))
  end
  _println("======================================")

  return 0
end

os.exit(main(arg or {}))
