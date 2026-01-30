local Flow = require("Components.Flow")
local Inventory = require("Components.Inventory")
local RNG = require("Components.RNG")
local Store = require("Components.Store")
local Tile = require("Components.Tile")

local flow = Flow.new({
  start = "init",
  states = {
    init = function(args)
      return nil, args
    end,
  },
})
assert(flow:step() == nil, "flow should end")
assert(flow.current == nil, "flow current should be nil")

local rng = RNG.new(1)
local v = rng:next_int(1, 1)
assert(v == 1, "rng should respect bounds")

local inv = Inventory.new({ max_slots = 2 })
assert(inv:add({ id = 1 }) == true, "inventory should add")
assert(inv:count() == 1, "inventory count should be 1")

local store = Store.new({ foo = "bar" })
assert(store:get({ "foo" }) == "bar", "store should read value")

local tile = Tile.from_config({ id = 1, name = "t", type = "land" })
assert(tile.id == 1 and tile.name == "t", "tile should be created")

print("ok - classutils refactor")
