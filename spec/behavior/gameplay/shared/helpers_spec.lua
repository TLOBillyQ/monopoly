-- Helper module for suites.gameplay.shared.helpers; no standalone test cases.
-- Cases here are exposed via dependent suite spec files.
describe("gameplay.shared.helpers (helper module)", function()
  it("is a helper module consumed by other suites", function()
    assert(require("suites.gameplay.shared.helpers"))
  end)
end)
