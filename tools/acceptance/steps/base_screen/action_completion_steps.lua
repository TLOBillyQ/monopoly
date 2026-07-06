-- base_screen step handlers: actions and optional-action completion flow.
--
-- Covers the Gherkin steps that trigger the action / end buttons, drive the
-- optional-action completion through the runtime, observe the required /
-- follow-up flow outcomes, and assert invariant guards around the end button
-- dispatch and the timeout path. Delegates to base_screen context helpers;
-- the handler key set here is owned by this sub-module and merged by the
-- aggregator.

local context = require("acceptance.steps.base_screen.context")
local render_flow_context = require("acceptance.steps.base_screen.render_flow_context")
local choice_auto_policy = context.choice_auto_policy
local base_nodes = context.base_nodes

local action_completion_steps = {}

function action_completion_steps.handlers()
  return {
    ["触发基础屏行动按钮"] = function(world)
      render_flow_context.trigger_action_button(world)
      return true
    end,

    ["玩家进入必经回合流程"] = function(world)
      if world.base_screen_required_flow_started ~= true then
        return nil, "action button did not enter required flow"
      end
      return true
    end,

    ["触发基础屏结束按钮"] = function(world)
      render_flow_context.trigger_end_button(world)
      return true
    end,

    ["触发基础屏取消按钮"] = function(world)
      local intent = render_flow_context.build_base_intent(world, base_nodes.cancel_button)
      world.base_screen_cancel_button_intent = intent
      if intent and intent.type == "choice_cancel" then
        render_flow_context.cancel_optional_action(world, intent, "user")
      end
      return true
    end,

    ["系统自动执行主按钮操作"] = function(world)
      local stage = world.base_screen_stage_state
      if stage == "行动等待阶段" then
        render_flow_context.trigger_action_button(world)
      else
        render_flow_context.trigger_end_button(world)
      end
      return true
    end,

    ["玩家完成可选行动阶段"] = function(world)
      if world.base_screen_optional_completed ~= true then
        return nil, "optional phase was not completed"
      end
      return true
    end,

    ["当前待处理选择已按完成语义清除"] = function(world)
      if world.base_screen_pending_choice_cleared ~= true then
        return nil, "pending choice was not cleared by completion"
      end
      return true
    end,

    ["回合继续到<后续流程>"] = function(world, example)
      local expected = tostring(example["后续流程"] or "")
      local actual = world.base_screen_followup_flow
      if expected == "必经流程" then
        if actual == nil then
          return nil, "expected any required follow-up flow"
        end
        return true
      end
      if actual ~= expected then
        return nil, "expected follow-up flow " .. expected .. ", got " .. tostring(actual)
      end
      return true
    end,

    ["可选行动阶段超时"] = function(world)
      if world.base_screen_render_state == nil then
        render_flow_context.refresh_base_screen_for_player(world)
      end
      local intent = choice_auto_policy.decide(render_flow_context.make_completion_game(world), world.base_screen_render_state,
        world.base_screen_ui_model and world.base_screen_ui_model.choice or nil,
        { mode = "tick_timeout" })
      world.base_screen_timeout_intent = intent
      if intent and intent.type == "complete_optional_action_phase" then
        render_flow_context.complete_optional_action(world, intent, "timer")
      end
      return true
    end,

    ["未触发基础屏行动按钮"] = function(world)
      if world.base_screen_action_button_triggered == true then
        return nil, "action button should not have been triggered"
      end
      return true
    end,

    ["基础屏结束按钮不可派发完成可选行动阶段"] = function(world)
      local ok, err = render_flow_context.assert_end_button_not_touchable(world)
      if not ok then
        return nil, err
      end
      if world.base_screen_input_blocked == true or (world.base_screen_ui_model and world.base_screen_ui_model.choice) == nil then
        local intent = render_flow_context.build_base_intent(world, base_nodes.end_button)
        if intent ~= nil then
          return nil, "end button built an intent while blocked or without optional choice"
        end
      end
      return true
    end,
  }
end

return action_completion_steps