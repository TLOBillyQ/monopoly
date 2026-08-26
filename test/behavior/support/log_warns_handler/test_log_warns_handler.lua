---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "test/behavior/support/log_warns_handler/test_log_warns_handler.lua") end
require("test.bootstrap").install_package_paths()

local lu = require("luaunit")
local env_lib = require("foundation.env")
local fs_lib = require("foundation.fs")
local path_lib = require("foundation.path")
local proc_lib = require("foundation.proc")
local shell_lib = require("foundation.shell")
-- 驱动 test/log_warns_handler.lua 输出处理器的子进程走 LuaUnit 运行器
-- （argv_prefix 返回 { lua5.4, runner.lua }）。BUSTED_BIN 逃生舱已删
-- 该 argv_prefix 恒为默认后端。
local runner_bin = require("packages.luaunit_runner.lua54")

local project_root = path_lib.normalize_path(env_lib.current_dir())

local function _runner_argv(extra)
  local args = {}
  for _, token in ipairs(runner_bin.argv_prefix()) do
    args[#args + 1] = token
  end
  args[#args + 1] = "--helper=test/helper.lua"
  args[#args + 1] = "--output=test/log_warns_handler.lua"
  for _, value in ipairs(extra or {}) do
    args[#args + 1] = value
  end
  return args
end

local function _cleanup_tmp(tmp_root)
  local ok, err = fs_lib.remove_path(tmp_root)
  if ok == nil then
    error(err)
  end
end

local function _with_tmp(tag, fn)
  local tmp_root = env_lib.make_temp_path("log_warns_handler_" .. tostring(tag or "tmp"), "")
  _cleanup_tmp(tmp_root)
  local ok, err = xpcall(function()
    fn(tmp_root)
  end, debug.traceback)
  _cleanup_tmp(tmp_root)
  if not ok then
    error(err)
  end
end

-- 生成一段 LuaUnit 原生临时 spec(桥接层退场后无 describe/it):必失败的
-- TestNoisy:test_xxx 用 lu.assertTrue 制造 failure,失败消息格式为
-- `<file>:<line>: boom failure\nexpected: true, actual: false`(与旧
-- assert.is_true 的 `Expected to be true, but got:` 形态不同,但 "boom
-- failure" 字样保留在首行,可读性契约不变);print 的 info/warn/诊断行不动。
local function _write_noisy_spec(path)
  local ok, err = fs_lib.write_file(path, table.concat({
    "local lu = require(\"luaunit\")",
    "TestNoisy = {}",
    "function TestNoisy:test_xxx(self)",
    "  print('0 [info] noisy info line')",
    "  print('plain diagnostic line')",
    "  print('0 [warn] custom warning line')",
    "  lu.assertTrue(false, 'boom failure')",
    "end",
    "",
  }, "\n"))
  lu.assertTrue(ok, tostring(err))
end

local function _run_with_handler(spec_path, extra_args)
  local args = _runner_argv(extra_args)
  args[#args + 1] = spec_path
  return proc_lib.run_command(args, { cwd = project_root })
end

local function _run_verbose_drop_info(spec_path)
  local args = _runner_argv({ "-Xoutput", "drop-info" })
  args[#args + 1] = spec_path
  local run_command = shell_lib.build_command(args)
  return proc_lib.run_command("EGGY_TEST_VERBOSE=1 " .. run_command, { cwd = project_root })
end

TestLogWarnsHandler = {}

function TestLogWarnsHandler:test_preserves_captured_info_lines_by_default()
  _with_tmp("default", function(tmp_root)
    local spec_path = path_lib.join_path(tmp_root, "test_noisy.lua")
    _write_noisy_spec(spec_path)

    local result = _run_with_handler(spec_path)

    lu.assertFalse(result.ok)
    lu.assertEvalToTrue(result.output:find("0 %[info%] noisy info line"))
    lu.assertEvalToTrue(result.output:find("plain diagnostic line", 1, true))
    lu.assertEvalToTrue(result.output:find("# WARN 0 [warn] custom warning line", 1, true))
    lu.assertEvalToTrue(result.output:find("boom failure", 1, true))
  end)
end

function TestLogWarnsHandler:test_drops_captured_info_lines_when_requested()
  _with_tmp("drop_info", function(tmp_root)
    local spec_path = path_lib.join_path(tmp_root, "test_noisy.lua")
    _write_noisy_spec(spec_path)

    local result = _run_with_handler(spec_path, { "-Xoutput", "drop-info" })

    lu.assertFalse(result.ok)
    lu.assertNil(result.output:find("0 %[info%] noisy info line"))
    lu.assertEvalToTrue(result.output:find("plain diagnostic line", 1, true))
    lu.assertEvalToTrue(result.output:find("# WARN 0 [warn] custom warning line", 1, true))
    lu.assertEvalToTrue(result.output:find("boom failure", 1, true))
    lu.assertEvalToTrue(result.output:find("1 FAIL", 1, true))
  end)
end

function TestLogWarnsHandler:test_does_not_drop_info_lines_in_verbose_mode()
  _with_tmp("verbose_drop_info", function(tmp_root)
    local spec_path = path_lib.join_path(tmp_root, "test_noisy.lua")
    _write_noisy_spec(spec_path)

    local result = _run_verbose_drop_info(spec_path)

    lu.assertFalse(result.ok)
    lu.assertEvalToTrue(result.output:find("0 %[info%] noisy info line"))
    lu.assertEvalToTrue(result.output:find("not ok 1 -", 1, true))
  end)
end


return TestLogWarnsHandler
