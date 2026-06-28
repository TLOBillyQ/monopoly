-- base_screen step-handler support: shared render-state assertions.
--
-- Pure read-only world queries shared across base_screen step sub-modules.
-- Kept separate from base_screen/render_flow_context.lua so the render-flow
-- support module stays under the per-file mutation-site budget; depends only
-- on the world render-state shape (no module-level requires).

local assert_helpers = {}

-- Assert a render-state node reports both `visible == true` and `touch == true`.
-- `label` is interpolated into the failure message to keep it human-readable.
function assert_helpers.node_visible_and_touchable(world, node, label)
  local state = world.base_screen_render_state
  local visible = state and state.ui and state.ui.visibility and state.ui.visibility[node]
  local touch = state and state.ui and state.ui.touch and state.ui.touch[node]
  if visible ~= true or touch ~= true then
    return nil, "expected " .. label .. " visible and touchable, visible="
      .. tostring(visible) .. " touch=" .. tostring(touch)
  end
  return true
end

return assert_helpers