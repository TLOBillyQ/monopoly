-- base_screen step handlers: role / observer / control / turn setup.
--
-- Covers the Gherkin steps that establish who is acting and how the panel
-- observes them. Pure delegation to base_screen context helpers; the handler
-- key set here is owned by this sub-module and merged by the aggregator.

local context = require("acceptance.steps.base_screen.context")

local role_observance_steps = {}

function role_observance_steps.handlers()
  return {
    ["玩家托管状态为<托管状态>"] = function(world, example)
      local enabled, err = context.parse_auto_state(example["托管状态"])
      if enabled == nil and err ~= nil then
        return nil, err
      end
      world.base_screen_auto_enabled = enabled
      return true
    end,

    ["基础屏刷新"] = function(world)
      local role_id = context.role_id(world)
      world.base_screen_panel = context.panel_slice.build(
        context.make_game(),
        { game = { board = {} } },
        { turn_count = 1, countdown_seconds = 0 },
        role_id,
        context.make_auto_enabled_by_player(world)
      )
      return true
    end,

    ["玩家角色ID为<观察角色ID>"] = function(world, example)
      return context.set_role_id(world, example["观察角色ID"])
    end,

    ["观察身份为<观察身份>"] = function(world, example)
      local identity = tostring(example["观察身份"] or "")
      if identity ~= "旁观角色" then
        return nil, "unknown observer identity: " .. identity
      end
      world.ui_role_id = 99
      world.base_screen_viewer_is_spectator = true
      return true
    end,

    ["当前轮到角色ID为<行动角色ID>"] = function(world, example)
      return context.set_current_action_role(world, example, "行动角色ID")
    end,

    ["当前轮到角色ID为<角色ID>"] = function(world, example)
      return context.set_current_action_role(world, example, "角色ID")
    end,

    ["当前行动控制为人类"] = function(world)
      world.base_screen_action_control = "人类"
      world.base_screen_input_blocked = false
      return true
    end,

    ["当前行动控制为<行动控制>"] = function(world, example)
      local control = tostring(example["行动控制"] or "")
      if control ~= "人类" and control ~= "AI" and control ~= "托管" then
        return nil, "unknown action control: " .. control
      end
      world.base_screen_action_control = control
      if control ~= "人类" then
        world.base_screen_input_blocked = true
      end
      return true
    end,

    ["当前轮次未定"] = function(world)
      world.base_screen_action_role_id = nil
      world.base_screen_action_role_unset = true
      return true
    end,
  }
end

return role_observance_steps