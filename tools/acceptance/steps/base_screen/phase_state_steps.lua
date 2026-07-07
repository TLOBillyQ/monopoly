-- base_screen step handlers: scenario world-state setup.
--
-- Covers the Gherkin steps that place the base screen into a phase, blocking
-- state, stage state, or secondary-confirm state, plus the refresh and
-- input-lock refresh steps. Delegates validation and bookkeeping to
-- base_screen context helpers; the handler key set here is owned by this
-- sub-module and merged by the aggregator.

local context = require("acceptance.steps.base_screen.context")
local render_flow_context = require("acceptance.steps.base_screen.render_flow_context")
local ui_runtime = context.ui_runtime

local phase_state_steps = {}

function phase_state_steps.handlers()
  return {
    ["输入门已锁"] = function(world)
      world.base_screen_input_blocked = true
      return true
    end,

    ["玩家处于行动等待阶段"] = function(world)
      world.base_screen_optional_action = nil
      world.base_screen_empty_optional_phase = false
      world.base_screen_stage_state = "行动等待阶段"
      return true
    end,

    ["玩家处于包含<可选行动>的可选行动阶段"] = function(world, example)
      return context.set_optional_action_phase(world, example["可选行动"])
    end,

    ["行动角色处于包含<可选行动>的可选行动阶段"] = function(world, example)
      return context.set_optional_action_phase(world, example["可选行动"])
    end,

    ["没有阻断性界面或动画等待"] = function(world)
      world.base_screen_input_blocked = false
      world.base_screen_blocking_state = nil
      return true
    end,

    ["<阻断状态>正在生效"] = function(world, example)
      return context.set_blocking_state(world, example["阻断状态"])
    end,

    ["通用二次确认屏因<触发源>而显示"] = function(world, example)
      local source = tostring(example["触发源"] or "")
      local valid_sources = {
        ["购买地块"] = true,
        ["加盖建筑"] = true,
        ["强征卡"] = true,
        ["免税卡"] = true,
      }
      if valid_sources[source] ~= true then
        return nil, "unknown secondary confirm trigger: " .. source
      end
      local ok, err = context.set_blocking_state(world, "二次确认弹窗")
      if not ok then
        return nil, err
      end
      world.base_screen_secondary_confirm_open = true
      world.base_screen_secondary_confirm_trigger = source
      return true
    end,

    ["玩家处于<阶段状态>"] = function(world, example)
      return context.set_stage_state(world, example["阶段状态"])
    end,

    ["玩家点击道具槽位1进入目标选择"] = function(world, example)
      local item_name = tostring(example["道具名"] or "")
      return context.enter_item_target_selection(world, item_name)
    end,

    ["玩家背包中有<道具名>"] = function(world, example)
      return context.give_item(world, example["道具名"])
    end,

    ["玩家背包中还有<第二道具名>"] = function(world, example)
      return context.give_item(world, example["第二道具名"])
    end,

    ["<道具名>可在行动前使用"] = function(world, example)
      return context.set_item_phase(world, example["道具名"], "pre_action")
    end,

    ["<道具名>可在行动后使用"] = function(world, example)
      return context.set_item_phase(world, example["道具名"], "post_action")
    end,

    ["玩家已投骰子并完成移动"] = function(world)
      return context.set_dice_rolled_and_moved(world)
    end,

    ["玩家落在可购买的无主地块"] = function(world)
      return context.set_landed_buyable_property(world)
    end,

    ["买地选择界面显示时"] = function(world)
      local ok, err = context.show_buy_property_choice(world)
      if not ok then
        return nil, err
      end
      render_flow_context.refresh_base_screen_for_player(world)
      return true
    end,

    ["所有强制落地选择已处理完毕"] = function(world)
      return context.resolve_forced_landing_choices(world)
    end,

    ["倒计时已超时"] = function(world)
      return context.set_countdown_timeout(world)
    end,

    ["弹窗提示导致输入锁定"] = function(world)
      return context.set_blocking_state(world, "弹窗提示")
    end,

    ["基础屏为该玩家刷新"] = function(world)
      render_flow_context.refresh_base_screen_for_player(world)
      return true
    end,

    ["基础屏为观察玩家刷新"] = function(world)
      render_flow_context.refresh_base_screen_for_player(world)
      return true
    end,

    ["基础屏为观察身份刷新"] = function(world)
      render_flow_context.refresh_base_screen_for_player(world)
      return true
    end,

    ["基础屏刷新后应用输入锁"] = function(world)
      world.base_screen_input_blocked = true
      ui_runtime.apply_input_lock(render_flow_context.refresh_base_screen_for_player(world))
      return true
    end,
  }
end

return phase_state_steps