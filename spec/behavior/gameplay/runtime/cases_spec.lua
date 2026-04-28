-- Helper module for suites.gameplay.runtime.cases; no standalone test cases.
-- Cases here are exposed via dependent suite spec files.
describe("gameplay.runtime.cases (helper module)", function()
  it("is a helper module consumed by other suites", function()
    assert(require("suites.gameplay.runtime.cases"))
  end)
end)
