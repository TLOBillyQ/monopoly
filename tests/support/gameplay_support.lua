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
  "inventory",
  "executor",
  "steal",
  "choice_resolver",
  "gameplay_loop",
  "tick_timeout",
  "constants",
  "bankruptcy",
  "map_cfg",
  "tiles_cfg",
  "bind_ui_runtime",
  "with_patches",
  "build_ui_port",
  "open_choice",
  "get_choice",
  "resolve_choice_first",
  "resolve_landing",
  "resolve_landing_with_choices",
  "new_game",
  "first_land_tile",
  "first_tile_by_type",
  "tile_state",
  "runtime_state",
  "landing_visual_hold",
})
