local constants = require("src.config.content.constants")
local timing = require("src.config.gameplay.timing")
local ChoiceTimeout = require("src.turn.waits.choice_timeout")
local turn_dispatch = require("src.turn.actions.action_dispatcher")

local choice_timeout = {}

-- #602:构造面收窄至 7 键——resolve_output_ports / deadline_service /
-- resolve_choice / force_skip 四个不变量收进模块内部,适配器只透传可覆盖键;
-- resolve_choice_ui_state 由幽灵依赖升格必填键,默认给无屏回落形状。
function choice_timeout.new(overrides)
  overrides = overrides or {}
  local lifecycle = ChoiceTimeout.new({
    on_pending_choice = function(game_ctx, state_ctx, pending)
      if overrides.on_pending_choice then
        return overrides.on_pending_choice(state_ctx, pending, game_ctx)
      end
    end,
    is_choice_active = overrides.is_choice_active or function() return true end,
    resolve_choice_ui_state = overrides.resolve_choice_ui_state
      or function(_, _, choice)
        return { route_key = choice and choice.route_key or nil, should_warn = false }
      end,
    build_action = overrides.build_action or function() return nil end,
    dispatch_action_with_close_choice = overrides.dispatch_action_with_close_choice
      or function(game_ctx, state_ctx, action)
        return turn_dispatch.dispatch_action(game_ctx, state_ctx, action)
      end,
    get_timeout_seconds = overrides.get_timeout_seconds
      or function() return constants.action_timeout_seconds or 0 end,
    get_min_visible_seconds = overrides.get_min_visible_seconds
      or function() return timing.auto_decision_delay_seconds or 0 end,
  })
  return lifecycle
end

return choice_timeout
