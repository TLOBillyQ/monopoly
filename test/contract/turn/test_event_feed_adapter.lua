---@diagnostic disable: undefined-global, undefined-field, need-check-nil

local lu = require("luaunit")
local event_feed_adapter = require("src.turn.output.event_feed_adapter")
local event_log = require("src.state.event_log")
local loop_runtime = require("src.turn.loop.runtime")
local tip_queue = require("src.foundation.tips")

-- 原生 LuaUnit:三个 describe 按钩子边界拍平——外层无钩子并入 TestEventFeedAdapter,
-- 内层「tip routing」「tip_queue: diagnostics」各有 before_each/after_each →
-- 拆成两个带 setUp/tearDown 的子类,共享的 tip_queue helper 提到文件级共用。

TestEventFeedAdapter = {}

function TestEventFeedAdapter:test_publish_writes_to_event_log_with_hhmmss_time_text()
  local game = {
    state = {
      event_log = event_log.new(),
    },
    tip_output_port = {
      enqueue = function()
        return true
      end,
    },
  }
  local adapter = event_feed_adapter.new(game)

  adapter:publish(game, { kind = "test_event", text = "第一回合" })

  local entries = event_log.get_entries(game.state.event_log)
  lu.assertIs(#entries, 1)
  lu.assertIs(entries[1].kind, "test_event")
  lu.assertIs(entries[1].text, "第一回合")
  lu.assertEvalToTrue(entries[1].time_text:match("^%d%d:%d%d:%d%d$"))
end

function TestEventFeedAdapter:test_publish_syncs_visible_content_after_appending()
  local synced_text
  local game = {
    state = { event_log = event_log.new() },
    tip_output_port = { enqueue = function() return true end },
  }
  local adapter = event_feed_adapter.new(game, function()
    synced_text = event_log.get_text(game.state.event_log)
  end)

  adapter:publish(game, { kind = "test_event", text = "实时结果", tip = false })

  lu.assertNotNil(synced_text)
  lu.assertNotNil(synced_text:match("实时结果$"),
    "the sync boundary must observe the newly appended action result")
end

function TestEventFeedAdapter:test_choice_picked_is_not_persisted_in_the_action_log()
  local game = {
    state = { event_log = event_log.new() },
    tip_output_port = { enqueue = function() return true end },
  }
  local adapter = event_feed_adapter.new(game)

  adapter:publish(game, { kind = "choice_picked", text = "等待选择：购买地块", tip = false })

  lu.assertIs(#event_log.get_entries(game.state.event_log), 0,
    "opening a choice is not an action result")
end

function TestEventFeedAdapter:test_turn_start_is_not_persisted_in_the_action_log()
  local game = {
    state = { event_log = event_log.new() },
    tip_output_port = { enqueue = function() return true end },
  }
  local adapter = event_feed_adapter.new(game)

  adapter:publish(game, { kind = "turn_start", text = "回合开始", tip = false })

  lu.assertIs(#event_log.get_entries(game.state.event_log), 0,
    "turn boundaries are not action results")
end

function TestEventFeedAdapter:test_market_auto_skipped_is_persisted_in_the_action_log_without_tip()
  local enqueued = 0
  local game = {
    state = { event_log = event_log.new() },
    tip_output_port = { enqueue = function() enqueued = enqueued + 1 return true end },
  }
  local adapter = event_feed_adapter.new(game)
  adapter:publish(game, { kind = "market_auto_skipped", text = "P1 (AI) 到达黑市，选择不购买", tip = false })
  local entries = event_log.get_entries(game.state.event_log)
  lu.assertIs(#entries, 1, "a delegated seat must be able to read that the market was skipped")
  lu.assertIs(entries[1].text, "P1 (AI) 到达黑市，选择不购买")
  lu.assertIs(enqueued, 0, "the skip is a log line, not a tip")
end

function TestEventFeedAdapter:test_tip_not_false_enqueues_tip_intent_with_expected_shape()
  local captured_game = nil
  local captured_intent = nil
  local game = {
    state = {},
    tip_output_port = {
      enqueue = function(arg_game, intent)
        captured_game = arg_game
        captured_intent = intent
        return true
      end,
    },
  }
  local adapter = event_feed_adapter.new(game)

  local published = adapter:publish(game, {
    kind = "test_event",
    text = "示例提示",
    tip_duration = 1.25,
    tip_dedupe_key = "rent:1",
    blocks_inter_turn = true,
    source = "spec",
  })

  lu.assertIs(published, true, "publish should report success after enqueueing the tip")
  lu.assertIs(captured_game, game)
  lu.assertIs(captured_intent.text, "示例提示")
  lu.assertIs(captured_intent.duration, 1.25)
  lu.assertIs(captured_intent.dedupe_key, "rent:1")
  lu.assertIs(captured_intent.blocks_inter_turn, true)
  lu.assertIs(captured_intent.source, "spec")
end

function TestEventFeedAdapter:test_tip_port_built_by_loop_runtime_receives_intent_as_second_arg()
  local captured_intent = nil
  local state = {
    show_tip = function(_, intent)
      captured_intent = intent
      return true
    end,
  }
  local game = {
    state = {},
    tip_output_port = loop_runtime.build_tip_output_port(state),
  }
  local adapter = event_feed_adapter.new(game)

  adapter:publish(game, {
    kind = "test_event",
    text = "示例提示",
  })

  lu.assertIs(captured_intent and captured_intent.text, "示例提示")
  lu.assertIs(captured_intent and captured_intent.source, "event_feed:test_event")
end

function TestEventFeedAdapter:test_tip_false_skips_enqueue()
  local enqueue_calls = 0
  local game = {
    state = {},
    tip_output_port = {
      enqueue = function()
        enqueue_calls = enqueue_calls + 1
        return true
      end,
    },
  }
  local adapter = event_feed_adapter.new(game)

  local ok = adapter:publish(game, {
    kind = "test_event",
    text = "无 tip",
    tip = false,
  })

  lu.assertIs(ok, true)
  lu.assertIs(enqueue_calls, 0)
end

function TestEventFeedAdapter:test_tip_policy_tip_false_suppresses_tip_even_when_event_tip_absent()
  local enqueue_calls = 0
  local game = {
    state = { event_log = event_log.new() },
    tip_output_port = {
      enqueue = function()
        enqueue_calls = enqueue_calls + 1
        return true
      end,
    },
  }
  local adapter = event_feed_adapter.new(game)

  adapter:publish(game, { kind = "dice_roll", text = "掷骰子" })

  lu.assertIs(enqueue_calls, 0)
  local entries = event_log.get_entries(game.state.event_log)
  lu.assertIs(#entries, 1, "policy tip=false should still log")
end

function TestEventFeedAdapter:test_tip_policy_tip_true_overrides_event_tip_false()
  local enqueue_calls = 0
  local game = {
    state = { event_log = event_log.new() },
    tip_output_port = {
      enqueue = function()
        enqueue_calls = enqueue_calls + 1
        return true
      end,
    },
  }
  local adapter = event_feed_adapter.new(game)

  adapter:publish(game, { kind = "rent_multiplier_breakdown", text = "南山广场 租金 ×3", tip = false })

  lu.assertIs(enqueue_calls, 1, "policy tip=true should enqueue regardless of event.tip")
end

function TestEventFeedAdapter:test_tip_policy_log_false_suppresses_event_log_entry()
  local game = {
    state = { event_log = event_log.new() },
    tip_output_port = { enqueue = function() return true end },
  }
  local adapter = event_feed_adapter.new(game)

  adapter:publish(game, { kind = "choice_skipped", text = "跳过选择", tip = false })

  local entries = event_log.get_entries(game.state.event_log)
  lu.assertIs(#entries, 0, "policy log=false should suppress log entry")
end

function TestEventFeedAdapter:test_publish_lands_in_event_log_independently_of_the_logger()
  local game = {
    state = {},
    tip_output_port = { enqueue = function() return true end },
  }
  game.state.event_log = event_log.new()
  local adapter = event_feed_adapter.new(game)

  local published = adapter:publish(game, {
    kind = "test_event",
    text = "event still visible",
    tip = false,
  })

  lu.assertTrue(published)
  local entries = event_log.get_entries(game.state.event_log)
  lu.assertIs(#entries, 1)
  lu.assertIs(entries[1].text, "event still visible")
end

local function _reset_tip_queue()
  tip_queue.clear()
  tip_queue.configure_runtime({
    clear_presenter = true,
    clear_scheduler = true,
    test_mode = false,
  })
end

local function _with_queue(fn)
  _reset_tip_queue()
  local ok, err = pcall(fn)
  _reset_tip_queue()
  if not ok then
    error(err, 2)
  end
end

local function _build_game(tip_port_override)
  local game = { state = { event_log = require("src.state.event_log").new() } }
  if tip_port_override ~= nil then
    game.tip_output_port = tip_port_override
  end
  return game
end

local function _build_event(overrides)
  local base = { kind = "test_event", text = "hello", tip_duration = 2.0 }
  if overrides then
    for k, v in pairs(overrides) do
      base[k] = v
    end
  end
  return base
end

TestEventFeedAdapterTipRouting = {}

function TestEventFeedAdapterTipRouting:setUp()
  _reset_tip_queue()
end

function TestEventFeedAdapterTipRouting:tearDown()
  _reset_tip_queue()
end

function TestEventFeedAdapterTipRouting:test_routes_tip_through_tip_output_port_when_available()
  local enqueued = {}
  local port = {
    enqueue = function(_, intent)
      enqueued[#enqueued + 1] = intent
    end,
  }
  local game = _build_game(port)
  local adapter = event_feed_adapter.new(game)

  adapter:publish(game, _build_event())

  lu.assertIs(#enqueued, 1, "tip should be routed through tip_output_port")
  lu.assertIs(enqueued[1].text, "hello", "intent text should match event text")
  lu.assertIs(enqueued[1].duration, 2.0, "intent duration should match event tip_duration")
end

function TestEventFeedAdapterTipRouting:test_intent_duration_falls_back_to_default_when_event_has_none()
  -- L42 `timing.event_tip_default_seconds or 1.0` 的 or->and:事件不带
  -- tip_duration 时必须采用配置默认(2.0),变异体把默认压成 1.0。
  local enqueued = {}
  local port = {
    enqueue = function(_, intent)
      enqueued[#enqueued + 1] = intent
    end,
  }
  local game = _build_game(port)
  local adapter = event_feed_adapter.new(game)

  adapter:publish(game, { kind = "test_event", text = "无时长事件" })

  lu.assertIs(#enqueued, 1, "tip should still be enqueued without tip_duration")
  lu.assertIs(enqueued[1].duration, 2.0, "intent duration should fall back to the configured default")
end

function TestEventFeedAdapterTipRouting:test_falls_back_to_tip_queue_direct_when_tip_output_port_is_absent()
  _with_queue(function()
    local shown = {}
    tip_queue.configure_runtime({
      presenter = function(text)
        shown[#shown + 1] = text
      end,
      scheduler = function(_, fn)
        fn()
        return true
      end,
      test_mode = true,
    })

    local game = _build_game(nil)
    local adapter = event_feed_adapter.new(game)
    adapter:publish(game, _build_event())

    lu.assertIs(#shown, 1, "fallback should deliver tip via tip_queue when port absent")
    lu.assertIs(shown[1], "hello", "fallback tip text should match event text")
  end)
end

function TestEventFeedAdapterTipRouting:test_skips_tip_when_event_tip_is_false()
  local enqueued = {}
  local port = {
    enqueue = function(_, __, intent)
      enqueued[#enqueued + 1] = intent
    end,
  }
  local game = _build_game(port)
  local adapter = event_feed_adapter.new(game)

  adapter:publish(game, _build_event({ tip = false }))

  lu.assertIs(#enqueued, 0, "tip=false event should not be routed to port")
end

function TestEventFeedAdapterTipRouting:test_still_appends_to_event_log_when_tip_is_false()
  local game = _build_game(nil)
  local adapter = event_feed_adapter.new(game)

  adapter:publish(game, _build_event({ tip = false, text = "log only" }))

  local entries = event_log.get_entries(game.state.event_log)
  lu.assertIs(#entries, 1, "event should always appear in log regardless of tip flag")
  lu.assertIs(entries[1].text, "log only")
end

TestTipQueueDiagnostics = {}

function TestTipQueueDiagnostics:setUp()
  _reset_tip_queue()
end

function TestTipQueueDiagnostics:tearDown()
  _reset_tip_queue()
end

function TestTipQueueDiagnostics:test_snapshot_reflects_runtime_state()
  _with_queue(function()
    local snap = tip_queue.snapshot()
    lu.assertFalse(snap.has_presenter, "presenter should be absent after clear")
    lu.assertFalse(snap.has_scheduler, "scheduler should be absent after clear")
    lu.assertIs(snap.pending_count, 0, "pending count should be 0 after clear")
    lu.assertNil(snap.active_text, "active_text should be nil after clear")

    tip_queue.configure_runtime({
      presenter = function() end,
      scheduler = function() return true end,
    })
    local snap2 = tip_queue.snapshot()
    lu.assertTrue(snap2.has_presenter, "presenter should be present after configure")
    lu.assertTrue(snap2.has_scheduler, "scheduler should be present after configure")
  end)
end

function TestTipQueueDiagnostics:test_enqueue_does_not_raise_when_presenter_throws()
  _with_queue(function()
    tip_queue.configure_runtime({
      presenter = function()
        error("boom")
      end,
      scheduler = function() return true end,
    })

    local ok = tip_queue.enqueue({ text = "crasher", duration = 1.0 })
    lu.assertTrue(ok, "enqueue should return true even when presenter throws")
  end)
end

function TestTipQueueDiagnostics:test_enqueue_silently_drops_when_no_presenter_registered()
  _with_queue(function()
    local ok = tip_queue.enqueue({ text = "orphan", duration = 1.0 })
    lu.assertTrue(ok, "enqueue should accept intent even with no presenter")

    local snap = tip_queue.snapshot()
    lu.assertIs(snap.pending_count, 0, "tip should be consumed/dispatched even if presenter is absent")
  end)
end


-- mutate 车道统一返回全部类（#283 多类文件 return 首类假幸存方向）：
-- 正常车道扫 _G 收全部 Test* 类，但 mutate 内建 runner 只跑 return 的表，
-- 只 return 首个类会让其余类的用例在变异车道完全不执行。合并全部类，
-- 每个 test* 方法跑所属类 setUp/tearDown（见 multi_class_return）。
return require("test.support.multi_class_return").merge(
  TestEventFeedAdapter,
  TestEventFeedAdapterTipRouting,
  TestTipQueueDiagnostics
)
