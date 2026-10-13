---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "tools/packages/dry/test/test_dry_cli.lua") end

require("test.bootstrap").install_package_paths()

-- dry 的真实 CLI 窄反馈(#96 / 母规格 #69 / ADR 0066)。dry(结构重复检测)当前是
-- 规格声明的 POSIX 专用能力:原生 Windows 上请求时必须给出可辨认的不可用诊断,
-- 不安装、不运行、不报通过,并且不可用 / 显式跳过 / 真实失败三态可区分。
--
-- 被替换的旧用例断言的是上游 dry4lua 的文本预算(--limit 行数裁剪),在原生
-- Windows 上必然红:上游 analysis.collect_files 用 `find` 与 `2>/dev/null` 发现
-- 候选,cmd.exe 把 `2>/dev/null` 当成 dev\null 路径而失败,于是零候选、静默打印
-- "No duplicate candidates found." 并退 0——那正是本票要消灭的「冒充通过」。
local lu = require("luaunit")
local env_lib = require("foundation.env")
local fs_lib = require("foundation.fs")
local path_lib = require("foundation.path")
local proc_lib = require("foundation.proc")

local CLI = "tools/cli.lua"
local RUNNER = "tools/packages/dry/runner.lua"

-- 上游 dry4lua 的「看起来通过了」输出。边界诊断一旦出现这两行,就说明它被放行了。
local UPSTREAM_NO_HITS = "No duplicate candidates found."
local UPSTREAM_HIT_ROW = "DUPLICATE score="

local function _run(tail)
  local command = { "lua", CLI, "dry" }
  for _, value in ipairs(tail) do
    command[#command + 1] = value
  end
  return proc_lib.run_command(command)
end

local function _with_fixture(fn)
  local root = env_lib.make_temp_path("dry_cli_spec", "")
  fs_lib.remove_path(root)
  lu.assertTrue(fs_lib.ensure_dir(root), "夹具目录建不起来: " .. root)
  local ok, err = xpcall(function()
    fn(root)
  end, debug.traceback)
  fs_lib.remove_path(root)
  if not ok then
    error(err)
  end
end

local function _write_duplicate_pair(root)
  local content = table.concat({
    "local M = {}",
    "function M.first(value)",
    "  if value then",
    "    return value + 1",
    "  end",
    "  return 0",
    "end",
    "function M.second(value)",
    "  if value then",
    "    return value + 1",
    "  end",
    "  return 0",
    "end",
    "return M",
    "",
  }, "\n")
  lu.assertTrue(fs_lib.write_file(path_lib.join_path(root, "duplicates.lua"), content))
end

TestDryCli = {}

-- 正例:--help 仍然有用(退出码 0),并说清能力边界与逃生开关。
function TestDryCli:test_help_stays_useful_and_states_the_windows_boundary()
  local result = _run({ "--help" })

  lu.assertEquals(result.code, 0, result.output)
  lu.assertEvalToTrue(result.output:find("dry4lua", 1, true) ~= nil, result.output)
  lu.assertEvalToTrue(result.output:find("--skip-if-unavailable", 1, true) ~= nil,
    "帮助要写出显式跳过开关: " .. result.output)
  lu.assertEvalToTrue(result.output:find("status=skipped", 1, true) ~= nil,
    "帮助要写出跳过状态词: " .. result.output)
end

-- 反例(本票核心):显式请求不冒充运行或通过。目标是真有一对重复函数的目录,
-- 若被放行给上游,输出里就会出现 "No duplicate candidates found."(零候选假绿)
-- 或 DUPLICATE 行(假结果);两者都不允许出现。
function TestDryCli:test_an_explicit_request_is_unavailable_and_never_claims_a_result()
  _with_fixture(function(root)
    _write_duplicate_pair(root)
    local result = _run({ root })

    lu.assertEquals(result.code, 3, result.output)
    lu.assertEvalToTrue(result.output:find("status=unavailable", 1, true) ~= nil,
      "诊断要带可机读状态词: " .. result.output)
    lu.assertEvalToTrue(result.output:find("POSIX", 1, true) ~= nil,
      "诊断要点明 POSIX 专用: " .. result.output)
    lu.assertNil(result.output:find(UPSTREAM_NO_HITS, 1, true),
      "不可用路径不得出现上游的零候选成功输出: " .. result.output)
    lu.assertNil(result.output:find(UPSTREAM_HIT_ROW, 1, true),
      "不可用路径不得出现任何重复簇结果: " .. result.output)
  end)
end

-- 显式跳过:调用方确认边界后跳过,状态与退出码都与不可用不同。
function TestDryCli:test_an_explicit_skip_exits_zero_with_a_skipped_status()
  _with_fixture(function(root)
    local result = _run({ "--skip-if-unavailable", root })

    lu.assertEquals(result.code, 0, result.output)
    lu.assertEvalToTrue(result.output:find("status=skipped", 1, true) ~= nil,
      "跳过要带可机读状态词: " .. result.output)
    lu.assertNil(result.output:find(UPSTREAM_NO_HITS, 1, true),
      "跳过路径同样不得冒充跑过: " .. result.output)
  end)
end

-- 诊断发生在安装/spawn 之前:边界诊断里不该夹带 cmd 的路径/重定向错误,
-- 那是安装或上游扫描真的跑起来的证据。
function TestDryCli:test_the_diagnostic_precedes_any_install_or_spawn()
  _with_fixture(function(root)
    local result = _run({ root })

    lu.assertNil(result.output:find("The system cannot find the path specified", 1, true),
      "边界诊断之前不该已经起过子进程: " .. result.output)
  end)
end

-- 脚本形态入口(verify/lint 类直接引用的 runner)与 CLI 同口径:旁门不许假绿。
function TestDryCli:test_the_runner_script_form_reports_the_same_boundary()
  _with_fixture(function(root)
    local result = proc_lib.run_command({ "lua", RUNNER, root })

    lu.assertEquals(result.code, 3, result.output)
    lu.assertEvalToTrue(result.output:find("status=unavailable", 1, true) ~= nil,
      result.output)
    lu.assertNil(result.output:find(UPSTREAM_NO_HITS, 1, true), result.output)
  end)
end

return TestDryCli
