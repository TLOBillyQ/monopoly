-- Mutation-pinning specs for src/ui/render/widgets/panel_action_controls.lua.
-- Drives the public apply_base_action_controls with a capturing ui stub so the
-- private _resolve_base_action_visibility decision table is observable.

local panel_action_controls = require("src.ui.render.widgets.panel_action_controls")
local base_nodes = require("src.ui.schema.base")

local function _capture_ui()
  local visible = {}
  return {
    visible = visible,
    set_visible = function(_, node, value) visible[node] = value end,
    set_touch_enabled = function() end,
  }
end

describe("panel_action_controls.apply_base_action_controls base_visible guard", function()
  it("hides all three base buttons when base_visible is not true (L28 'false')", function()
    -- base_visible=false must hide action/end/cancel together. Any 'false'->'true'
    -- mutation in the guard's return would leak one button visible.
    local ui = _capture_ui()
    panel_action_controls.apply_base_action_controls(ui, {}, false)
    assert(ui.visible[base_nodes.action_button] == false, "action must be hidden when base not visible")
    assert(ui.visible[base_nodes.end_button] == false, "end must be hidden when base not visible")
    assert(ui.visible[base_nodes.cancel_button] == false, "cancel must be hidden when base not visible")
  end)
end)
