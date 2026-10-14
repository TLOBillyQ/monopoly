require("test.bootstrap").install_package_paths()
local luassert = assert
local guard = require("test.guards.lib.luassert_migration_pilot_guard")

-- The assertion provenance seam survives the temporary #74 pilot inventory.
local _PILOT = "test/behavior/foundation/test_scope.lua"
local function _clean_source()
  return 'require("test.bootstrap").install_package_paths()\n'
    .. 'local luassert = assert(require("test.support.luassert_loader").load())\n'
end
local function _check(path, source, backend)
  return guard.check({ { path = path, source = source, backend = backend } })
end
local function _joined(violations)
  return table.concat(violations, "\n")
end

describe("TestLuassertMigrationPilotGuard", function()
  it("test_synthetic_compliant_pilot_source_has_no_violations", function()
    local violations = _check(_PILOT, _clean_source())
    luassert.is.equal(0, #violations, _joined(violations))
  end)

  -- Replace the removable pilot-count pin with genuine DSL provenance policy.
  it("test_busted_sources_use_verified_runner_assertion_without_structure_pins", function()
    local violations = _check(_PILOT,
      'local luassert = assert\ndescribe("scope", function() end)\n', "busted")
    luassert.is.equal(0, #violations, _joined(violations))
    luassert.is_nil(guard.STRUCTURE_ANCHORS)
    luassert.is_nil(guard.ASSERTION_CALL_FLOOR)
    local direct = _check(_PILOT, 'local luassert = require("luassert")\n', "busted")
    luassert.is.equal(0, #direct, _joined(direct))
  end)

  it("test_still_requiring_luaunit_is_a_violation", function()
    local violations = _check(_PILOT, _clean_source() .. 'local lu = require("luaunit")\n')
    luassert.is.equal(1, #violations, _joined(violations))
    luassert.truthy(violations[1]:find("luaunit", 1, true) ~= nil, violations[1])
  end)

  it("test_bypassing_the_loader_for_luassert_is_a_violation", function()
    local violations = _check(_PILOT, _clean_source():gsub('test%.support%.luassert_loader', 'luassert'))
    luassert.truthy(#violations > 0, "绕过 loader 直接 require luassert 必须被拦")
  end)

  it("test_missing_loader_require_is_a_violation", function()
    local violations = _check(_PILOT, "local luassert = {}\n" .. _clean_source():gsub(
      'require%("test%.support%.luassert_loader"%)', 'require("somewhere.else")'))
    luassert.truthy(#violations > 0, "断言对象不来自项目工具缓存 loader 必须被拦")
    luassert.truthy(_joined(violations):find("loader", 1, true) ~= nil, _joined(violations))
  end)

  it("test_busted_structure_migration_is_allowed", function()
    local violations = _check(_PILOT, 'local luassert = assert\ndescribe("scope", function() end)\n', "busted")
    luassert.is.equal(0, #violations, _joined(violations))
  end)

  it("test_helpers_and_return_structure_are_not_pinned", function()
    local violations = _check(_PILOT, _clean_source())
    luassert.is.equal(0, #violations, _joined(violations))
  end)

  it("test_assertion_call_count_is_not_a_structure_rule", function()
    local violations = _check(_PILOT, _clean_source() .. "luassert.is_true(true)\n")
    luassert.is.equal(0, #violations, _joined(violations))
  end)

  it("test_loader_taking_over_the_global_assert_is_a_violation", function()
    for _, snippet in ipairs({ "_G.assert = function() end", '_G["assert"] = function() end' }) do
      for _, entry in ipairs({
        { path = guard.LOADER_PATH, source = "local M = {}\n" .. snippet .. "\nreturn M\n" },
        { path = _PILOT, source = snippet, backend = "busted" },
      }) do
        local violations = guard.check({ entry })
        luassert.is.equal(1, #violations, snippet .. ": " .. _joined(violations))
      end
    end
  end)

  it("test_real_repository_pilot_files_pass_the_guard", function()
    local result = guard.run()
    luassert.is_true(result.ok == true, tostring(result.error or result.message))
  end)
end)
