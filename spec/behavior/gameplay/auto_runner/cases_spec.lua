-- Helper module for suites.gameplay.auto_runner.cases; no standalone test cases.
-- Cases here are exposed via dependent suite spec files.
describe("gameplay.auto_runner.cases (helper module)", function()
  it("is a helper module consumed by other suites", function()
    assert(require("suites.gameplay.auto_runner.cases"))
  end)
end)
