---@diagnostic disable: undefined-global
-- 串行 acceptance 车道的 spawn 契约:
--   * 基础设施错误即便 launcher 静默退出(退出码 127、输出为空)也必须给出非空诊断;
--   * 零用例不得算通过,但不得掩盖上面的基础设施诊断;
--   * 真实失败(有输出、非基础设施错误)保留 output,error 为空;
--   * spawn 走仓库根 cwd + LUA_PATH(生成脚本的相对路径依赖该 cwd)。
require("test.bootstrap").install_package_paths()

local check = require("luassert")
local path_lib = require("foundation.path")
local proc_lib = require("foundation.proc")
-- 预热点:解释器探测会 spawn `<candidate> -v`,必须在 stub proc 之前完成,
-- 否则缓存的探测结果会被 stub 污染。
require("foundation.lua54").lua54_bin()
local bootstrap = require("foundation.bootstrap")
local run_all = require("packages.acceptance.run_all")
local registry = require("packages.acceptance.acceptance_features")

describe("acceptance serial JSON protocol", function()

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

local function _result(cases, passed, failed)
  return require("acceptance4lua.json").encode_compact({ backend = "busted", outcome = failed > 0 and "test_failure" or "test_success", error = "", output = "real busted output", counts = { cases = cases, passed = passed, failed = failed, errors = 0 }, executions = {} })
end

local function _run_serial()
  return run_all.run({ serial = true, generated_dir = "build/acceptance/serial_spec_tmp" })
end

it("silent launcher failure keeps a nonempty diagnostic", function()
  local summary
  _with_single_entry(function()
    _with_stubbed_proc({ { ok = false, code = 127, output = "" } }, function()
      summary = _run_serial()
    end)
  end)
  check.equal(1, #summary.failed)
  check.equal(0, summary.passed)
  check.truthy(
    summary.failed[1].error:find("lua launcher failed with exit code 127", 1, true) ~= nil,
    "empty launcher output must still name the exit code: " .. summary.failed[1].error
  )
end)

it("zero executed cases never counts as passing", function()
  local summary
  _with_single_entry(function()
    _with_stubbed_proc({ { ok = true, code = 0, output = _result(0, 0, 0) } }, function()
      summary = _run_serial()
    end)
  end)
  check.equal(0, summary.passed)
  check.equal(1, #summary.failed)
  check.equal("no acceptance cases executed", summary.failed[1].error)
end)

it("real failure keeps output without infrastructure error", function()
  local summary
  _with_single_entry(function()
    _with_stubbed_proc({ { ok = false, code = 1, output = _result(18, 16, 2) } }, function()
      summary = _run_serial()
    end)
  end)
  check.equal(1, #summary.failed)
  check.equal("", summary.failed[1].error)
  check.truthy(summary.failed[1].output:find("real busted output", 1, true) ~= nil)
end)

it("spawns argv executor from repo root", function()
  local summary, calls
  _with_single_entry(function()
    _with_stubbed_proc({ { ok = true, code = 0, output = _result(1, 1, 0) } }, function(captured)
      calls = captured
      summary = _run_serial()
    end)
  end)
  check.equal(1, summary.passed)
  check.equal(1, #calls)

  -- bootstrap 从相对 source 路径解析时给出 "<root>/." 形式,与 run_all 内部的
  -- 绝对解析同指一个目录;归一化后比较。
  local function _strip_dot(path)
    return (tostring(path):gsub("/%.$", ""))
  end
  local repo_root = bootstrap.resolve("tools/packages/acceptance/run_all.lua").repo_root
  check.equal(_strip_dot(repo_root), _strip_dot(calls[1].options.cwd))
  check.is_table(calls[1].command)
  check.matches("tools/packages/acceptance/execute.lua", calls[1].command[2], 1, true)
  check.equal(path_lib.join_path("build/acceptance/serial_spec_tmp", "test_x_acceptance.lua"), calls[1].command[3])
end)
end)
