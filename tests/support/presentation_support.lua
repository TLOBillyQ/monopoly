local shared = require("support.shared_support")
local ui_fixture = require("support.presentation_ui_fixture_support")

local function pick(source, keys)
  local out = {}
  for _, key in ipairs(keys) do
    out[key] = source[key]
  end
  return out
end

local M = pick(shared, {
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

M.wrap_ui_refs = ui_fixture.wrap_ui_refs
M.build_popup_view_state = ui_fixture.build_popup_view_state
M.build_role_with_events = ui_fixture.build_role_with_events
M.has_event = ui_fixture.has_event
M.build_choice_modal_state = ui_fixture.build_choice_modal_state
M.build_target_pick_env = ui_fixture.build_target_pick_env

return M
