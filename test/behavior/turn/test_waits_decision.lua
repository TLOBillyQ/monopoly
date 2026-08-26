-- #293 批3 pin:src/turn/waits/decision.lua 无既有直测文件,11 个幸存者
-- 在 decide_choice_action 的 ctx 组装链(L18-20 缺省/短路变异)与
-- log_turn_start 的回合数钳制链(L36-37)加 tip 标志(L41)。
-- 策略:桩 choice_auto_policy.decide 与 event_feed.publish 捕获可观测面。

local lu = require("luaunit")
local turn_decision = require("src.turn.waits.decision")
local timing = require("src.config.gameplay.timing")
local choice_auto_policy = require("src.turn.policies.choice_auto")
local event_feed = require("src.rules.ports.event_feed")

local _saved_delay = timing.auto_decision_delay_seconds
local _saved_decide = choice_auto_policy.decide
local _saved_publish = event_feed.publish

local function _assert_eq(a, b, msg)
  lu.assertEvalToTrue(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local _decide_captured = nil
local _publish_captured = nil

TestWaitsDecision = {}

function TestWaitsDecision:setUp()
  _decide_captured = nil
  _publish_captured = nil
  choice_auto_policy.decide = function(game, actor, choice, ctx)
    _decide_captured = ctx
    return "decided"
  end
  event_feed.publish = function(game, event)
    _publish_captured = event
  end
end

function TestWaitsDecision:tearDown()
  timing.auto_decision_delay_seconds = _saved_delay
  choice_auto_policy.decide = _saved_decide
  event_feed.publish = _saved_publish
end

-- ============ decide_choice_action ============

function TestWaitsDecision:test_decide_ctx_carries_mode_pending_action_and_elapsed()
  -- L20 `mode = "wait_choice"` 换 nil、L19 `opts and opts.elapsed_seconds or 0`
  -- 的 and->or(opts 表整表进 elapsed)与 0->1(无 opts 时落 1):
  -- ctx 三字段必须按契约组装。
  timing.auto_decision_delay_seconds = nil
  local result = turn_decision.decide_choice_action({}, { id = "c" }, { type = "pick" }, {
    elapsed_seconds = 1.5,
  })
  _assert_eq(result, "decided", "decide result must pass through")
  _assert_eq(_decide_captured.mode, "wait_choice", "ctx mode must be wait_choice")
  _assert_eq(_decide_captured.pending_action.type, "pick", "ctx must carry the pending action")
  _assert_eq(_decide_captured.elapsed_seconds, 1.5, "explicit elapsed must carry through")
  _assert_eq(_decide_captured.min_visible_seconds, 0, "nil timing delay must default to 0")
end

function TestWaitsDecision:test_decide_ctx_defaults_elapsed_to_zero_without_opts()
  -- L19 `opts and opts.elapsed_seconds or 0` 的 0->1:无 opts 时 elapsed 必须 0。
  turn_decision.decide_choice_action({}, { id = "c" }, nil, nil)
  _assert_eq(_decide_captured.elapsed_seconds, 0, "no opts must yield elapsed 0")
end

function TestWaitsDecision:test_decide_ctx_carries_timing_delay_verbatim()
  -- L18 `timing.auto_decision_delay_seconds or 0` 的 or->and:配置的延迟必须
  -- 原样进 ctx,变异体 `delay and 0` 恒 0。
  timing.auto_decision_delay_seconds = 0.5
  turn_decision.decide_choice_action({}, { id = "c" }, nil, { elapsed_seconds = 0.1 })
  _assert_eq(_decide_captured.min_visible_seconds, 0.5, "configured delay must carry through")
end

-- ============ log_turn_start ============

function TestWaitsDecision:test_log_turn_start_publishes_next_turn_count_and_tip_false()
  -- L36 `game and game.turn and game.turn.turn_count or 0` 的 or->and
  -- (5 被 and 0 吃掉)与 L37 `(turn_count or 0) + 1` 的 or->and:
  -- 第 5 回合开始必须报「第6回合」;L41 `tip=false` -> true 必须为 false。
  local game = {
    turn = { turn_count = 5 },
    current_player = function()
      return { name = "甲" }
    end,
  }
  turn_decision.log_turn_start(game)
  _assert_eq(_publish_captured.kind, "turn_start", "event kind must be turn_start")
  lu.assertEvalToTrue(_publish_captured.text:find("第6回合", 1, true) ~= nil,
    "text must announce the next turn count: " .. tostring(_publish_captured.text))
  _assert_eq(_publish_captured.tip, false, "turn start must not tip")
end

function TestWaitsDecision:test_log_turn_start_defaults_missing_turn_count_to_first()
  -- L36 `... or 0` 的 0->1 与 L37 `(turn_count or 0) + 1` 的 0->1:
  -- 无 turn_count 时必须报「第1回合」。
  local game = {
    current_player = function()
      return { name = "乙" }
    end,
  }
  turn_decision.log_turn_start(game)
  lu.assertEvalToTrue(_publish_captured.text:find("第1回合", 1, true) ~= nil,
    "missing turn count must announce turn 1: " .. tostring(_publish_captured.text))
end

return TestWaitsDecision
