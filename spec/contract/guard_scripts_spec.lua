assert(require("spec.bootstrap").ensure_tool("arch_view"))

local dep_rules = require("spec.guards.lib.dep_rules")
local forbidden_globals = require("spec.guards.lib.forbidden_globals")
local fixed_type_guard = require("spec.guards.lib.fixed_type_guard")
local arch_common = require("arch_view.runtime.common")

local fixture_root = arch_common.normalize_path("spec/fixtures/guards")

local function _fixture_path(relpath)
  return arch_common.join_path(fixture_root, relpath)
end

describe("guard_scripts_contract", function()
  it("dep_rules_catches_ui_runtime_bypass", function()
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

    assert.is_true(result.ok == false, "dep_rules should reject direct state.ui_* writes")
    assert.is_not_nil(result.violation, "dep_rules should report a violation")
    assert.is_not_nil(result.violation.path:find("src/turn.lua", 1, true), "dep_rules should point to fixture file")
  end)

  it("forbidden_globals_catches_numeric_cast_in_src", function()
    local result = forbidden_globals.run({
      scan_roots = { _fixture_path("forbidden_globals/numeric_cast/src/bad.lua") },
    })

    assert.is_true(result.ok == false, "forbidden_globals should reject tonumber in src")
    assert.is_true(result.violations ~= nil and #result.violations == 1,
      "forbidden_globals should report one violation")
    assert.equals("tonumber", result.violations[1].name, "forbidden_globals should identify tonumber")
  end)

  it("forbidden_globals_catches_src_package_access", function()
    local result = forbidden_globals.run({
      scan_roots = { _fixture_path("forbidden_globals/src_package/src/bad.lua") },
    })

    assert.is_true(result.ok == false, "forbidden_globals should reject package access in src")
    assert.is_true(result.violations ~= nil and #result.violations == 1,
      "forbidden_globals should report one package violation")
    assert.equals("package.*", result.violations[1].name, "forbidden_globals should identify package access")
  end)

  it("forbidden_globals_allows_numeric_cast_outside_src", function()
    local tests_result = forbidden_globals.run({
      scan_roots = { _fixture_path("forbidden_globals/numeric_cast/tests/bad.lua") },
    })
    local tools_result = forbidden_globals.run({
      scan_roots = { _fixture_path("forbidden_globals/numeric_cast/tools/bad.lua") },
    })

    assert.is_true(tests_result.ok == true, "forbidden_globals should allow numeric casts in tests")
    assert.is_true(tools_result.ok == true, "forbidden_globals should allow numeric casts in tools")
  end)

  it("forbidden_globals_allows_package_access_outside_src", function()
    local tests_result = forbidden_globals.run({
      scan_roots = { _fixture_path("forbidden_globals/package_allowed/tests/clean.lua") },
    })
    local tools_result = forbidden_globals.run({
      scan_roots = { _fixture_path("forbidden_globals/package_allowed/tools/clean.lua") },
    })

    assert.is_true(tests_result.ok == true, "forbidden_globals should allow package access in tests")
    assert.is_true(tools_result.ok == true, "forbidden_globals should allow package access in tools")
  end)

  it("guard_scripts_allow_clean_fixtures", function()
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

    assert.is_true(dep_result.ok == true, "dep_rules should allow clean fixtures")
    assert.is_true(globals_result.ok == true, "forbidden_globals should allow clean fixtures")
  end)

  it("fixed_type_catches_int_literals", function()
    local result = fixed_type_guard.run({
      scan_roots = { _fixture_path("fixed_type/int_literal/src") },
    })

    assert.is_true(result.ok == false, "fixed_type_guard should reject integer literals in Fixed-typed params")
    assert.is_true(result.violations ~= nil and #result.violations >= 3,
      "fixed_type_guard should report at least 3 violations")
  end)

  it("fixed_type_allows_float_literals", function()
    local result = fixed_type_guard.run({
      scan_roots = { _fixture_path("fixed_type/float_literal/src") },
    })

    assert.is_true(result.ok == true, "fixed_type_guard should allow float literals for Fixed-typed params")
  end)

  it("fixed_type_allows_clean_src", function()
    local result = fixed_type_guard.run({
      scan_roots = { _fixture_path("clean/src") },
    })

    assert.is_true(result.ok == true, "fixed_type_guard should allow clean source files")
  end)
end)
