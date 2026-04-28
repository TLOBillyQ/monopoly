-- Helper module for suites.gameplay.shared.misc_cases; no standalone test cases.
-- Cases here are exposed via dependent suite spec files.
describe("gameplay.shared.misc_cases (helper module)", function()
  it("is a helper module consumed by other suites", function()
    assert(require("suites.gameplay.shared.misc_cases"))
  end)
end)
