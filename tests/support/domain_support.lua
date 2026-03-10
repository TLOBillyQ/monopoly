local shared = require("support.shared_support")

local function pick(source, keys)
  local out = {}
  for _, key in ipairs(keys) do
    out[key] = source[key]
  end
  return out
end

return pick(shared, {
  "assert_eq",
  "with_patches",
  "build_ui_port",
  "new_game",
  "visited_tile_ids",
  "list_contains",
  "open_choice",
  "get_choice",
  "resolve_choice_first",
  "resolve_landing",
  "resolve_landing_with_choices",
  "first_land_tile",
  "first_tile_by_type",
  "first_adjacent_land_pair",
  "tile_state",
  "movement",
  "inventory",
  "executor",
  "pricing",
  "land_actions",
  "steal",
  "chance_effects",
  "choice_resolver",
  "board_utils",
  "map_cfg",
  "tiles_cfg",
})
