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