-- 文件系统 IO:读写文件、建删目录、拷贝。
--
-- 测试正是靠替换 foundation.fs.path_exists 这类字段来控制环境分支的。
-- 那个替身注入点在**调用方**边界上——调用方直接 require 本模块的表,字段可整体替换。
-- 但注意:本模块内部互调走 fs.xxx,替身穿不进来,别指望 stub fs.path_exists 能改掉
-- fs.remove_path 的行为。
--
-- 工具链只跑在 macOS 与 WSL Ubuntu 上(工单 #127 / #129;#127 平台约束),所以只有 POSIX 一条路径。
local text_lib = require("foundation.text")
local path_lib = require("foundation.path")
local shell_lib = require("foundation.shell")

local fs = {}

function fs.read_raw(path)
  local file = io.open(path, "rb")
  if file == nil then
    return nil
  end
  local content = file:read("*a")
  file:close()
  return content
end

local function _write_raw_file(path, content, mode)
  local file = io.open(path, mode or "wb")
  if file == nil then
    return nil
  end
  file:write(content)
  file:close()
  return true
end

function fs.read_file(path)
  local normalized = path_lib.normalize_path(path)
  local content = fs.read_raw(normalized)
  if content ~= nil then
    return content
  end
  return nil, text_lib.bilingual_with_suffix("无法打开文件: ", "Cannot open file: ", path)
end

function fs.ensure_dir(path)
  if path == nil or path == "" then
    return true
  end

  local normalized = path_lib.normalize_path(path)
  local command = "mkdir -p " .. shell_lib.shell_quote(normalized)
  local ok, kind, code = os.execute(command)
  local success = shell_lib.exit_status(ok, kind, code)
  if not success then
    return nil, text_lib.bilingual_with_suffix("创建目录失败: ", "Failed to create directory: ", path)
  end
  return true
end

function fs.ensure_parent_dir(path)
  return fs.ensure_dir(path_lib.parent_dir(path))
end

-- write_file / append_file 只差一个写入模式。差异参数化,流程只留一份。
local function _write_file_with_mode(path, content, mode)
  local ok, err = fs.ensure_parent_dir(path)
  if not ok then
    return nil, err
  end

  local appending = mode == "append"
  local normalized = path_lib.normalize_path(path)
  local write_ok = _write_raw_file(normalized, tostring(content or ""), appending and "ab" or "wb")
  if write_ok == nil then
    return nil, text_lib.bilingual_with_suffix(
      "无法" .. (appending and "追加" or "写入") .. "文件: ",
      "Cannot " .. (appending and "append" or "write") .. " file: ",
      path
    )
  end
  return true
end

function fs.write_file(path, content)
  return _write_file_with_mode(path, content, "write")
end

function fs.append_file(path, content)
  return _write_file_with_mode(path, content, "append")
end

-- path_exists / is_dir 只差一个判定谓词(存在 vs 是目录)。
--
-- 必须显式收成一个布尔再 return:exit_status 返回 (成功, 退出码),
-- 先前两个函数都直接 `return exit_status(...)`,于是谓词实际返回 (true, 0)
-- ——两个值。verify_full 和 packages/luaunit_runner/lua54.lua 里的
-- _path_or_command_available 又原样 `return fs_lib.path_exists(text)`,把这对值
-- 继续往上传。谓词就该只答"是/否"。
local function _probe_path(path, posix_flag)
  local normalized = path_lib.normalize_path(path)
  local command = "[ " .. posix_flag .. " " .. shell_lib.shell_quote(normalized) .. " ]"
  local ok, kind, code = os.execute(command)
  local success = shell_lib.exit_status(ok, kind, code)
  return success
end

function fs.path_exists(path)
  return _probe_path(path, "-e")
end

function fs.is_dir(path)
  return _probe_path(path, "-d")
end

function fs.remove_path(path)
  if not fs.path_exists(path) then
    return true
  end

  local normalized = path_lib.normalize_path(path)
  local command = "rm -rf " .. shell_lib.shell_quote(normalized)
  local ok, kind, code = os.execute(command)
  local success = shell_lib.exit_status(ok, kind, code)
  if not success then
    return nil, text_lib.bilingual_with_suffix("删除路径失败: ", "Failed to remove path: ", path)
  end
  return true
end

function fs.copy_file(source_path, target_path)
  local ok, err = fs.ensure_parent_dir(target_path)
  if not ok then
    return nil, err
  end
  local source_text, read_err = fs.read_file(source_path)
  if source_text == nil then
    return nil, read_err
  end
  return fs.write_file(target_path, source_text)
end

function fs.copy_tree(source_path, target_path)
  local normalized_source = path_lib.normalize_path(source_path)
  local normalized_target = path_lib.normalize_path(target_path)
  local removed, remove_err = fs.remove_path(normalized_target)
  if not removed then
    return nil, remove_err
  end

  local ok, err = fs.ensure_parent_dir(normalized_target)
  if not ok then
    return nil, err
  end

  local command = "cp -R "
    .. shell_lib.shell_quote(normalized_source)
    .. " "
    .. shell_lib.shell_quote(normalized_target)
  local exec_ok, kind, code = os.execute(command)
  local success, exit_code = shell_lib.exit_status(exec_ok, kind, code)
  if not success then
    return nil, text_lib.bilingual_with_suffix(
      "目录拷贝失败，退出码: ",
      "Copy tree failed with exit code: ",
      exit_code
    )
  end
  return true
end

return fs
