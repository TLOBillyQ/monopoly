local luassert = assert

---@diagnostic disable: undefined-global, undefined-field, need-check-nil
local event_feed_adapter = require("src.turn.output.event_feed_adapter")
local event_log = require("src.state.event_log")
local loop_runtime = require("src.turn.loop.runtime")
local tip_queue = require("src.foundation.tips")

describe("TestEventFeedAdapter", function()

it("test_publish_writes_to_event_log_with_hhmmss_time_text", function()
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
  luassert.is.equal(1, #entries)
  luassert.is.equal("test_event", entries[1].kind)
  luassert.is.equal("第一回合", entries[1].text)
  luassert.truthy(entries[1].time_text:match("^%d%d:%d%d:%d%d$"))
end)

it("test_publish_syncs_visible_content_after_appending", function()
  local synced_text
  local game = {
    state = { event_log = event_log.new() },
    tip_output_port = { enqueue = function() return true end },
  }
  local adapter = event_feed_adapter.new(game, function()
    synced_text = event_log.get_text(game.state.event_log)
  end)

  adapter:publish(game, { kind = "test_event", text = "实时结果", tip = false })

  luassert.is_not_nil(synced_text)
  luassert.is_not_nil(synced_text:match("实时结果$"),
    "the sync boundary must observe the newly appended action result")
end)

it("test_choice_picked_is_not_persisted_in_the_action_log", function()
  local game = {
    state = { event_log = event_log.new() },
    tip_output_port = { enqueue = function() return true end },
  }
  local adapter = event_feed_adapter.new(game)

  adapter:publish(game, { kind = "choice_picked", text = "等待选择：购买地块", tip = false })

  luassert.is.equal(0, #event_log.get_entries(game.state.event_log),
    "opening a choice is not an action result")
end)

it("test_turn_start_is_not_persisted_in_the_action_log", function()
  local game = {
    state = { event_log = event_log.new() },
    tip_output_port = { enqueue = function() return true end },
  }
  local adapter = event_feed_adapter.new(game)

  adapter:publish(game, { kind = "turn_start", text = "回合开始", tip = false })

  luassert.is.equal(0, #event_log.get_entries(game.state.event_log),
    "turn boundaries are not action results")
end)

it("test_market_auto_skipped_is_persisted_in_the_action_log_without_tip", function()
  local enqueued = 0
  local game = {
    state = { event_log = event_log.new() },
    tip_output_port = { enqueue = function() enqueued = enqueued + 1 return true end },
  }
  local adapter = event_feed_adapter.new(game)
  adapter:publish(game, { kind = "market_auto_skipped", text = "P1 (AI) 到达黑市，选择不购买", tip = false })
  local entries = event_log.get_entries(game.state.event_log)
  luassert.is.equal(1, #entries, "a delegated seat must be able to read that the market was skipped")
  luassert.is.equal("P1 (AI) 到达黑市，选择不购买", entries[1].text)
  -- lint-allow: call-count tip_output_port 经 game 注入,enqueue 次数即提示策略的对外输出
  luassert.is.equal(0, enqueued, "the skip is a log line, not a tip")
end)

it("test_tip_not_false_enqueues_tip_intent_with_expected_shape", function()
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

  luassert.is.equal(true, published, "publish should report success after enqueueing the tip")
  luassert.is.equal(game, captured_game)
  luassert.is.equal("示例提示", captured_intent.text)
  luassert.is.equal(1.25, captured_intent.duration)
  luassert.is.equal("rent:1", captured_intent.dedupe_key)
  luassert.is.equal(true, captured_intent.blocks_inter_turn)
  luassert.is.equal("spec", captured_intent.source)
end)

it("test_tip_port_built_by_loop_runtime_receives_intent_as_second_arg", function()
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

  luassert.is.equal("示例提示", captured_intent and captured_intent.text)
  luassert.is.equal("event_feed:test_event", captured_intent and captured_intent.source)
end)

it("test_tip_false_skips_enqueue", function()
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

  luassert.is.equal(true, ok)
  -- lint-allow: call-count tip_output_port 经 game 注入,enqueue 次数即提示策略的对外输出
  luassert.is.equal(0, enqueue_calls)
end)

it("test_tip_policy_tip_false_suppresses_tip_even_when_event_tip_absent", function()
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

  -- lint-allow: call-count tip_output_port 经 game 注入,enqueue 次数即提示策略的对外输出
  luassert.is.equal(0, enqueue_calls)
  local entries = event_log.get_entries(game.state.event_log)
  luassert.is.equal(1, #entries, "policy tip=false should still log")
end)

it("test_tip_policy_tip_true_overrides_event_tip_false", function()
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

  -- lint-allow: call-count tip_output_port 经 game 注入,enqueue 次数即提示策略的对外输出
  luassert.is.equal(1, enqueue_calls, "policy tip=true should enqueue regardless of event.tip")
end)

it("test_tip_policy_log_false_suppresses_event_log_entry", function()
  local game = {
    state = { event_log = event_log.new() },
    tip_output_port = { enqueue = function() return true end },
  }
  local adapter = event_feed_adapter.new(game)

  adapter:publish(game, { kind = "choice_skipped", text = "跳过选择", tip = false })

  local entries = event_log.get_entries(game.state.event_log)
  luassert.is.equal(0, #entries, "policy log=false should suppress log entry")
end)

it("test_publish_lands_in_event_log_independently_of_the_logger", function()
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

  luassert.is_true(published)
  local entries = event_log.get_entries(game.state.event_log)
  luassert.is.equal(1, #entries)
  luassert.is.equal("event still visible", entries[1].text)
end)

end)

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

describe("TestEventFeedAdapterTipRouting", function()

before_each(function()
  _reset_tip_queue()
end)

after_each(function()
  _reset_tip_queue()
end)

it("test_routes_tip_through_tip_output_port_when_available", function()
  local enqueued = {}
  local port = {
    enqueue = function(_, intent)
      enqueued[#enqueued + 1] = intent
    end,
  }
  local game = _build_game(port)
  local adapter = event_feed_adapter.new(game)

  adapter:publish(game, _build_event())

  luassert.is.equal(1, #enqueued, "tip should be routed through tip_output_port")
  luassert.is.equal("hello", enqueued[1].text, "intent text should match event text")
  luassert.is.equal(2.0, enqueued[1].duration, "intent duration should match event tip_duration")
end)

it("test_intent_duration_falls_back_to_default_when_event_has_none", function()
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

  luassert.is.equal(1, #enqueued, "tip should still be enqueued without tip_duration")
  luassert.is.equal(2.0, enqueued[1].duration, "intent duration should fall back to the configured default")
end)

it("test_falls_back_to_tip_queue_direct_when_tip_output_port_is_absent", function()
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

    luassert.is.equal(1, #shown, "fallback should deliver tip via tip_queue when port absent")
    luassert.is.equal("hello", shown[1], "fallback tip text should match event text")
  end)
end)

it("test_skips_tip_when_event_tip_is_false", function()
  local enqueued = {}
  local port = {
    enqueue = function(_, __, intent)
      enqueued[#enqueued + 1] = intent
    end,
  }
  local game = _build_game(port)
  local adapter = event_feed_adapter.new(game)

  adapter:publish(game, _build_event({ tip = false }))

  luassert.is.equal(0, #enqueued, "tip=false event should not be routed to port")
end)

it("test_still_appends_to_event_log_when_tip_is_false", function()
  local game = _build_game(nil)
  local adapter = event_feed_adapter.new(game)

  adapter:publish(game, _build_event({ tip = false, text = "log only" }))

  local entries = event_log.get_entries(game.state.event_log)
  luassert.is.equal(1, #entries, "event should always appear in log regardless of tip flag")
  luassert.is.equal("log only", entries[1].text)
end)

end)

describe("TestTipQueueDiagnostics", function()

before_each(function()
  _reset_tip_queue()
end)

after_each(function()
  _reset_tip_queue()
end)

it("test_snapshot_reflects_runtime_state", function()
  _with_queue(function()
    local snap = tip_queue.snapshot()
    luassert.is_false(snap.has_presenter, "presenter should be absent after clear")
    luassert.is_false(snap.has_scheduler, "scheduler should be absent after clear")
    luassert.is.equal(0, snap.pending_count, "pending count should be 0 after clear")
    luassert.is_nil(snap.active_text, "active_text should be nil after clear")

    tip_queue.configure_runtime({
      presenter = function() end,
      scheduler = function() return true end,
    })
    local snap2 = tip_queue.snapshot()
    luassert.is_true(snap2.has_presenter, "presenter should be present after configure")
    luassert.is_true(snap2.has_scheduler, "scheduler should be present after configure")
  end)
end)

it("test_enqueue_does_not_raise_when_presenter_throws", function()
  _with_queue(function()
    tip_queue.configure_runtime({
      presenter = function()
        error("boom")
      end,
      scheduler = function() return true end,
    })

    local ok = tip_queue.enqueue({ text = "crasher", duration = 1.0 })
    luassert.is_true(ok, "enqueue should return true even when presenter throws")
  end)
end)

it("test_enqueue_silently_drops_when_no_presenter_registered", function()
  _with_queue(function()
    local ok = tip_queue.enqueue({ text = "orphan", duration = 1.0 })
    luassert.is_true(ok, "enqueue should accept intent even with no presenter")

    local snap = tip_queue.snapshot()
    luassert.is.equal(0, snap.pending_count, "tip should be consumed/dispatched even if presenter is absent")
  end)
end)

end)
