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

-- 一份合规的最小试点源码:loader + 局部断言对象 + 结构锚点 + 足够断言调用点。
local function _clean_source(path)
  local lines = {
    'require("test.bootstrap").install_package_paths()',
    "",
    'local luassert = assert(require("test.support.luassert_loader").load())',
    "",
  }
  for _, anchor in ipairs(guard.STRUCTURE_ANCHORS[path] or {}) do
    lines[#lines + 1] = anchor.literal
  end
  local floor = guard.ASSERTION_CALL_FLOOR[path] or 0
  for index = 1, floor do
    lines[#lines + 1] = "  luassert.is.equal(" .. index .. ", " .. index .. ")"
  end
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

-- 试点范围是冻结数据:5 个文件,且每个文件都有结构锚点与断言调用下界。
-- 试点外新增文件必须显式改表,不能悄悄漂移。
function TestLuassertMigrationPilotGuard:test_pilot_scope_is_frozen_and_fully_annotated()
  lu.assertEquals(#guard.PILOT_FILES, 5, _joined(guard.PILOT_FILES))
  for _, path in ipairs(guard.PILOT_FILES) do
    lu.assertNotNil(guard.STRUCTURE_ANCHORS[path], path .. " 缺结构锚点")
    lu.assertNotNil(guard.ASSERTION_CALL_FLOOR[path], path .. " 缺断言调用下界")
  end
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

function TestLuassertMigrationPilotGuard:test_busted_compat_layer_is_a_violation()
  local violations = _check(_PILOT, _clean_source(_PILOT) .. 'describe("旧 Test 表", function() end)\n')
  lu.assertEquals(#violations, 1, _joined(violations))
  lu.assertEvalToTrue(violations[1]:find("describe", 1, true) ~= nil, violations[1])
end

function TestLuassertMigrationPilotGuard:test_lost_structure_anchor_is_a_violation()
  local anchor = guard.STRUCTURE_ANCHORS[_PILOT][1].literal
  local violations = _check(_PILOT, (_clean_source(_PILOT):gsub(anchor:gsub("%W", "%%%0"), "-- removed")))
  lu.assertEquals(#violations, 1, _joined(violations))
  lu.assertEvalToTrue(violations[1]:find("结构锚点", 1, true) ~= nil, violations[1])
end

function TestLuassertMigrationPilotGuard:test_assertion_call_floor_is_enforced()
  local floor = guard.ASSERTION_CALL_FLOOR[_PILOT]
  local source = _clean_source(_PILOT)
  local trimmed = source:gsub("%f[%a]luassert%.[%a_%.]+", "")
  local violations = _check(_PILOT, trimmed)
  lu.assertEquals(#violations, 1, _joined(violations))
  lu.assertEvalToTrue(violations[1]:find("下界 " .. floor, 1, true) ~= nil, violations[1])
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
