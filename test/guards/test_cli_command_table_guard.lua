require("test.bootstrap").install_package_paths()

local lu = require("luaunit")
local guard = require("test.guards.lib.cli_command_table_guard")

-- cli 子命令表 ↔ packages/ 一致性 guard(#316 / #300 Q4):commands 路由表与
-- tools/packages/ 目录一一对应,非路由包走白名单。下面每一条都喂合成的
-- 路由表/目录/白名单,断言它真的会红/会绿——门禁的价值全在能变红。

-- 精简的合成基线语料(6 条路由 + 1 个非路由包;真实仓库为 10 条路由 + 3 个
-- 非路由包,同构即可,判分支与数量无关)。
local _COMMANDS = {
  { name = "verify", pkg = "verify" },
  { name = "spec-lane", pkg = "spec_lane" },
  { name = "acceptance", pkg = "acceptance" },
  { name = "mutate", pkg = "mutate" },
  { name = "lint", pkg = "lint" },
  { name = "deploy", pkg = "ops" },
}
local _DIRS = { "verify", "spec_lane", "acceptance", "mutate", "lint", "coverage", "ops" }
local _NON_ROUTED = { "coverage" }

local function _check(commands, dirs, non_routed)
  return guard.check(commands or _COMMANDS, dirs or _DIRS, non_routed or _NON_ROUTED)
end

local function _joined(violations)
  return table.concat(violations, "\n")
end

TestCliCommandTableGuard = {}

-- 从 cli.lua 源码形态解析出 name/pkg 对。
function TestCliCommandTableGuard:test_parse_commands_extracts_entries()
  local source = table.concat({
    'local commands = {',
    '  { name = "verify",            pkg = "verify",             summary = "x" },',
    '  { name = "spec-lane",         pkg = "spec_lane",          summary = "y" },',
    '}',
  }, "\n")
  local commands, err = guard.parse_commands(source)
  lu.assertNotIsNil(commands, tostring(err))
  lu.assertEquals(#commands, 2)
  lu.assertEquals(commands[1].name, "verify")
  lu.assertEquals(commands[1].pkg, "verify")
  lu.assertEquals(commands[2].name, "spec-lane")
  lu.assertEquals(commands[2].pkg, "spec_lane")
end

-- 源码里一条都解析不到(表被改名/搬走)必须失败,不能静默全绿。
function TestCliCommandTableGuard:test_parse_commands_fails_on_unparseable_source()
  local commands, err = guard.parse_commands("-- 空源码,没有 commands 表")
  lu.assertIsNil(commands)
  lu.assertEvalToTrue(tostring(err):find("解析", 1, true) ~= nil)
end

-- 现状同构语料必须全绿(路由 ⊆ 目录,目录 = 路由 ∪ 白名单)。
function TestCliCommandTableGuard:test_current_shape_is_allowed()
  local violations = _check()
  lu.assertEquals(#violations, 0, _joined(violations))
end

-- 路由到不存在的包(错名/目录遗漏)必须被拦。
function TestCliCommandTableGuard:test_routed_missing_pkg_is_blocked()
  local commands = { { name = "mutate", pkg = "mutatte" } }
  local violations = _check(commands, { "mutate" }, {})
  lu.assertEquals(#violations, 2, _joined(violations))
  lu.assertEvalToTrue(_joined(violations):find("mutatte", 1, true) ~= nil)
end

-- 多余包(未路由也未豁免)必须被拦。
function TestCliCommandTableGuard:test_unrouted_unlisted_pkg_is_blocked()
  local dirs = { "verify", "spec_lane", "acceptance", "mutate", "lint", "coverage", "ops", "surprise" }
  local violations = _check(nil, dirs)
  lu.assertEquals(#violations, 1, _joined(violations))
  lu.assertEvalToTrue(violations[1]:find("surprise", 1, true) ~= nil)
end

-- 白名单内的非路由包豁免。
function TestCliCommandTableGuard:test_whitelisted_non_routed_pkg_is_allowed()
  local violations = _check({ { name = "verify", pkg = "verify" } }, { "verify", "coverage" }, { "coverage" })
  lu.assertEquals(#violations, 0, _joined(violations))
end

-- stale 白名单条目(包已消失)必须报错销账。
function TestCliCommandTableGuard:test_stale_whitelist_entry_is_blocked()
  local violations = _check(nil, nil, { "coverage", "ghost" })
  lu.assertEquals(#violations, 1, _joined(violations))
  lu.assertEvalToTrue(violations[1]:find("ghost", 1, true) ~= nil)
end

-- 已挂路由的包仍留白名单里必须报错销账。
function TestCliCommandTableGuard:test_routed_but_whitelisted_pkg_is_blocked()
  local violations = _check(nil, nil, { "coverage", "lint" })
  lu.assertEquals(#violations, 1, _joined(violations))
  lu.assertEvalToTrue(violations[1]:find("lint", 1, true) ~= nil)
end

-- 子命令重名必须被拦。
function TestCliCommandTableGuard:test_duplicate_command_name_is_blocked()
  local commands = {
    { name = "verify", pkg = "verify" },
    { name = "verify", pkg = "verify" },
  }
  local violations = _check(commands, { "verify" }, {})
  lu.assertEquals(#violations, 1, _joined(violations))
  lu.assertEvalToTrue(violations[1]:find("重复", 1, true) ~= nil)
end

return TestCliCommandTableGuard
