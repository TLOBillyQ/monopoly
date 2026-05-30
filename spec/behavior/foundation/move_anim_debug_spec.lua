local move_anim_debug = require("src.foundation.move_anim_debug")
local logger = require("src.foundation.log")
local debug_flags = require("src.config.gameplay.debug_flags")
local config_reset = require("spec.support.config_reset")

local function _set_provider(value)
  logger.set_anim_debug_enabled_provider(function() return value end)
end

describe("foundation.move_anim_debug.enabled", function()
  before_each(function()
    config_reset.reset_all()
    logger.set_anim_debug_enabled_provider(nil)
    logger.clear()
  end)
  after_each(function()
    logger.set_anim_debug_enabled_provider(nil)
    config_reset.reset_all()
    logger.clear()
  end)

  it("returns false when both provider and flag are off", function()
    debug_flags.move_anim_debug_log_enabled = false
    assert(move_anim_debug.enabled() == false, "expected false when neither source enabled")
  end)

  it("returns true when logger provider returns true and flag is false", function()
    _set_provider(true)
    debug_flags.move_anim_debug_log_enabled = false
    assert(move_anim_debug.enabled() == true, "expected true from logger provider arm")
  end)

  it("returns true when flag is true and logger provider is off", function()
    logger.set_anim_debug_enabled_provider(nil)
    debug_flags.move_anim_debug_log_enabled = true
    assert(move_anim_debug.enabled() == true, "expected true from debug_flags arm")
  end)

  it("returns true when both sources are enabled", function()
    _set_provider(true)
    debug_flags.move_anim_debug_log_enabled = true
    assert(move_anim_debug.enabled() == true, "expected true when both enabled")
  end)

  it("returns false when flag is truthy non-boolean (== true strips non-bool)", function()
    logger.set_anim_debug_enabled_provider(nil)
    debug_flags.move_anim_debug_log_enabled = "yes"
    assert(move_anim_debug.enabled() == false, "expected false when flag is non-bool truthy because == true is enforced")
  end)
end)

describe("foundation.move_anim_debug.log", function()
  before_each(function()
    config_reset.reset_all()
    logger.set_anim_debug_enabled_provider(nil)
    logger.clear()
  end)
  after_each(function()
    logger.set_anim_debug_enabled_provider(nil)
    config_reset.reset_all()
    logger.clear()
  end)

  it("does not push when disabled", function()
    debug_flags.move_anim_debug_log_enabled = false
    move_anim_debug.log("suppressed_payload")
    local text = logger.get_text()
    assert(not text:find("suppressed_payload"), "expected payload not logged when disabled")
    assert(not text:find("MoveAnim"), "expected MoveAnim tag absent when disabled")
  end)

  it("pushes with [MoveAnim] tag when enabled via flag", function()
    debug_flags.move_anim_debug_log_enabled = true
    move_anim_debug.log("tagged_payload_one", "tagged_payload_two")
    local text = logger.get_text()
    assert(text:find("%[MoveAnim%]"), "expected [MoveAnim] tag in log text: " .. tostring(text))
    assert(text:find("tagged_payload_one"), "expected first payload arg in log text")
    assert(text:find("tagged_payload_two"), "expected second payload arg in log text")
  end)

  it("pushes with [MoveAnim] tag when enabled via provider", function()
    _set_provider(true)
    debug_flags.move_anim_debug_log_enabled = false
    move_anim_debug.log("provider_payload")
    local text = logger.get_text()
    assert(text:find("%[MoveAnim%]"), "expected [MoveAnim] tag when provider enables")
    assert(text:find("provider_payload"), "expected payload from provider-enabled log")
  end)
end)
