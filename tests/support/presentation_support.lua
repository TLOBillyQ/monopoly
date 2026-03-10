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
  "bind_ui_runtime",
  "with_patches",
  "build_ui_port",
  "open_choice",
  "get_choice",
  "resolve_choice_first",
  "new_game",
  "choice_resolver",
  "gameplay_loop",
  "turn_anim",
  "tick_timeout",
  "constants",
  "turn_move",
})
