---@diagnostic disable: undefined-global, undefined-field, need-check-nil

local event_feed_adapter = require("src.turn.output.event_feed_adapter")
local event_log = require("src.state.event_log")
local loop_runtime = require("src.turn.loop.runtime")

describe("turn.output.event_feed_adapter", function()
  it("publish writes to event_log with HH:MM:SS time_text", function()
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

    adapter:publish(game, { kind = "turn_start", text = "第一回合" })

    local entries = event_log.get_entries(game.state.event_log)
    assert.equals(1, #entries)
    assert.equals("turn_start", entries[1].kind)
    assert.equals("第一回合", entries[1].text)
    assert.is_truthy(entries[1].time_text:match("^%d%d:%d%d:%d%d$"))
  end)

  it("tip not false enqueues tip intent with expected shape", function()
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

    adapter:publish(game, {
      kind = "test_event",
      text = "示例提示",
      tip_duration = 1.25,
      tip_dedupe_key = "rent:1",
      blocks_inter_turn = true,
      source = "spec",
    })

    assert.equals(game, captured_game)
    assert.equals("示例提示", captured_intent.text)
    assert.equals(1.25, captured_intent.duration)
    assert.equals("rent:1", captured_intent.dedupe_key)
    assert.equals(true, captured_intent.blocks_inter_turn)
    assert.equals("spec", captured_intent.source)
  end)

  it("tip port built by loop runtime receives intent as second arg", function()
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

    assert.equals("示例提示", captured_intent and captured_intent.text)
    assert.equals("event_feed:test_event", captured_intent and captured_intent.source)
  end)

  it("tip false skips enqueue", function()
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

    assert.equals(true, ok)
    assert.equals(0, enqueue_calls)
  end)

  it("tip_policy tip=false suppresses tip even when event.tip absent", function()
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

    adapter:publish(game, { kind = "rent_paid", text = "支付租金" })

    assert.equals(0, enqueue_calls)
    local entries = event_log.get_entries(game.state.event_log)
    assert.equals(1, #entries, "policy tip=false should still log")
  end)

  it("tip_policy tip=true overrides event.tip=false", function()
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

    assert.equals(1, enqueue_calls, "policy tip=true should enqueue regardless of event.tip")
  end)

  it("tip_policy log=false suppresses event_log entry", function()
    local game = {
      state = { event_log = event_log.new() },
      tip_output_port = { enqueue = function() return true end },
    }
    local adapter = event_feed_adapter.new(game)

    adapter:publish(game, { kind = "choice_skipped", text = "跳过选择", tip = false })

    local entries = event_log.get_entries(game.state.event_log)
    assert.equals(0, #entries, "policy log=false should suppress log entry")
  end)
end)
