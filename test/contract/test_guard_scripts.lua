local lu = require("luaunit")

lu.assertEvalToTrue(require("test.bootstrap").ensure_tool("arch_view"))

local dep_rules = require("test.guards.lib.dep_rules")
local forbidden_globals = require("test.guards.lib.forbidden_globals")
local fixed_type_guard = require("test.guards.lib.fixed_type_guard")
local arch_common = require("arch_view.runtime.common")

local fixture_root = arch_common.normalize_path("test/fixtures/guards")

local function _fixture_path(relpath)
  return arch_common.join_path(fixture_root, relpath)
end

TestGuardScripts = {}

function TestGuardScripts:test_dep_rules_catches_ui_runtime_bypass()
  local result = dep_rules.run({
    rules = {
      {
        roots = { _fixture_path("dep_rules/ui_runtime_bypass/src/turn.lua") },
        forbidden_patterns = { "state%.ui_[A-Za-z0-9_]+%s*=" },
        description = "turn flow must route UI writes through output/ui_sync ports",
      },
    },
    forbidden_files = {},
  })

  lu.assertTrue(result.ok == false, "dep_rules should reject direct state.ui_* writes")
  lu.assertNotNil(result.violation, "dep_rules should report a violation")
  lu.assertNotNil(result.violation.path:find("src/turn.lua", 1, true), "dep_rules should point to fixture file")
end

function TestGuardScripts:test_forbidden_globals_catches_numeric_cast_in_src()
  local result = forbidden_globals.run({
    scan_roots = { _fixture_path("forbidden_globals/numeric_cast/src/bad.lua") },
  })

  lu.assertTrue(result.ok == false, "forbidden_globals should reject tonumber in src")
  lu.assertTrue(result.violations ~= nil and #result.violations == 1,
    "forbidden_globals should report one violation")
  lu.assertEquals(result.violations[1].name, "tonumber", "forbidden_globals should identify tonumber")
end

function TestGuardScripts:test_forbidden_globals_catches_src_package_access()
  local result = forbidden_globals.run({
    scan_roots = { _fixture_path("forbidden_globals/src_package/src/bad.lua") },
  })

  lu.assertTrue(result.ok == false, "forbidden_globals should reject package access in src")
  lu.assertTrue(result.violations ~= nil and #result.violations == 1,
    "forbidden_globals should report one package violation")
  lu.assertEquals(result.violations[1].name, "package.*", "forbidden_globals should identify package access")
end

function TestGuardScripts:test_forbidden_globals_allows_numeric_cast_outside_src()
  local tests_result = forbidden_globals.run({
    scan_roots = { _fixture_path("forbidden_globals/numeric_cast/tests/bad.lua") },
  })
  local tools_result = forbidden_globals.run({
    scan_roots = { _fixture_path("forbidden_globals/numeric_cast/tools/bad.lua") },
  })

  lu.assertTrue(tests_result.ok == true, "forbidden_globals should allow numeric casts in tests")
  lu.assertTrue(tools_result.ok == true, "forbidden_globals should allow numeric casts in tools")
end

function TestGuardScripts:test_forbidden_globals_allows_package_access_outside_src()
  local tests_result = forbidden_globals.run({
    scan_roots = { _fixture_path("forbidden_globals/package_allowed/tests/clean.lua") },
  })
  local tools_result = forbidden_globals.run({
    scan_roots = { _fixture_path("forbidden_globals/package_allowed/tools/clean.lua") },
  })

  lu.assertTrue(tests_result.ok == true, "forbidden_globals should allow package access in tests")
  lu.assertTrue(tools_result.ok == true, "forbidden_globals should allow package access in tools")
end

function TestGuardScripts:test_forbidden_globals_catches_host_globals_in_ui()
  local result = forbidden_globals.run({
    scan_roots = { _fixture_path("forbidden_globals/host_globals/src/ui/direct_call.lua") },
  })

  lu.assertTrue(result.ok == false, "forbidden_globals should reject direct host global usage in src/ui")
  lu.assertNotNil(result.violations, "forbidden_globals should report violations")
  local names = {}
  for _, violation in ipairs(result.violations) do
    names[violation.name] = true
  end
  lu.assertTrue(names.GameAPI, "should flag GameAPI")
  lu.assertTrue(names.LuaAPI, "should flag LuaAPI")
  lu.assertTrue(names.SceneUI, "should flag SceneUI")
  lu.assertTrue(names.Enums, "should flag Enums")
  lu.assertTrue(names.RegisterCustomEvent, "should flag RegisterCustomEvent")
  lu.assertTrue(names.UnregisterCustomEvent, "should flag UnregisterCustomEvent")
end

function TestGuardScripts:test_forbidden_globals_allows_host_globals_in_ui_manager()
  local result = forbidden_globals.run({
    scan_roots = { _fixture_path("forbidden_globals/host_globals/src/ui/manager/allowed.lua") },
  })

  lu.assertTrue(result.ok == true, "forbidden_globals should allow direct host global usage in src/ui/manager")
end

function TestGuardScripts:test_forbidden_globals_allows_host_globals_in_host()
  local result = forbidden_globals.run({
    scan_roots = { _fixture_path("forbidden_globals/host_globals/src/host/allowed.lua") },
  })

  lu.assertTrue(result.ok == true, "forbidden_globals should allow direct host global usage in src/host")
end

function TestGuardScripts:test_guard_scripts_allow_clean_fixtures()
  local dep_result = dep_rules.run({
    rules = {
      {
        roots = { _fixture_path("clean/src/clean.lua") },
        forbidden_patterns = { "state%.ui_[A-Za-z0-9_]+%s*=" },
        description = "turn flow must route UI writes through output/ui_sync ports",
      },
    },
    forbidden_files = {},
  })
  local globals_result = forbidden_globals.run({
    scan_roots = { _fixture_path("clean/tools/clean.lua") },
  })

  lu.assertTrue(dep_result.ok == true, "dep_rules should allow clean fixtures")
  lu.assertTrue(globals_result.ok == true, "forbidden_globals should allow clean fixtures")
end

function TestGuardScripts:test_fixed_type_catches_int_literals()
  local result = fixed_type_guard.run({
    scan_roots = { _fixture_path("fixed_type/int_literal/src") },
  })

  lu.assertTrue(result.ok == false, "fixed_type_guard should reject integer literals in Fixed-typed params")
  lu.assertTrue(result.violations ~= nil and #result.violations >= 3,
    "fixed_type_guard should report at least 3 violations")
end

function TestGuardScripts:test_fixed_type_allows_float_literals()
  local result = fixed_type_guard.run({
    scan_roots = { _fixture_path("fixed_type/float_literal/src") },
  })

  lu.assertTrue(result.ok == true, "fixed_type_guard should allow float literals for Fixed-typed params")
end

function TestGuardScripts:test_fixed_type_allows_clean_src()
  local result = fixed_type_guard.run({
    scan_roots = { _fixture_path("clean/src") },
  })

  lu.assertTrue(result.ok == true, "fixed_type_guard should allow clean source files")
end


return TestGuardScripts
