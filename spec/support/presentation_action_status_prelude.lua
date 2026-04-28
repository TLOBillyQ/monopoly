local support = require("spec.support.presentation_support")
local runtime_state = require("src.ui.state")

local M = {
  new_game = support.new_game,
  build_ui_port = support.build_ui_port,
  open_choice = support.open_choice,
  get_choice = support.get_choice,
  assert_eq = support.assert_eq,
  bind_ui_runtime = support.bind_ui_runtime,
  with_patches = support.with_patches,
  wrap_ui_refs = support.wrap_ui_refs,
  build_popup_view_state = support.build_popup_view_state,
  build_role_with_events = support.build_role_with_events,
  has_event = support.has_event,
  build_choice_modal_state = support.build_choice_modal_state,
  build_target_pick_env = support.build_target_pick_env,
  tick_timeout = support.tick_timeout,
  gameplay_loop = support.gameplay_loop,
}

function M.ui_runtime(state)
  return runtime_state.ensure_ui_runtime(state)
end

return M
