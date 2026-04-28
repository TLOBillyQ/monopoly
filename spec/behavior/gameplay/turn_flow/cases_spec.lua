-- Helper module for suites.gameplay.turn_flow.cases; no standalone test cases.
-- Cases here are exposed via dependent suite spec files.
describe("gameplay.turn_flow.cases (helper module)", function()
  it("is a helper module consumed by other suites", function()
    assert(require("suites.gameplay.turn_flow.cases"))
  end)
end)
