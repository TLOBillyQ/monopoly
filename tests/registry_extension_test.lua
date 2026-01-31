dofile("tests/test_bootstrap.lua")

local ChanceRegistry = require("Manager.GameManager.ChanceRegistry")
local ChanceEffects = require("Manager.GameManager.Chance")

local called = 0

ChanceRegistry.register("test_registry_effect", function()
  called = called + 1
  return true
end)

local player = {
  has_angel = function()
    return false
  end,
}

ChanceEffects.resolve({}, player, { effect = "test_registry_effect" }, {})

assert(called == 1, "registry handler should be called once")

print("ok - registry extension works")
