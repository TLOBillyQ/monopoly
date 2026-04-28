-- Helper module for suites.gameplay.shared.enabled_cases; no standalone test cases.
-- Cases here are exposed via dependent suite spec files.
describe("gameplay.shared.enabled_cases (helper module)", function()
  it("is a helper module consumed by other suites", function()
    assert(require("suites.gameplay.shared.enabled_cases"))
  end)
end)
