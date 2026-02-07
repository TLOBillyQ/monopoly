local land_actions = require("src.game.land.LandActions")

local first_path = nil
local store = {
  get = function(_, path)
    if not first_path then
      first_path = path
    else
      assert(path ~= first_path, "safe_tile_state should not reuse mutable path table")
    end
    if path[3] == 1 then
      return { owner_id = 2, level = 1 }
    end
    if path[3] == 2 then
      return { owner_id = 3, level = 2 }
    end
    return nil
  end,
}

local game = { store = store }
local a = land_actions.safe_tile_state(game, { id = 1, type = "land" })
local b = land_actions.safe_tile_state(game, { id = 2, type = "land" })

assert(a.owner_id == 2 and a.level == 1, "first tile state mismatch")
assert(b.owner_id == 3 and b.level == 2, "second tile state mismatch")

print("Contract land_safe_tile_state_no_shared_path passed")
