-- base_screen step handlers: render-state and model-content assertions.
--
-- Covers the Gherkin steps that assert render-state visibility / touchability
-- / labels, the auxiliary-entry input-lock guards, and the skin-entry
-- visibility observations. Reads world render state and ui model only; the
-- handler key set here is owned by this sub-module and merged by the
-- aggregator. Optional-action / secondary-confirm / follow-up outcome
-- observations live in base_screen/flow_outcome_steps.lua.

local context = require("acceptance.steps.base_screen.context")
local assert_helpers = require("acceptance.steps.base_screen.assert_helpers")
local number_utils = context.number_utils
local base_nodes = context.base_nodes

local assert_steps = {}

function assert_steps.handlers()
  return {
    ["基础屏当前行动角色ID为<预期行动角色ID>"] = function(world, example)
      local expected = number_utils.to_integer(example["预期行动角色ID"])
      if expected == nil then
        return nil, "invalid expected action role_id: " .. tostring(example["预期行动角色ID"])
      end
      local actual = world.base_screen_ui_model and world.base_screen_ui_model.current_player_id or nil
      if actual ~= expected then
        return nil, "expected current action role_id " .. tostring(expected) .. ", got " .. tostring(actual)
      end
      return true
    end,

    ["基础屏<入口>未被输入锁隐藏"] = function(world, example)
      local node = context.auxiliary_entry_node(example["入口"])
      if node == nil then
        return nil, "unknown base auxiliary entry: " .. tostring(example["入口"])
      end
      local state = world.base_screen_render_state
      local actual = state and state.ui and state.ui.visibility and state.ui.visibility[node]
      if actual == false then
        return nil, "expected " .. node .. " not hidden by input lock"
      end
      return true
    end,

    ["基础屏<入口>未被输入锁禁用"] = function(world, example)
      local node = context.auxiliary_entry_node(example["入口"])
      if node == nil then
        return nil, "unknown base auxiliary entry: " .. tostring(example["入口"])
      end
      local state = world.base_screen_render_state
      local actual = state and state.ui and state.ui.touch and state.ui.touch[node]
      if actual ~= true then
        return nil, "expected " .. node .. " explicitly enabled by input lock, got " .. tostring(actual)
      end
      return true
    end,

    ['基础屏托管按钮文字为"<按钮文字>"'] = function(world, example)
      local expected = tostring(example["按钮文字"] or "")
      local panel = world.base_screen_panel or {}
      local role_id = context.role_id(world)
      local by_player = panel.auto_label_by_player or {}
      local actual = by_player[role_id] or panel.auto_label
      if actual ~= expected then
        return nil, "expected base auto label " .. expected .. ", got " .. tostring(actual)
      end
      return true
    end,

    ["基础屏行动按钮已展示且可点击"] = function(world)
      return assert_helpers.node_visible_and_touchable(world, base_nodes.action_button, "action button")
    end,

    ["基础屏皮肤<节点>已隐藏"] = function(world, example)
      local node = context.SKIN_ENTRY_NODES[tostring(example["节点"] or "")]
      if node == nil then
        return nil, "unknown skin entry node: " .. tostring(example["节点"])
      end
      local state = world.base_screen_render_state
      local actual = state and state.ui and state.ui.visibility and state.ui.visibility[node]
      if actual ~= false then
        return nil, "expected " .. node .. " hidden, got " .. tostring(actual)
      end
      return true
    end,

    ["基础屏皮肤<节点>已展示"] = function(world, example)
      local node = context.SKIN_ENTRY_NODES[tostring(example["节点"] or "")]
      if node == nil then
        return nil, "unknown skin entry node: " .. tostring(example["节点"])
      end
      local state = world.base_screen_render_state
      local actual = state and state.ui and state.ui.visibility and state.ui.visibility[node]
      if actual ~= true then
        return nil, "expected " .. node .. " visible, got " .. tostring(actual)
      end
      return true
    end,
  }
end

return assert_steps