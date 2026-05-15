---@diagnostic disable: undefined-global, undefined-field

local policy = require("src.app.policy")
local logger = require("src.foundation.log")
local event_feed = require("src.rules.ports.event_feed")
local event_feed_adapter = require("src.turn.output.event_feed_adapter")
local event_kinds = require("src.config.gameplay.event_kinds")
local event_log = require("src.state.event_log")

describe("contract.app.policy", function()
  local original_print
  local original_io_write
  local original_enabled
  local outputs

  before_each(function()
    original_print = print
    original_io_write = io.write
    original_enabled = logger.enabled
    outputs = {}

    -- luacheck: push ignore 121 122
    rawset(_G, "print", function(...)
      local parts = { ... }
      outputs[#outputs + 1] = table.concat(parts, " ")
    end)

    rawset(io, "write", function(...)
      local parts = { ... }
      outputs[#outputs + 1] = table.concat(parts, "")
      return true
    end)
    -- luacheck: pop

    logger.clear()
    logger.set_enabled(true)
  end)

  after_each(function()
    logger.set_enabled(true)
    logger.enabled = original_enabled
    -- luacheck: push ignore 121 122
    rawset(_G, "print", original_print)
    rawset(io, "write", original_io_write)
    -- luacheck: pop
    logger.clear()
  end)

  it("is_release returns true for release", function()
    assert.is_true(policy.is_release({ build_mode = "release" }))
  end)

  it("is_release returns false for debug", function()
    assert.is_false(policy.is_release({ build_mode = "debug" }))
  end)

  it("is_release returns false for non-release values", function()
    assert.is_false(policy.is_release({ build_mode = "dev" }))
  end)

  it("is_release returns false for nil", function()
    assert.is_false(policy.is_release(nil))
  end)

  it("logger info, warn, info_unlimited are silenced when disabled", function()
    logger.set_enabled(false)

    logger.info("test")
    logger.warn("test")
    logger.info_unlimited("test")

    assert.equals(0, #outputs)
  end)

  it("logger info, warn, info_unlimited emit output when enabled", function()
    logger.set_enabled(true)
    local sink_entries = {}
    logger.set_ui_sink(function(entry)
      sink_entries[#sink_entries + 1] = entry
    end)

    logger.info("test")
    logger.warn("test")
    logger.info_unlimited("test")

    logger.set_ui_sink(nil)
    assert.is_true(#sink_entries >= 3)
  end)

  it("event_feed publish is unaffected by logger set_enabled", function()
    logger.set_enabled(false)
    local game = {
      state = {},
    }
    game.event_feed_port = event_feed_adapter.new(game)

    local published = event_feed.publish(game, {
      kind = event_kinds.turn_start,
      text = "event still visible",
      tip = false,
    })

    assert.is_true(published)
    local entries = event_log.get_entries(game.state.event_log)
    assert.equals(1, #entries)
    assert.equals("event still visible", entries[1].text)
  end)
end)
