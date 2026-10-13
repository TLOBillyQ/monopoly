require("test.bootstrap").install_package_paths()

local check = require("luassert")
local env_lib = require("foundation.env")
local path_lib = require("foundation.path")
local behavior_parallel = require("test.support.behavior_parallel")

local function _seen_path(seen, path)
  return seen[path] == true
    or seen[path_lib.resolve_path(env_lib.current_dir(), path)] == true
end

describe("behavior parallel support", function()

it("resolves the tooling profile from spec profiles", function()
  local roots = assert(behavior_parallel._test_support.profile_roots("tooling"))

  check.is_true(#roots >= 2, "tooling profile should cover relocated tool specs")
  check.is_true(roots[1] ~= "test/behavior", "tooling profile must not fall back to behavior")
end)

it("discovers specs across multiple roots", function()
  local files = behavior_parallel._test_support.discover_spec_files_for_roots({
    "tools/packages/luaunit_runner/test",
    "test/support/luaunit_runner_infra/test",
  })

  local seen = {}
  for _, path in ipairs(files) do
    seen[path] = true
  end
  check.is_true(_seen_path(seen, "tools/packages/luaunit_runner/test/test_spec_sharding.lua"))
  check.is_true(_seen_path(seen, "test/support/luaunit_runner_infra/test/test_luaunit_runner_infra_tooling.lua"))
end)

it("parses quiet result summaries from the shared output handler", function()
  local parsed = behavior_parallel._test_support.parse_output("# RESULT: 123 ok\r\n")

  check.same(parsed.passed, 123)
  check.same(parsed.failed, 0)
end)

it("keeps quiet result summary failures visible", function()
  local parsed = behavior_parallel._test_support.parse_output("not ok - failed to load broken.lua\r\n# missing dependency\r\n# RESULT: 7 ok · 2 FAIL · 1 error\r\n")

  check.same(parsed.passed, 7)
  check.same(parsed.failed, 3)
  check.matches("failed to load broken.lua", table.concat(parsed.failure_lines, "\n"), 1, true)
end)

it("crash excerpt returns empty for nil output", function()
  check.same(behavior_parallel._test_support.crash_excerpt(nil), {})
end)

it("crash excerpt keeps short output in order", function()
  local excerpt = behavior_parallel._test_support.crash_excerpt("line a\nline b\n")

  check.same(excerpt, { "line a", "line b" })
end)

it("crash excerpt trims trailing blank lines", function()
  local excerpt = behavior_parallel._test_support.crash_excerpt("keep me\n\n  \n")

  check.same(excerpt, { "keep me" })
end)

it("crash excerpt caps long output to the tail", function()
  local lines = {}
  for i = 1, 40 do
    lines[#lines + 1] = "row " .. i
  end
  local excerpt = behavior_parallel._test_support.crash_excerpt(table.concat(lines, "\n"))

  check.equal(#excerpt, 15)
  check.equal(excerpt[1], "row 26")
  check.equal(excerpt[15], "row 40")
end)


end)
