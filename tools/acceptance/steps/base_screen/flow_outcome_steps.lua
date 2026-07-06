-- base_screen step handlers: optional-action flow-outcome observations.
--
-- Covers the Gherkin steps that observe the optional-action choice entry, the
-- secondary-confirm presence, the dispatched end action, the required /
-- follow-up flow outcomes, the empty-choice invariant, the action-button
-- non-progression guard during optional action, and the passive-view
-- expectation. Reads world render state, ui model, and recorded intents; the
-- handler key set here is owned by this sub-module and merged by the
-- aggregator.

local context = require("acceptance.steps.base_screen.context")
local render_flow_context = require("acceptance.steps.base_screen.render_flow_context")
local base_nodes = context.base_nodes

local flow_outcome_steps = {}

function flow_outcome_steps.handlers()
  return {
    ["基础屏行动按钮未作为可点击推进入口"] = function(world)
      local state = world.base_screen_render_state
      local touch = state and state.ui and state.ui.touch and state.ui.touch[base_nodes.action_button]
      if touch == true then
        return nil, "action button should not be touchable during optional action"
      end
      local intent = render_flow_context.build_base_intent(world, base_nodes.action_button)
      if intent ~= nil then
        return nil, "action button should not build progression intent during optional action"
      end
      return true
    end,

    ["<可选行动>仍可作为主动选择入口"] = function(world, example)
      local expected = tostring(example["可选行动"] or "")
      local choice = world.base_screen_ui_model and world.base_screen_ui_model.choice or nil
      local actual = choice and choice.meta and choice.meta.optional_action or nil
      if actual ~= expected then
        return nil, "expected optional action entry " .. expected .. ", got " .. tostring(actual)
      end
      return true
    end,

    ["没有打开二次确认弹窗"] = function(world)
      local screen = world.base_screen_render_state
        and world.base_screen_render_state.ui
        and world.base_screen_render_state.ui.active_choice_screen_key
      if screen == "secondary_confirm" or world.base_screen_secondary_confirm_open == true then
        return nil, "secondary confirm should not open"
      end
      return true
    end,

    ["未派发通用结束动作"] = function(world)
      local intent = world.base_screen_end_button_intent or world.base_screen_action_button_intent
      if intent and intent.type == "ui_button" and (intent.id == "end" or intent.id == "end_turn") then
        return nil, "generic end action was dispatched"
      end
      return true
    end,

    ["后续必经流程未被跳过"] = function(world)
      if world.base_screen_followup_flow == nil then
        return nil, "follow-up required flow was skipped"
      end
      return true
    end,

    ["可选行动阶段不会停在空选择入口"] = function(world)
      local choice = world.base_screen_ui_model and world.base_screen_ui_model.choice or nil
      if choice ~= nil then
        return nil, "empty optional phase should not create a choice"
      end
      return true
    end,

    ["基础屏只展示被动当前回合提示"] = function(world)
      local state = world.base_screen_render_state
      local action_touch = state and state.ui and state.ui.touch and state.ui.touch[base_nodes.action_button]
      if action_touch == true then
        return nil, "passive view should not expose action touch"
      end
      local ok, err = render_flow_context.assert_end_button_hidden(world)
      if not ok then
        return nil, err
      end
      return true
    end,

    ["玩家投骰子并移动"] = function(world)
      if world.base_screen_dice_rolled ~= true then
        return nil, "dice was not rolled"
      end
      if world.base_screen_move_completed ~= true then
        return nil, "player did not move"
      end
      return true
    end,

    ["玩家跳过 pre-action 道具使用"] = function(world)
      local action = world.base_screen_action_button_intent
      if action == nil or action.type ~= "ui_button" or action.id ~= "next" then
        return nil, "action button did not skip pre-action item phase"
      end
      world.base_screen_pre_action_skipped = true
      world.base_screen_dice_rolled = true
      world.base_screen_move_completed = true
      return true
    end,

    ["玩家跳过 post-action 道具使用"] = function(world)
      local action = world.base_screen_end_button_intent
      if action == nil or action.type ~= "complete_optional_action_phase" then
        return nil, "end button did not skip post-action item phase"
      end
      world.base_screen_post_action_skipped = true
      return true
    end,

    ["当前回合结束"] = function(world)
      if world.base_screen_turn_ended ~= true and world.base_screen_post_action_skipped ~= true then
        return nil, "turn was not ended"
      end
      return true
    end,

    ["轮到下一玩家"] = function(world)
      if world.base_screen_next_player ~= true and world.base_screen_turn_ended ~= true then
        return nil, "turn did not advance to next player"
      end
      return true
    end,

    ["关闭目标选择界面"] = function(world)
      if world.base_screen_target_choice ~= nil then
        return nil, "target selection was not closed"
      end
      return true
    end,

    ["返回到道具槽选择界面"] = function(world)
      local choice = world.base_screen_ui_model and world.base_screen_ui_model.choice
      if choice ~= nil then
        return nil, "expected item slot selection to be closed"
      end
      world.base_screen_item_slot_selection_open = true
      return true
    end,

    ["该道具未被消耗"] = function(world)
      local item_name = world.base_screen_target_choice_item_consumed
      if item_name ~= nil then
        return nil, "item was consumed: " .. tostring(item_name)
      end
      return true
    end,
  }
end

return flow_outcome_steps