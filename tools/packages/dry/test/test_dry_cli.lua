---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "tools/packages/dry/test/test_dry_cli.lua") end

require("test.bootstrap").install_package_paths()

-- dry 的真实 CLI 窄反馈(#122 / 父 spec #119)。上游 dry4lua 的文件发现已改为纯 Lua
-- (luafilesystem),原生 Windows 上真实扫描,dry 撤出平台边界。
--
-- 旧失败形态是「空扫描假绿」:cmd.exe 下零候选文件,上游照旧打印
-- "No duplicate candidates found." 并退 0。因此本套件的每个正例都要求真实扫描的
-- 候选文件数 > 0(runner 在 stderr 报 candidate_files=N),而不只看退出码;
-- 已知重复用仓内固定夹具,不依赖 src/ 里碰巧存在的重复。
local check = require("luassert")
local env_lib = require("foundation.env")
local fs_lib = require("foundation.fs")
local proc_lib = require("foundation.proc")

local CLI = "tools/cli.lua"
local RUNNER = "tools/packages/dry/runner.lua"
local DUPLICATE_PAIR = "tools/packages/dry/test/fixtures/duplicate_pair"

local UPSTREAM_NO_HITS = "No duplicate candidates found."
local UPSTREAM_HIT_ROW = "DUPLICATE score="

local function _run(tail)
  local command = { "lua", CLI, "dry" }
  for _, value in ipairs(tail) do
    command[#command + 1] = value
  end
  return proc_lib.run_command(command)
end

local function _candidate_files(output)
  return tonumber(output:match("candidate_files=(%d+)"))
end

local function _with_empty_dir(fn)
  local root = env_lib.make_temp_path("dry_cli_spec", "")
  fs_lib.remove_path(root)
  check.is_true(fs_lib.ensure_dir(root), "夹具目录建不起来: " .. root)
  local ok, err = xpcall(function()
    fn(root)
  end, debug.traceback)
  fs_lib.remove_path(root)
  if not ok then
    error(err)
  end
end

describe("dry cli", function()

it("help describes the scan and no longer declares a windows boundary", function()
  local result = _run({ "--help" })

  check.same(0, result.code, result.output)
  check.truthy(result.output:find("dry4lua", 1, true) ~= nil, result.output)
  check.truthy(result.output:find("candidate_files", 1, true) ~= nil,
    "帮助要说明候选文件数输出: " .. result.output)
  check.is_nil(result.output:find("POSIX", 1, true), "帮助不得再声明 POSIX 专用: " .. result.output)
  check.is_nil(result.output:find("--skip-if-unavailable", 1, true), result.output)
end)

-- 已知重复样例:固定夹具里的一对同构函数必须被识别,且候选文件数如实为 2。
it("finds the known duplicate pair in the fixture", function()
  local result = _run({ DUPLICATE_PAIR })

  check.same(0, result.code, result.output)
  check.same(2, _candidate_files(result.output), result.output)
  check.truthy(result.output:find(UPSTREAM_HIT_ROW, 1, true) ~= nil, result.output)
  check.truthy(result.output:find("ledger_a.lua", 1, true) ~= nil, result.output)
  check.truthy(result.output:find("ledger_b.lua", 1, true) ~= nil, result.output)
end)

-- 防空扫描假绿:真实扫描 src/ 的候选文件数必须 > 0。
it("scans a non-empty candidate set under src", function()
  local result = _run({ "--limit", "1", "src" })

  check.same(0, result.code, result.output)
  local count = _candidate_files(result.output)
  check.truthy(count ~= nil and count > 0, "src 候选文件数必须 > 0: " .. result.output)
  check.is_nil(result.output:find("status=unavailable", 1, true), result.output)
end)

-- 真实失败:路径不存在不能被读成「没有重复」。
it("a missing path is a real failure, not an empty pass", function()
  local result = _run({ "tools/packages/dry/test/fixtures/no_such_dir" })

  check.same(1, result.code, result.output)
  check.truthy(result.output:find("no_such_dir", 1, true) ~= nil, result.output)
  check.is_nil(result.output:find(UPSTREAM_NO_HITS, 1, true), result.output)
end)

-- 真实失败:目标下一个 .lua 都没有,扫描等于没跑,不许退 0。
it("a target without lua files fails instead of reporting no duplicates", function()
  _with_empty_dir(function(root)
    local result = _run({ root })

    check.same(1, result.code, result.output)
    check.same(0, _candidate_files(result.output), result.output)
    check.is_nil(result.output:find(UPSTREAM_NO_HITS, 1, true), result.output)
  end)
end)

-- #122 保留兼容开关:--skip-if-unavailable 由本仓消费、不漏给上游(漏了会被当成
-- 未知选项退 2),受支持平台上照常真实扫描。
it("skip flag is consumed and the scan still runs", function()
  local result = _run({ "--skip-if-unavailable", DUPLICATE_PAIR })

  check.same(0, result.code, result.output)
  check.same(2, _candidate_files(result.output), result.output)
  check.truthy(result.output:find(UPSTREAM_HIT_ROW, 1, true) ~= nil, result.output)
end)

-- 脚本形态入口与 CLI 同口径。
it("the runner script form scans the same way", function()
  local result = proc_lib.run_command({ "lua", RUNNER, DUPLICATE_PAIR })

  check.same(0, result.code, result.output)
  check.same(2, _candidate_files(result.output), result.output)
  check.truthy(result.output:find(UPSTREAM_HIT_ROW, 1, true) ~= nil, result.output)
end)

end)
