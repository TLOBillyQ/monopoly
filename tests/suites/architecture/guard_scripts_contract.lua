local dep_rules = require("guards.dep_rules")
local forbidden_globals = require("guards.forbidden_globals")
local arch_common = require("arch_view.runtime.common")

local fixture_root = arch_common.normalize_path("tests/fixtures/guards")

local function _fixture_path(relpath)
    return arch_common.join_path(fixture_root, relpath)
end

local function _test_dep_rules_catches_ui_runtime_bypass()
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

    assert(result.ok == false, "dep_rules should reject direct state.ui_* writes")
    assert(result.violation ~= nil, "dep_rules should report a violation")
    assert(result.violation.path:find("src/turn.lua", 1, true) ~= nil, "dep_rules should point to fixture file")
end

local function _test_forbidden_globals_catches_numeric_cast_in_src()
    local result = forbidden_globals.run({
        scan_roots = { _fixture_path("forbidden_globals/numeric_cast/src/bad.lua") },
    })

    assert(result.ok == false, "forbidden_globals should reject tonumber in src")
    assert(result.violations ~= nil and #result.violations == 1, "forbidden_globals should report one violation")
    assert(result.violations[1].name == "tonumber", "forbidden_globals should identify tonumber")
end

local function _test_forbidden_globals_catches_src_package_access()
    local result = forbidden_globals.run({
        scan_roots = { _fixture_path("forbidden_globals/src_package/src/bad.lua") },
    })

    assert(result.ok == false, "forbidden_globals should reject package access in src")
    assert(result.violations ~= nil and #result.violations == 1, "forbidden_globals should report one package violation")
    assert(result.violations[1].name == "package.*", "forbidden_globals should identify package access")
end

local function _test_forbidden_globals_allows_numeric_cast_outside_src()
    local tests_result = forbidden_globals.run({
        scan_roots = { _fixture_path("forbidden_globals/numeric_cast/tests/bad.lua") },
    })
    local tools_result = forbidden_globals.run({
        scan_roots = { _fixture_path("forbidden_globals/numeric_cast/tools/bad.lua") },
    })

    assert(tests_result.ok == true, "forbidden_globals should allow numeric casts in tests")
    assert(tools_result.ok == true, "forbidden_globals should allow numeric casts in tools")
end

local function _test_forbidden_globals_allows_package_access_outside_src()
    local tests_result = forbidden_globals.run({
        scan_roots = { _fixture_path("forbidden_globals/package_allowed/tests/clean.lua") },
    })
    local tools_result = forbidden_globals.run({
        scan_roots = { _fixture_path("forbidden_globals/package_allowed/tools/clean.lua") },
    })

    assert(tests_result.ok == true, "forbidden_globals should allow package access in tests")
    assert(tools_result.ok == true, "forbidden_globals should allow package access in tools")
end

local function _test_guard_scripts_allow_clean_fixtures()
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

    assert(dep_result.ok == true, "dep_rules should allow clean fixtures")
    assert(globals_result.ok == true, "forbidden_globals should allow clean fixtures")
end

return {
    name = "guard_scripts_contract",
    tests = {
        { name = "dep_rules_catches_ui_runtime_bypass",              run = _test_dep_rules_catches_ui_runtime_bypass },
        { name = "forbidden_globals_catches_numeric_cast_in_src",    run = _test_forbidden_globals_catches_numeric_cast_in_src },
        { name = "forbidden_globals_catches_src_package_access",     run = _test_forbidden_globals_catches_src_package_access },
        { name = "forbidden_globals_allows_numeric_cast_outside_src", run = _test_forbidden_globals_allows_numeric_cast_outside_src },
        { name = "forbidden_globals_allows_package_access_outside_src", run = _test_forbidden_globals_allows_package_access_outside_src },
        { name = "guard_scripts_allow_clean_fixtures",               run = _test_guard_scripts_allow_clean_fixtures },
    },
}
