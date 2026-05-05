local support = require("support.test_profile_support")
local test_profile_resolver = require("src.app.testing.test_profile_resolver")

describe("runtime.test_profile_bootstrap_core", function()
  it("profile_bootstrap_rejects_item_count_over_inventory_limit", function()
    local game = support.new_game()
    local ok, err = pcall(function()
      support.with_patches({
        {
          target = test_profile_resolver,
          key = "resolve_bootstrap",
          value = function()
            return {
              players = {
                [1] = {
                  item_counts = {
                    [2001] = 2,
                    [2002] = 2,
                    [2003] = 2,
                  },
                },
              },
            }
          end,
        },
      }, function()
        require("src.app.testing.test_profile_bootstrap").apply(game, "default")
      end)
    end)
    assert(ok == false, "item_counts exceeding inventory limit should fail fast")
    assert(tostring(err):find("item_counts exceeds inventory limit", 1, true) ~= nil,
      "error should explain inventory limit breach")
  end)
end)
