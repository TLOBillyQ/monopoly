-- base_screen step handlers: end-button render-text / visibility assertions.
--
-- Covers the Gherkin steps that assert the end-button hidden / shown state,
-- the end-button label text, and the end-button extra-text invariant. Reads
-- world render state only; the handler key set here is owned by this
-- sub-module and merged by the aggregator.

local context = require("acceptance.steps.base_screen.context")
local render_flow_context = require("acceptance.steps.base_screen.render_flow_context")
local assert_helpers = require("acceptance.steps.base_screen.assert_helpers")
local base_nodes = context.base_nodes

local end_button_steps = {}

function end_button_steps.handlers()
  return {
    ["基础屏结束按钮已隐藏"] = function(world)
      return render_flow_context.assert_end_button_hidden(world)
    end,

    ["基础屏结束按钮已展示且可点击"] = function(world)
      return assert_helpers.node_visible_and_touchable(world, base_nodes.end_button, "end button")
    end,

    ['基础屏结束按钮文字为"结束"'] = function(world)
      local state = world.base_screen_render_state
      local ui = state and state.ui or {}
      local actual = ui.buttons and ui.buttons[base_nodes.end_button]
        or ui.labels and ui.labels[base_nodes.end_button]
      if actual ~= "结束" then
        return nil, "expected end button label 结束, got " .. tostring(actual)
      end
      return true
    end,

    ["基础屏结束按钮不额外写入文字"] = function(world)
      local state = world.base_screen_render_state
      local ui = state and state.ui or {}
      local button_text = ui.buttons and ui.buttons[base_nodes.end_button]
      local label_text = ui.labels and ui.labels[base_nodes.end_button]
      if button_text ~= nil or label_text ~= nil then
        return nil, "expected end button to skip extra text, button="
          .. tostring(button_text) .. " label=" .. tostring(label_text)
      end
      return true
    end,

    ["基础屏取消按钮已隐藏"] = function(world)
      local state = world.base_screen_render_state
      local actual = state and state.ui and state.ui.visibility and state.ui.visibility[base_nodes.cancel_button]
      if actual ~= false then
        return nil, "expected cancel button hidden, got " .. tostring(actual)
      end
      return true
    end,

    ["基础屏取消按钮已展示且可点击"] = function(world)
      return assert_helpers.node_visible_and_touchable(world, base_nodes.cancel_button, "cancel button")
    end,
  }
end

return end_button_steps