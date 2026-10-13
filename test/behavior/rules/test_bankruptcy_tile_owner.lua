local suite = require("test.support.scenario_suites.bankruptcy.tile_owner")


describe("TestBankruptcyTileOwner", function()
for _, case in ipairs(suite.tests or suite) do
  it("test_" .. case.name, function()
    case.run()
  end)
end


end)
