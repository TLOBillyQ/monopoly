-- Helper module for suites.gameplay.bankruptcy.cases; no standalone test cases.
-- Cases here are exposed via dependent suite spec files.
describe("gameplay.bankruptcy.cases (helper module)", function()
  it("is a helper module consumed by other suites", function()
    assert(require("suites.gameplay.bankruptcy.cases"))
  end)
end)
