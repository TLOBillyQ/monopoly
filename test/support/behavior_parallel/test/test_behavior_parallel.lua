require("test.bootstrap").install_package_paths()

local lu = require("luaunit")
local env_lib = require("foundation.env")
local path_lib = require("foundation.path")
local behavior_parallel = require("test.support.behavior_parallel")

local function _seen_path(seen, path)
  return seen[path] == true
    or seen[path_lib.resolve_path(env_lib.current_dir(), path)] == true
end

TestBehaviorParallel = {}

function TestBehaviorParallel:test_resolves_the_tooling_profile_from_spec_profiles()
  local roots = assert(behavior_parallel._test_support.profile_roots("tooling"))

  lu.assertTrue(#roots >= 2, "tooling profile should cover relocated tool specs")
  lu.assertTrue(roots[1] ~= "test/behavior", "tooling profile must not fall back to behavior")
end

function TestBehaviorParallel:test_discovers_specs_across_multiple_roots()
  local files = behavior_parallel._test_support.discover_spec_files_for_roots({
    "tools/packages/luaunit_runner/test",
    "test/support/luaunit_runner_infra/test",
  })

  local seen = {}
  for _, path in ipairs(files) do
    seen[path] = true
  end
  lu.assertTrue(_seen_path(seen, "tools/packages/luaunit_runner/test/test_spec_sharding.lua"))
  lu.assertTrue(_seen_path(seen, "test/support/luaunit_runner_infra/test/test_luaunit_runner_infra_tooling.lua"))
end

function TestBehaviorParallel:test_parses_quiet_result_summaries_from_the_shared_output_handler()
  local parsed = behavior_parallel._test_support.parse_output("# RESULT: 123 ok\n")

  lu.assertEquals(parsed.passed, 123)
  lu.assertEquals(parsed.failed, 0)
end

function TestBehaviorParallel:test_keeps_quiet_result_summary_failures_visible()
  local parsed = behavior_parallel._test_support.parse_output("# RESULT: 7 ok · 2 FAIL · 1 error\n")

  lu.assertEquals(parsed.passed, 7)
  lu.assertEquals(parsed.failed, 3)
  lu.assertTrue(parsed.failure_lines[1]:find("FAIL", 1, true) ~= nil)
end

function TestBehaviorParallel:test_crash_excerpt_returns_empty_for_nil_output()
  lu.assertEquals(behavior_parallel._test_support.crash_excerpt(nil), {})
end

function TestBehaviorParallel:test_crash_excerpt_keeps_short_output_in_order()
  local excerpt = behavior_parallel._test_support.crash_excerpt("line a\nline b\n")

  lu.assertEquals(excerpt, { "line a", "line b" })
end

function TestBehaviorParallel:test_crash_excerpt_trims_trailing_blank_lines()
  local excerpt = behavior_parallel._test_support.crash_excerpt("keep me\n\n  \n")

  lu.assertEquals(excerpt, { "keep me" })
end

function TestBehaviorParallel:test_crash_excerpt_caps_long_output_to_the_tail()
  local lines = {}
  for i = 1, 40 do
    lines[#lines + 1] = "row " .. i
  end
  local excerpt = behavior_parallel._test_support.crash_excerpt(table.concat(lines, "\n"))

  lu.assertIs(#excerpt, 15)
  lu.assertIs(excerpt[1], "row 26")
  lu.assertIs(excerpt[15], "row 40")
end


return TestBehaviorParallel
