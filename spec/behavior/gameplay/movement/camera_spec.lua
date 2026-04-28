local suite = require("suites.gameplay.movement.camera")
local cases = suite.tests or suite
local label = suite.name or "gameplay.movement.camera"

describe(label, function()
  for _, case in ipairs(cases) do
    it(case.name, case.run)
  end
end)
