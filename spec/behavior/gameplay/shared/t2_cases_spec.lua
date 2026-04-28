-- Helper module for suites.gameplay.shared.t2_cases; no standalone test cases.
-- Cases here are exposed via dependent suite spec files.
describe("gameplay.shared.t2_cases (helper module)", function()
  it("is a helper module consumed by other suites", function()
    assert(require("suites.gameplay.shared.t2_cases"))
  end)
end)
