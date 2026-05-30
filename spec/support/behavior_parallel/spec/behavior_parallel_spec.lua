require("spec.bootstrap").install_package_paths()

local behavior_parallel = require("spec.support.behavior_parallel")

describe("behavior_parallel profile roots", function()
  it("resolves the tooling profile from .busted", function()
    local roots = assert(behavior_parallel._test_support.profile_roots("tooling"))

    assert.is_true(#roots >= 2, "tooling profile should cover relocated tool specs")
    assert.is_true(roots[1] ~= "spec/behavior", "tooling profile must not fall back to behavior")
  end)

  it("discovers specs across multiple roots", function()
    local files = behavior_parallel._test_support.discover_spec_files_for_roots({
      "tools/shared/lib/busted_sharding/spec",
      "spec/support/busted/spec",
    })

    local seen = {}
    for _, path in ipairs(files) do
      seen[path] = true
    end
    assert.is_true(seen["tools/shared/lib/busted_sharding/spec/busted_sharding_spec.lua"])
    assert.is_true(seen["spec/support/busted/spec/busted_infra_tooling_spec.lua"])
  end)

  it("parses quiet result summaries from the shared output handler", function()
    local parsed = behavior_parallel._test_support.parse_output("# RESULT: 123 ok\n")

    assert.are.equal(123, parsed.passed)
    assert.are.equal(0, parsed.failed)
  end)

  it("keeps quiet result summary failures visible", function()
    local parsed = behavior_parallel._test_support.parse_output("# RESULT: 7 ok · 2 FAIL · 1 error\n")

    assert.are.equal(7, parsed.passed)
    assert.are.equal(3, parsed.failed)
    assert.is_true(parsed.failure_lines[1]:find("FAIL", 1, true) ~= nil)
  end)
end)
