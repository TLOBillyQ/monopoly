local shared = require("support.shared_support")

local function pick(source, keys)
  local out = {}
  for _, key in ipairs(keys) do
    out[key] = source[key]
  end
  return out
end

return pick(shared, {
  "app",
  "movement",
  "turn_move",
  "gameplay_loop",
  "tick_timeout",
  "constants",
  "bankruptcy",
  "map_cfg",
  "tiles_cfg",
  "number_utils",
  "assert_eq",
  "bind_ui_runtime",
  "with_patches",
  "build_ui_port",
  "open_choice",
  "get_choice",
  "new_game",
  "first_adjacent_land_pair",
  "tile_state",
})
