local timing = require("src.config.gameplay.timing")
local number_utils = require("src.foundation.number")
local choice_auto_policy = require("src.turn.policies.choice_auto")
local event_kinds = require("src.config.gameplay.event_kinds")
local event_feed = require("src.rules.ports.event_feed")
local choice_resolver = require("src.rules.choice.resolver")

local turn_decision = {}

local _decide_ctx = {
  mode = nil,
  pending_action = nil,
  min_visible_seconds = nil,
  elapsed_seconds = nil,
}

function turn_decision.decide_choice_action(game, choice, pending_action, opts)
  local min_visible = timing.auto_decision_delay_seconds or 0
  local elapsed = opts and opts.elapsed_seconds or 0
  _decide_ctx.mode = "wait_choice"
  _decide_ctx.pending_action = pending_action
  _decide_ctx.min_visible_seconds = min_visible
  _decide_ctx.elapsed_seconds = elapsed
  return choice_auto_policy.decide(game, nil, choice, _decide_ctx)
end

function turn_decision.resolve_choice(game, choice, action)
  return choice_resolver.resolve(game, choice, action, {
    on_event = function(event)
      event_feed.publish(game, event)
    end,
  }) or {}
end

function turn_decision.log_turn_start(game)
  local turn_count = game and game.turn and game.turn.turn_count or 0
  local next_turn_count = number_utils.format_integer_part((turn_count or 0) + 1)
  event_feed.publish(game, {
    kind = event_kinds.turn_start,
    text = "第" .. next_turn_count .. "回合开始：玩家 " .. tostring(game:current_player().name),
    tip = false,
  })
end

return turn_decision

--[[ mutate4lua-manifest
version=2
projectHash=83667677902d6b2f
scope.0.id=chunk:src/turn/waits/decision.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=46
scope.0.semanticHash=fff00fcb020e4d18
scope.1.id=function:turn_decision.decide_choice_action:17
scope.1.kind=function
scope.1.startLine=17
scope.1.endLine=25
scope.1.semanticHash=fd42e58a99045f27
scope.2.id=function:anonymous@29:29
scope.2.kind=function
scope.2.startLine=29
scope.2.endLine=31
scope.2.semanticHash=db9d382bb5a2bf46
scope.3.id=function:turn_decision.resolve_choice:27
scope.3.kind=function
scope.3.startLine=27
scope.3.endLine=33
scope.3.semanticHash=0c175eaca8a4bb87
scope.4.id=function:turn_decision.log_turn_start:35
scope.4.kind=function
scope.4.startLine=35
scope.4.endLine=43
scope.4.semanticHash=4fdb5cf85ea96e59
]]
