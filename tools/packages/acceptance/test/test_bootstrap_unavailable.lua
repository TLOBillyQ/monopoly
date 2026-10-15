---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "tools/packages/acceptance/test/test_bootstrap_unavailable.lua") end
require("test.bootstrap").install_package_paths()

-- #114:acceptance 保证面四个入口(parser / generator / ir_dry / regenerate)接入
-- bootstrap 自举三态,与 spec-lane / lint 同口径(#112)。网络/下载类自举失败 →
-- 退 3、stderr 打 status=unavailable tool=acceptance4lua step=<步>,未运行、
-- 不冒充检查结论;仓内缺陷(锁文件缺项)照旧真实失败退 1。
-- 全部经 ensure_tool 注入缝喂三态:不碰网络、不替换 io、不起子进程。
local check = require("luassert")
local availability = require("foundation.tool_availability")

-- 断网替身:git ls-remote 解析不到主机,ensure_tool 透传不可用记录。
local function _offline_ensure(tool)
  local detail = "git ls-remote failed for https://example.invalid/eggy/" .. tool
    .. ": Could not resolve host: example.invalid"
  return nil, detail, availability.unavailable(tool, "resolve", detail)
end

-- 仓内缺陷替身:锁文件缺项是真实失败,不是不可用。
local function _defect_ensure(tool)
  return nil, "tool missing from lockfile: " .. tool
end

local function _must_not_run()
  error("upstream must not run when bootstrap failed")
end

-- 三个显式入口共用同一判定形状:注入 ensure_tool 喂三态,上游缝
-- (upstream_main / generate_file)在被触及时即炸——自举失败时上游不得运行。
local CLI_ENTRIES = {
  { module = "packages.acceptance.cli.parser", tag = "acceptance-parser" },
  { module = "packages.acceptance.cli.generator", tag = "acceptance-generator" },
  { module = "packages.acceptance.cli.ir_dry", tag = "acceptance-ir-dry" },
}

describe("acceptance cli entrypoints bootstrap availability (#114)", function()

for _, entry in ipairs(CLI_ENTRIES) do
  it(entry.tag .. " exits 3 with status=unavailable on network bootstrap failure", function()
    local result = require(entry.module).execute({
      args = {},
      ensure_tool = _offline_ensure,
      upstream_main = _must_not_run,
      generate_file = _must_not_run,
    })
    check.equal(3, result.code)
    check.equal("unavailable", result.status)
    check.equal("", result.stdout)
    check.matches("[" .. entry.tag .. "] status=unavailable tool=acceptance4lua step=resolve",
      result.stderr, 1, true)
    check.matches("未运行", result.stderr, 1, true)
    check.matches("Could not resolve host", result.stderr, 1, true)
  end)

  it(entry.tag .. " keeps repo defects as a real failure", function()
    local result = require(entry.module).execute({
      args = {},
      ensure_tool = _defect_ensure,
      upstream_main = _must_not_run,
      generate_file = _must_not_run,
    })
    check.equal(1, result.code)
    check.is_nil(result.status)
    check.equal("", result.stdout)
    check.matches("tool missing from lockfile: acceptance4lua", result.stderr, 1, true)
  end)
end

end)

describe("acceptance regenerate bootstrap availability (#114)", function()

it("regenerate exits 3 with status=unavailable on network bootstrap failure", function()
  local regenerate = require("packages.acceptance.regenerate")
  local result = regenerate.execute({ ensure_tool = _offline_ensure })
  check.equal(3, result.code)
  check.equal("unavailable", result.status)
  check.equal("", result.stdout)
  check.matches("[acceptance] status=unavailable tool=acceptance4lua step=resolve",
    result.stderr, 1, true)
  check.matches("未运行", result.stderr, 1, true)
  check.matches("Could not resolve host", result.stderr, 1, true)
end)

it("regenerate keeps repo defects as a real failure", function()
  local regenerate = require("packages.acceptance.regenerate")
  local result = regenerate.execute({ ensure_tool = _defect_ensure })
  check.equal(1, result.code)
  check.is_nil(result.status)
  check.matches("regenerate failed: tool missing from lockfile: acceptance4lua",
    result.stderr, 1, true)
end)

end)
