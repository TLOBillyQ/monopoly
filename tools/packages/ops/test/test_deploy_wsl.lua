---@diagnostic disable: undefined-global
-- 测试内 stub io.popen / os.execute(W122 read-only global),同 test/log_warns_handler.lua 口径。
-- luacheck: ignore 122
if arg then rawset(arg, 0, "tools/packages/ops/test/test_deploy_wsl.lua") end
require("test.bootstrap").install_package_paths()

-- deploy.lua(story2 deploy_wsl)的聚焦单测:WSL 互操作。覆盖 Test-IsWSLHost 完整
-- 规约、Resolve-WslWindowsHome(cmd.exe 读 %USERPROFILE% → 校验盘符 → wslpath -u)、
-- Convert-ToWindowsPath(wslpath -w)、Resolve-DefaultTargetPath 的 wsl 分支、
-- Copy-DirectoryTree 的 wsl 分支(cmd.exe /c robocopy,退出码 <8 成功、>=8 或
-- 路径转换失败回落逐文件拷贝)。行为真源是 deploy.lua(历史来源 deploy.ps1,已随
-- #384 删除,ADR 0030)。
--
-- 用例策略:host 无关路径全部确定性(模块 stub / io.popen stub / os.execute stub);
-- 依赖真机 WSL 互操作(cmd.exe + wslpath)的用例按环境跳过。
local lu = require("luaunit")
local env_lib = require("foundation.env")
local fs_lib = require("foundation.fs")
local proc_lib = require("foundation.proc")
local deploy = require("tools.packages.ops.deploy")

-- 通用「暂替换目标表字段 → 跑 fn → 恢复」脚手架;deploy 字段 / io.popen /
-- os.execute 三类 stub 共用,避免 save/restore/xpcall 样板重复三份。
local function _with_global_stub(target, field, value, fn)
  local original = target[field]
  target[field] = value
  local ok, err = xpcall(fn, debug.traceback)
  target[field] = original
  if not ok then
    error(err)
  end
end

local function _with_stubbed(field, value, fn)
  _with_global_stub(deploy, field, value, fn)
end

local function _with_sandbox(fn)
  local root = env_lib.make_temp_path("deploy_wsl_spec_", "")
  fs_lib.remove_path(root)
  local ok, err = xpcall(function()
    fn(root)
  end, debug.traceback)
  fs_lib.remove_path(root)
  if not ok then
    error(err)
  end
end

local function _write_file(path, content)
  local ok, err = fs_lib.write_file(path, content)
  if not ok then
    error(err)
  end
end

local function _proc_version_has_microsoft()
  local handle = io.open("/proc/version", "r")
  if handle == nil then
    return false
  end
  local text = handle:read("*a") or ""
  handle:close()
  return text:lower():find("microsoft", 1, true) ~= nil
end

local function _is_wsl()
  local distro = os.getenv("WSL_DISTRO_NAME")
  if distro ~= nil and tostring(distro):gsub("^%s+", ""):gsub("%s+$", "") ~= "" then
    return true
  end
  return _proc_version_has_microsoft()
end

-- io.popen 假句柄:read("*a") 一次吐完整输出,后续返回 nil 模拟 EOF。
local function _fake_handle(output)
  local handle = { _output = output, _exhausted = false }
  function handle:read()
    if self._exhausted then
      return nil
    end
    self._exhausted = true
    return self._output
  end
  function handle:close()
  end
  return handle
end

local function _with_io_popen_stub(fake_fn, fn)
  _with_global_stub(io, "popen", function(command, mode)
    return fake_fn(tostring(command or ""), mode)
  end, fn)
end

-- os.execute stub:stub_fn(command, original_execute) 决定返回值;非拦截命令可
-- 转调 original 保持真实文件系统行为。
local function _with_os_execute_stub(stub_fn, fn)
  local original = os.execute
  _with_global_stub(os, "execute", function(command)
    return stub_fn(tostring(command or ""), original)
  end, fn)
end

-- 子进程跑 deploy.lua 的 test_is_wsl_host,env 由调用方控制(env 命令可设/可删
-- 变量;Lua 进程内无法 setenv)。cwd 必须是仓根(default package.path 的 ./?.lua)。
local _DRIVER_EXPR =
  "local deploy = require('tools.packages.ops.deploy'); io.write(deploy.test_is_wsl_host() and '1' or '0')"

local function _run_wsl_host_driver(env_pairs, unset)
  local args = { "env" }
  for _, name in ipairs(unset or {}) do
    args[#args + 1] = "-u"
    args[#args + 1] = name
  end
  for _, pair in ipairs(env_pairs or {}) do
    args[#args + 1] = pair[1] .. "=" .. pair[2]
  end
  args[#args + 1] = "lua"
  args[#args + 1] = "-e"
  args[#args + 1] = _DRIVER_EXPR
  return proc_lib.run_command(args, { cwd = env_lib.current_dir() })
end

TestDeployWslHost = {}

function TestDeployWslHost:test_wsl_host_false_when_windows_host()
  _with_stubbed("test_is_windows_host", function()
    return true
  end, function()
    lu.assertIs(deploy.test_is_wsl_host(), false)
  end)
end

function TestDeployWslHost:test_wsl_host_true_when_distro_env_set()
  -- WSL_DISTRO_NAME 非空白 → true,在任何非 Windows POSIX 宿主上都成立。
  local result = _run_wsl_host_driver({ { "WSL_DISTRO_NAME", "Ubuntu" } }, {})
  lu.assertIs(result.ok, true, "driver must run: " .. tostring(result.output))
  lu.assertIs(result.output, "1")
end

function TestDeployWslHost:test_wsl_host_matches_proc_version_without_env()
  -- 删掉 WSL_DISTRO_NAME 后,结果只取决于 /proc/version 是否含 microsoft。
  local expected = _proc_version_has_microsoft()
  local result = _run_wsl_host_driver({}, { "WSL_DISTRO_NAME" })
  lu.assertIs(result.ok, true, "driver must run: " .. tostring(result.output))
  lu.assertIs(result.output, expected and "1" or "0")
end

function TestDeployWslHost:test_wsl_host_matches_environment()
  -- 当前宿主一致性回归钉(等价 test_deploy.lua 的 _is_wsl 口径)。
  lu.assertIs(deploy.test_is_wsl_host(), _is_wsl())
end

TestDeployWslWindowsHome = {}

function TestDeployWslWindowsHome:test_returns_empty_when_cmd_unavailable()
  _with_io_popen_stub(function()
    return nil
  end, function()
    lu.assertIs(deploy.resolve_wsl_windows_home(), "")
  end)
end

function TestDeployWslWindowsHome:test_returns_empty_when_profile_not_drive_letter()
  -- cmd.exe 输出 C:/Users/alice(前斜杠)→ 不匹配 ^[A-Za-z]:\,不再调 wslpath。
  local calls = 0
  _with_io_popen_stub(function()
    calls = calls + 1
    return _fake_handle("C:/Users/alice\r\n")
  end, function()
    lu.assertIs(deploy.resolve_wsl_windows_home(), "")
    lu.assertIs(calls, 1)
  end)
end

function TestDeployWslWindowsHome:test_returns_empty_when_wslpath_output_blank()
  local outputs = { "C:\\Users\\alice\r\n", "" }
  local index = 0
  _with_io_popen_stub(function()
    index = index + 1
    return _fake_handle(outputs[index] or "")
  end, function()
    lu.assertIs(deploy.resolve_wsl_windows_home(), "")
  end)
end

function TestDeployWslWindowsHome:test_resolves_mnt_path_from_valid_profile()
  local outputs = { "C:\\Users\\alice\r\n", "/mnt/c/Users/alice\n" }
  local index = 0
  _with_io_popen_stub(function()
    index = index + 1
    return _fake_handle(outputs[index] or "")
  end, function()
    lu.assertIs(deploy.resolve_wsl_windows_home(), "/mnt/c/Users/alice")
  end)
end

function TestDeployWslWindowsHome:test_real_wsl_interop_when_available()
  if not (_is_wsl() and proc_lib.command_exists("cmd.exe") and proc_lib.command_exists("wslpath")) then
    return
  end
  local win_home = deploy.resolve_wsl_windows_home()
  lu.assertEvalToTrue(win_home:match("^/mnt/%a/Users/") ~= nil,
    "win_home must be a /mnt drive path under C:\\Users: " .. tostring(win_home))
  local home = os.getenv("HOME")
  if home ~= nil and tostring(home):gsub("^%s+", ""):gsub("%s+$", "") ~= "" then
    lu.assertIs(win_home == deploy.normalize_path_text(home), false,
      "win_home must not be the WSL $HOME: " .. tostring(win_home))
  end
end

TestDeployConvertToWindowsPath = {}

function TestDeployConvertToWindowsPath:test_returns_empty_when_wslpath_unavailable()
  _with_io_popen_stub(function()
    return nil
  end, function()
    lu.assertIs(deploy.convert_to_windows_path("/mnt/c/Users/alice/Desktop"), "")
  end)
end

function TestDeployConvertToWindowsPath:test_returns_first_line_trimmed()
  _with_io_popen_stub(function()
    return _fake_handle("C:\\Users\\alice\\Desktop\r\n")
  end, function()
    lu.assertIs(
      deploy.convert_to_windows_path("/mnt/c/Users/alice/Desktop"),
      "C:\\Users\\alice\\Desktop"
    )
  end)
end

function TestDeployConvertToWindowsPath:test_real_wslpath_when_available()
  if not (_is_wsl() and proc_lib.command_exists("wslpath")) then
    return
  end
  local win_home = deploy.resolve_wsl_windows_home()
  if win_home == "" then
    return
  end
  local converted = deploy.convert_to_windows_path(win_home)
  lu.assertEvalToTrue(converted:match("^%a:\\") ~= nil,
    "converted must be a Windows drive path: " .. tostring(converted))
end

TestDeployDefaultTargetWsl = {}

function TestDeployDefaultTargetWsl:test_wsl_branch_uses_windows_home_desktop_dev()
  _with_stubbed("resolve_home_dir", function()
    return "/home/alice"
  end, function()
    _with_stubbed("resolve_wsl_windows_home", function()
      return "/mnt/c/Users/alice"
    end, function()
      lu.assertIs(
        deploy.resolve_default_target_path("wsl"),
        "/mnt/c/Users/alice/Desktop/dev/" .. deploy.join_lua_source_dir_name()
      )
    end)
  end)
end

function TestDeployDefaultTargetWsl:test_wsl_branch_errors_when_windows_home_missing()
  local captured = nil
  _with_stubbed("resolve_home_dir", function()
    return "/home/alice"
  end, function()
    _with_stubbed("resolve_wsl_windows_home", function()
      return ""
    end, function()
      _with_stubbed("exit_with_error", function(message)
        captured = message
      end, function()
        deploy.resolve_default_target_path("wsl")
      end)
    end)
  end)
  lu.assertEvalToTrue(
    tostring(captured):find("Cannot resolve Windows host home from WSL (need cmd.exe + wslpath interop).", 1, true) ~= nil,
    "wsl branch must error when windows home cannot be resolved: " .. tostring(captured)
  )
end

function TestDeployDefaultTargetWsl:test_wsl_branch_errors_when_windows_home_blank()
  local captured = nil
  _with_stubbed("resolve_home_dir", function()
    return "/home/alice"
  end, function()
    _with_stubbed("resolve_wsl_windows_home", function()
      return "   "
    end, function()
      _with_stubbed("exit_with_error", function(message)
        captured = message
      end, function()
        deploy.resolve_default_target_path("wsl")
      end)
    end)
  end)
  lu.assertEvalToTrue(
    tostring(captured):find("Cannot resolve Windows host home from WSL", 1, true) ~= nil,
    "blank win_home must follow the same error path: " .. tostring(captured)
  )
end

TestDeployCopyDirectoryTreeWsl = {}

local function _make_src_tree(root)
  local source = root .. "/src"
  fs_lib.ensure_dir(source .. "/sub")
  _write_file(source .. "/a.lua", "local a = 1\n")
  _write_file(source .. "/sub/b.lua", "local b = 1\n")
  _write_file(source .. "/.hidden", "hidden\n")
  return source
end

local function _stub_wsl_platforms(fn)
  _with_stubbed("test_is_windows_host", function()
    return false
  end, function()
    _with_stubbed("test_is_wsl_host", function()
      return true
    end, fn)
  end)
end

function TestDeployCopyDirectoryTreeWsl:test_falls_back_when_path_conversion_fails()
  _with_sandbox(function(root)
    local source = _make_src_tree(root)
    local target = root .. "/target/src"
    _stub_wsl_platforms(function()
      _with_stubbed("convert_to_windows_path", function()
        return ""
      end, function()
        deploy.copy_directory_tree(source, target)
      end)
    end)
    lu.assertIs(fs_lib.read_raw(target .. "/a.lua"), "local a = 1\n")
    lu.assertIs(fs_lib.read_raw(target .. "/sub/b.lua"), "local b = 1\n")
    lu.assertIs(fs_lib.read_raw(target .. "/.hidden"), "hidden\n")
  end)
end

function TestDeployCopyDirectoryTreeWsl:test_falls_back_when_robocopy_fails()
  _with_sandbox(function(root)
    local source = _make_src_tree(root)
    local target = root .. "/target/src"
    local robocopy_calls = 0
    _stub_wsl_platforms(function()
      _with_stubbed("convert_to_windows_path", function(path_text)
        return "C:\\fake" .. tostring(path_text)
      end, function()
        _with_os_execute_stub(function(command, original)
          if command:find("robocopy", 1, true) ~= nil then
            robocopy_calls = robocopy_calls + 1
            return false, "exit", 16
          end
          if command:find("command -v cmd.exe", 1, true) ~= nil then
            return true, "exit", 0
          end
          return original(command)
        end, function()
          deploy.copy_directory_tree(source, target)
        end)
      end)
    end)
    lu.assertIs(robocopy_calls, 1)
    lu.assertIs(fs_lib.read_raw(target .. "/a.lua"), "local a = 1\n")
    lu.assertIs(fs_lib.read_raw(target .. "/sub/b.lua"), "local b = 1\n")
    lu.assertIs(fs_lib.read_raw(target .. "/.hidden"), "hidden\n")
  end)
end

function TestDeployCopyDirectoryTreeWsl:test_robocopy_success_returns_early()
  _with_sandbox(function(root)
    local source = _make_src_tree(root)
    local target = root .. "/target/src"
    local robocopy_calls = {}
    local conversions = {}
    _stub_wsl_platforms(function()
      _with_stubbed("convert_to_windows_path", function(path_text)
        conversions[#conversions + 1] = tostring(path_text)
        return "C:\\fake" .. tostring(path_text)
      end, function()
        _with_os_execute_stub(function(command, original)
          if command:find("robocopy", 1, true) ~= nil then
            robocopy_calls[#robocopy_calls + 1] = command
            return false, "exit", 1
          end
          if command:find("command -v cmd.exe", 1, true) ~= nil then
            return true, "exit", 0
          end
          return original(command)
        end, function()
          deploy.copy_directory_tree(source, target)
        end)
      end)
    end)
    -- 退出码 1(< 8,有文件复制)应直接返回,不再 reset/逐文件拷贝。
    lu.assertIs(#robocopy_calls, 1)
    lu.assertEvalToTrue(robocopy_calls[1]:find("cmd.exe /c robocopy", 1, true) ~= nil,
      "robocopy must be launched via cmd.exe: " .. tostring(robocopy_calls[1]))
    lu.assertEvalToTrue(robocopy_calls[1]:find(">/dev/null 2>&1", 1, true) ~= nil,
      "wsl robocopy stderr/stdout must be discarded on POSIX: " .. tostring(robocopy_calls[1]))
    lu.assertEvalToTrue(robocopy_calls[1]:find(">nul", 1, true) == nil,
      "wsl branch must not use the Windows nul redirect: " .. tostring(robocopy_calls[1]))
    lu.assertIs(#conversions, 2)
    lu.assertIs(conversions[1], source)
    lu.assertIs(conversions[2], target)
    lu.assertIs(fs_lib.path_exists(target), false,
      "successful robocopy must return before the file-by-file fallback")
  end)
end

return TestDeployWslHost
