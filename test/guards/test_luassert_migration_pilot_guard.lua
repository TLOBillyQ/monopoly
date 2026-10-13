require("test.bootstrap").install_package_paths()

local lu = require("luaunit")
local guard = require("test.guards.lib.luassert_migration_pilot_guard")

-- #74 断言层迁移试点的静态门禁 spec。
--
-- 与同目录其余 guard 同款:门禁的判定逻辑住 lib 的纯核(M.check,喂 {path,
-- source}),这里既核对真实仓库文件(真门禁),也把合成的「违规输入」喂进去,
-- 逐条证明它真的会红——只跑真实仓库,一个被掏空的门禁照样全绿。
-- 真实仓库核对由 test_guard_runner.lua 的聚合入口跑(guard.run())。

local _PILOT = "test/behavior/foundation/test_scope.lua"

-- 合规最小源码仅声明断言来源,不要求旧结构。
local function _clean_source()
  local lines = {
    'require("test.bootstrap").install_package_paths()',
    "",
    'local luassert = assert(require("test.support.luassert_loader").load())',
    "",
  }
  return table.concat(lines, "\n") .. "\n"
end

local function _check(path, source)
  return guard.check({ { path = path, source = source } })
end

local function _joined(violations)
  return table.concat(violations, "\n")
end

TestLuassertMigrationPilotGuard = {}

-- 合成语料本身必须零违规:否则下面每条「会红」的验证都可能红在别的原因上,
-- 变成一条永远为红的假门禁。
function TestLuassertMigrationPilotGuard:test_synthetic_compliant_pilot_source_has_no_violations()
  local violations = _check(_PILOT, _clean_source(_PILOT))
  lu.assertEquals(#violations, 0, _joined(violations))
end

-- 冻结本票文件范围,允许下一阶段改变测试结构。
function TestLuassertMigrationPilotGuard:test_pilot_scope_is_frozen_without_structure_pins()
  lu.assertEquals(#guard.PILOT_FILES, 5, _joined(guard.PILOT_FILES))
  lu.assertNil(guard.STRUCTURE_ANCHORS)
  lu.assertNil(guard.ASSERTION_CALL_FLOOR)
end

function TestLuassertMigrationPilotGuard:test_still_requiring_luaunit_is_a_violation()
  local violations = _check(_PILOT, _clean_source(_PILOT) .. 'local lu = require("luaunit")\n')
  lu.assertEquals(#violations, 1, _joined(violations))
  lu.assertEvalToTrue(violations[1]:find("luaunit", 1, true) ~= nil, violations[1])
end

function TestLuassertMigrationPilotGuard:test_bypassing_the_loader_for_luassert_is_a_violation()
  local violations = _check(_PILOT, _clean_source(_PILOT):gsub(
    'test%.support%.luassert_loader', 'luassert'))
  lu.assertEvalToTrue(#violations > 0, "绕过 loader 直接 require luassert 必须被拦")
end

function TestLuassertMigrationPilotGuard:test_missing_loader_require_is_a_violation()
  local violations = _check(_PILOT, "local luassert = {}\n" .. _clean_source(_PILOT):gsub(
    'require%("test%.support%.luassert_loader"%)', 'require("somewhere.else")'))
  lu.assertEvalToTrue(#violations > 0, "断言对象不来自项目工具缓存 loader 必须被拦")
  lu.assertEvalToTrue(_joined(violations):find("loader", 1, true) ~= nil, _joined(violations))
end

function TestLuassertMigrationPilotGuard:test_busted_structure_migration_is_allowed()
  local violations = _check(_PILOT, _clean_source(_PILOT)
    .. 'local busted = require("busted")\ndescribe("scope", function() end)\n')
  lu.assertEquals(#violations, 0, _joined(violations))
end

function TestLuassertMigrationPilotGuard:test_helpers_and_return_structure_are_not_pinned()
  local violations = _check(_PILOT, _clean_source(_PILOT))
  lu.assertEquals(#violations, 0, _joined(violations))
end

function TestLuassertMigrationPilotGuard:test_assertion_call_count_is_not_a_structure_rule()
  local violations = _check(_PILOT, _clean_source(_PILOT) .. "luassert.is_true(true)\n")
  lu.assertEquals(#violations, 0, _joined(violations))
end

function TestLuassertMigrationPilotGuard:test_loader_taking_over_the_global_assert_is_a_violation()
  for _, snippet in ipairs({ "_G.assert = function() end", "_G[\"assert\"] = function() end" }) do
    local violations = _check(guard.LOADER_PATH, "local M = {}\n" .. snippet .. "\nreturn M\n")
    lu.assertEquals(#violations, 1, snippet .. ": " .. _joined(violations))
  end
end

-- 真实仓库:lib 的 IO 壳读真文件必须零违规(与聚合入口同口径,红在这里更好定位)。
function TestLuassertMigrationPilotGuard:test_real_repository_pilot_files_pass_the_guard()
  local result = guard.run()
  lu.assertTrue(result.ok == true, tostring(result.error or result.message))
end

return TestLuassertMigrationPilotGuard
