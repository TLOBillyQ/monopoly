local suite = require("suites.gameplay.bankruptcy.tile_owner")
local cases = suite.tests or suite
local label = suite.name or "gameplay.bankruptcy.tile_owner"

describe(label, function()
  for _, case in ipairs(cases) do
    it(case.name, case.run)
  end
end)
