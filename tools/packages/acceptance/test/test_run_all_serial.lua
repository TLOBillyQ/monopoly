---@diagnostic disable: undefined-global
-- 串行 acceptance 车道的 spawn 契约:
--   * 基础设施错误即便 launcher 静默退出(退出码 127、输出为空)也必须给出非空诊断;
--   * 零用例不得算通过,但不得掩盖上面的基础设施诊断;
--   * 真实失败(有输出、非基础设施错误)保留 output,error 为空;
--   * spawn 走仓库根 cwd + LUA_PATH(生成脚本的相对路径依赖该 cwd)。
require("test.bootstrap").install_package_paths()

local lu = require("luaunit")
local path_lib = require("foundation.path")
local proc_lib = require("foundation.proc")
-- 预热点:解释器探测会 spawn `<candidate> -v`,必须在 stub proc 之前完成,
-- 否则缓存的探测结果会被 stub 污染。
require("packages.luaunit_runner.lua54").lua54_bin()
local bootstrap = require("foundation.bootstrap")
local run_all = require("packages.acceptance.run_all")
local registry = require("packages.acceptance.acceptance_features")

-- 原生 spec 形态:Test* 必须是全局表(runner 靠 _G 增量收集用例)。
TestAcceptanceSerialLane = {}

-- 把 proc.run_command 换成固定结果序列;fn(calls) 里 calls[i] 记录第 i 次调用。
local function _with_stubbed_proc(results, fn)
  local original = proc_lib.run_command
  local index = 0
  local calls = {}
  proc_lib.run_command = function(command, options)
    index = index + 1
    calls[index] = { command = command, options = options }
    return results[index] or results[#results]
  end
  local ok, err = pcall(fn, calls)
  proc_lib.run_command = original
  if not ok then
    error(err, 0)
  end
end

-- 把注册表缩到单条 entry,让 spawn 次数与断言一一对应。
local function _with_single_entry(fn)
  local original = registry.entries
  registry.entries = { { feature = "features/x.feature", generated = "test_x_acceptance.lua" } }
  local ok, err = pcall(fn)
  registry.entries = original
  if not ok then
    error(err, 0)
  end
end

local function _run_serial()
  return run_all.run({ serial = true, generated_dir = "build/acceptance/serial_spec_tmp" })
end

function TestAcceptanceSerialLane:test_silent_launcher_failure_keeps_a_nonempty_diagnostic()
  local summary
  _with_single_entry(function()
    _with_stubbed_proc({ { ok = false, code = 127, output = "" } }, function()
      summary = _run_serial()
    end)
  end)
  lu.assertIs(#summary.failed, 1)
  lu.assertIs(summary.passed, 0)
  lu.assertEvalToTrue(
    summary.failed[1].error:find("lua launcher failed with exit code 127", 1, true) ~= nil,
    "empty launcher output must still name the exit code: " .. summary.failed[1].error
  )
end

function TestAcceptanceSerialLane:test_zero_executed_cases_never_counts_as_passing()
  local summary
  _with_single_entry(function()
    _with_stubbed_proc({ { ok = true, code = 0, output = "0 passed, 0 failed\n" } }, function()
      summary = _run_serial()
    end)
  end)
  lu.assertIs(summary.passed, 0)
  lu.assertIs(#summary.failed, 1)
  lu.assertIs(summary.failed[1].error, "no acceptance cases executed")
end

function TestAcceptanceSerialLane:test_real_failure_keeps_output_without_infrastructure_error()
  local summary
  _with_single_entry(function()
    _with_stubbed_proc({ { ok = false, code = 1, output = "16 passed, 2 failed\n" } }, function()
      summary = _run_serial()
    end)
  end)
  lu.assertIs(#summary.failed, 1)
  lu.assertIs(summary.failed[1].error, "")
  lu.assertEvalToTrue(summary.failed[1].output:find("16 passed, 2 failed", 1, true) ~= nil)
end

function TestAcceptanceSerialLane:test_spawns_from_repo_root_with_project_lua_path()
  local summary, calls
  _with_single_entry(function()
    _with_stubbed_proc({ { ok = true, code = 0, output = "1 passed, 0 failed\n" } }, function(captured)
      calls = captured
      summary = _run_serial()
    end)
  end)
  lu.assertIs(summary.passed, 1)
  lu.assertIs(#calls, 1)

  -- bootstrap 从相对 source 路径解析时给出 "<root>/." 形式,与 run_all 内部的
  -- 绝对解析同指一个目录;归一化后比较。
  local function _strip_dot(path)
    return (tostring(path):gsub("/%.$", ""))
  end
  local repo_root = bootstrap.resolve("tools/packages/acceptance/run_all.lua").repo_root
  lu.assertIs(_strip_dot(calls[1].options.cwd), _strip_dot(repo_root))
  lu.assertEvalToTrue(calls[1].command:find("LUA_PATH=", 1, true) ~= nil, calls[1].command)
  lu.assertEvalToTrue(
    calls[1].command:find(path_lib.join_path("build/acceptance/serial_spec_tmp", "test_x_acceptance.lua"), 1, true) ~= nil,
    calls[1].command
  )
end

return TestAcceptanceSerialLane
