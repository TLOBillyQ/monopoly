local logger = require("src.core.utils.logger")
local timing = require("src.config.gameplay.timing")
local number_utils = require("src.core.utils.number")
local choice_auto_policy = require("src.turn.policies.choice_auto")

local turn_decision = {}

function turn_decision.build_turn_log_line(game)
  local player = game:current_player()
  return "玩家 " .. tostring(player.name)
end

function turn_decision.decide_choice_action(game, choice, pending_action, opts)
  opts = opts or {}
  local min_visible = timing.auto_decision_delay_seconds or 0
  local elapsed = opts.elapsed_seconds or 0
  local action = choice_auto_policy.decide(game, nil, choice, {
    mode = "wait_choice",
    pending_action = pending_action,
    min_visible_seconds = min_visible,
    elapsed_seconds = elapsed,
  })
  if action then
    return action
  end
  return nil
end

function turn_decision.resolve_choice(game, choice, action)
  return require("src.core.choice.resolver").resolve(game, choice, action) or {}
end

function turn_decision.log_turn_start(game)
  local turn_count = game and game.turn and game.turn.turn_count or 0
  local next_turn_count = number_utils.format_integer_part((turn_count or 0) + 1)
  logger.event_no_tips("第" .. next_turn_count .. "回合开始：" .. turn_decision.build_turn_log_line(game))
end

return turn_decision
