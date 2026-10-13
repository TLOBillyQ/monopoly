require("test.bootstrap").install_package_paths()
local luassert = assert
local suite = require("test.support.scenario_suites.movement.relocation")
local support = require("test.support.shared_support")

describe("TestRelocation", function()
  for _, case in ipairs(suite.tests) do
    it("test_" .. case.name, case.run)
  end
end)

describe("TestRelocationDirect", function()
  it("test_relocate_without_destination_errors", function()
    local game = support.new_game()
    local ok, err = pcall(function()
      game:player_relocate(game.players[1], {})
    end)
    luassert.is_false(ok, "relocate without a destination should fail")
    luassert.truthy(tostring(err):find("missing relocation destination", 1, true) ~= nil,
      "relocate error should name the missing destination")
  end)
end)
