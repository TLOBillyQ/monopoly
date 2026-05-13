local event_feed_adapter = require("src.turn.output.event_feed_adapter")
local tip_queue = require("src.foundation.coordination.tip_queue")

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

describe("event_feed_adapter: tip routing", function()
  it("routes tip through tip_output_port when available", function()
    local enqueued = {}
    local port = {
      enqueue = function(_, intent)
        enqueued[#enqueued + 1] = intent
      end,
    }
    local game = _build_game(port)
    local adapter = event_feed_adapter.new(game)

    adapter:publish(game, _build_event())

    assert.equals(1, #enqueued, "tip should be routed through tip_output_port")
    assert.equals("hello", enqueued[1].text, "intent text should match event text")
    assert.equals(2.0, enqueued[1].duration, "intent duration should match event tip_duration")
  end)

  it("falls back to tip_queue direct when tip_output_port is absent", function()
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

      assert.equals(1, #shown, "fallback should deliver tip via tip_queue when port absent")
      assert.equals("hello", shown[1], "fallback tip text should match event text")
    end)
  end)

  it("skips tip when event.tip is false", function()
    local enqueued = {}
    local port = {
      enqueue = function(_, __, intent)
        enqueued[#enqueued + 1] = intent
      end,
    }
    local game = _build_game(port)
    local adapter = event_feed_adapter.new(game)

    adapter:publish(game, _build_event({ tip = false }))

    assert.equals(0, #enqueued, "tip=false event should not be routed to port")
  end)

  it("still appends to event_log when tip is false", function()
    local game = _build_game(nil)
    local adapter = event_feed_adapter.new(game)

    adapter:publish(game, _build_event({ tip = false, text = "log only" }))

    local event_log = require("src.state.event_log")
    local entries = event_log.get_entries(game.state.event_log)
    assert.equals(1, #entries, "event should always appear in log regardless of tip flag")
    assert.equals("log only", entries[1].text)
  end)
end)

describe("tip_queue: diagnostics", function()
  it("snapshot reflects runtime state", function()
    _with_queue(function()
      local snap = tip_queue.snapshot()
      assert.is_false(snap.has_presenter, "presenter should be absent after clear")
      assert.is_false(snap.has_scheduler, "scheduler should be absent after clear")
      assert.equals(0, snap.pending_count, "pending count should be 0 after clear")
      assert.is_nil(snap.active_text, "active_text should be nil after clear")

      tip_queue.configure_runtime({
        presenter = function() end,
        scheduler = function() return true end,
      })
      local snap2 = tip_queue.snapshot()
      assert.is_true(snap2.has_presenter, "presenter should be present after configure")
      assert.is_true(snap2.has_scheduler, "scheduler should be present after configure")
    end)
  end)

  it("enqueue does not raise when presenter throws", function()
    _with_queue(function()
      tip_queue.configure_runtime({
        presenter = function()
          error("boom")
        end,
        scheduler = function() return true end,
      })

      local ok = tip_queue.enqueue({ text = "crasher", duration = 1.0 })
      assert.is_true(ok, "enqueue should return true even when presenter throws")
    end)
  end)

  it("enqueue silently drops when no presenter registered", function()
    _with_queue(function()
      local ok = tip_queue.enqueue({ text = "orphan", duration = 1.0 })
      assert.is_true(ok, "enqueue should accept intent even with no presenter")

      local snap = tip_queue.snapshot()
      assert.equals(0, snap.pending_count, "tip should be consumed/dispatched even if presenter is absent")
    end)
  end)
end)
