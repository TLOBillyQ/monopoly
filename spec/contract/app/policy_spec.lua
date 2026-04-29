---@diagnostic disable: undefined-global, undefined-field

local policy = require("src.app.policy")
local logger = require("src.core.utils.logger")

describe("contract.app.policy", function()
  local original_print
  local original_io_write
  local original_enabled
  local original_event_provider
  local outputs

  before_each(function()
    original_print = print
    original_io_write = io.write
    original_enabled = logger.enabled
    original_event_provider = logger.event_collection_enabled_provider
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
    logger.set_event_collection_enabled_provider(nil)
    logger.set_enabled(true)
  end)

  after_each(function()
    logger.set_enabled(true)
    logger.set_event_collection_enabled_provider(original_event_provider)
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

    logger.info("test")
    logger.warn("test")
    logger.info_unlimited("test")

    assert.is_true(#outputs >= 3)
  end)

  it("logger event is unaffected by set_enabled", function()
    logger.set_enabled(false)

    logger.event("event still visible")

    assert.equals(1, #outputs)
  end)
end)
