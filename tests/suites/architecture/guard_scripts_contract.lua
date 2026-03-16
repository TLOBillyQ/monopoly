local dep_rules = require("guards.dep_rules")
local forbidden_globals = require("guards.forbidden_globals")
local arch_common = require("arch_view.runtime.common")

local path_sep = package.config:sub(1, 1)

local function _ensure_dir(path)
    local ok, err = arch_common.ensure_dir(path)
    if not ok then
        error(err)
    end
end

local function _write_file(path, text)
    local file = assert(io.open(path, "w"))
    file:write(text)
    file:close()
end

local function _with_fixture(files, fn)
    local fixture_root = arch_common.make_temp_path("guard_scripts_contract", "")
    local removed, remove_err = arch_common.remove_path(fixture_root)
    if not removed then
        error(remove_err)
    end
    for relpath, text in pairs(files) do
        local normalized = relpath:gsub("/", path_sep)
        local dir = nil
        if path_sep == "\\" then
            dir = normalized:match("^(.*)\\[^\\]+$")
        else
            dir = normalized:match("^(.*)/[^/]+$")
        end
        if dir then
            _ensure_dir(fixture_root .. path_sep .. dir)
        end
        _write_file(fixture_root .. path_sep .. normalized, text)
    end

    local ok, err = xpcall(function()
        fn(arch_common.normalize_path(fixture_root))
    end, debug.traceback)
    local cleaned, cleanup_err = arch_common.remove_path(fixture_root)
    if not cleaned and ok then
        error(cleanup_err)
    end
    if not ok then
        error(err)
    end
end

local function _test_dep_rules_catches_ui_runtime_bypass()
    _with_fixture({
        ["src/turn.lua"] = "local state = {}\nstate.ui_dirty = true\n",
    }, function(fixture_root)
        local result = dep_rules.run({
            rules = {
                {
                    roots = { arch_common.join_path(fixture_root, "src") },
                    forbidden_patterns = { "state%.ui_[A-Za-z0-9_]+%s*=" },
                    description = "turn flow must route UI writes through output/ui_sync ports",
                },
            },
            forbidden_files = {},
        })

        assert(result.ok == false, "dep_rules should reject direct state.ui_* writes")
        assert(result.violation ~= nil, "dep_rules should report a violation")
        assert(result.violation.path:find("src/turn.lua", 1, true) ~= nil, "dep_rules should point to fixture file")
    end)
end

local function _test_forbidden_globals_catches_numeric_cast()
    local forbidden_call = "ton" .. "umber"
    _with_fixture({
        ["scripts/bad.lua"] = "return " .. forbidden_call .. "('1')\n",
    }, function(fixture_root)
        local result = forbidden_globals.run({
            scan_roots = { arch_common.join_path(fixture_root, "scripts") },
        })

        assert(result.ok == false, "forbidden_globals should reject tonumber")
        assert(result.violations ~= nil and #result.violations == 1, "forbidden_globals should report one violation")
        assert(result.violations[1].name == "tonumber", "forbidden_globals should identify tonumber")
    end)
end

local function _test_guard_scripts_allow_clean_fixtures()
    _with_fixture({
        ["src/clean.lua"] = "local state = {}\nstate.output = true\nreturn state\n",
        ["tests/clean.lua"] = 'return require("src.turn.loop.scheduler_runtime")\n',
        ["scripts/clean.lua"] = "return 1\n",
    }, function(fixture_root)
        local dep_result = dep_rules.run({
            rules = {
                {
                    roots = { arch_common.join_path(fixture_root, "src") },
                    forbidden_patterns = { "state%.ui_[A-Za-z0-9_]+%s*=" },
                    description = "turn flow must route UI writes through output/ui_sync ports",
                },
            },
            forbidden_files = {},
        })
        local globals_result = forbidden_globals.run({
            scan_roots = { arch_common.join_path(fixture_root, "scripts") },
        })

        assert(dep_result.ok == true, "dep_rules should allow clean fixtures")
        assert(globals_result.ok == true, "forbidden_globals should allow clean fixtures")
    end)
end

return {
    name = "guard_scripts_contract",
    tests = {
        { name = "dep_rules_catches_ui_runtime_bypass",              run = _test_dep_rules_catches_ui_runtime_bypass },
        { name = "forbidden_globals_catches_numeric_cast",           run = _test_forbidden_globals_catches_numeric_cast },
        { name = "guard_scripts_allow_clean_fixtures",               run = _test_guard_scripts_allow_clean_fixtures },
    },
}
