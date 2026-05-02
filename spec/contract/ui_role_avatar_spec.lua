local role_avatar = require("src.ui.view.role_avatar")
local logger = require("src.foundation.log.logger")

-- 0 is the Eggy platform sentinel for "no avatar set" — it must return nil silently.
-- Negative values are genuinely invalid and must still warn.
describe("ui_role_avatar_contract", function()
  it("sanitize_image_key_zero_returns_nil_no_warn", function()
    local warn_calls = 0
    local original_warn = logger.warn
    logger.warn = function(...)
      warn_calls = warn_calls + 1
      return original_warn(...)
    end
    local result = role_avatar.sanitize_image_key(0)
    logger.warn = original_warn
    assert.equals(nil, result, "sanitize_image_key(0) must return nil")
    assert.equals(0, warn_calls, "sanitize_image_key(0) must not call logger.warn")
  end)

  it("sanitize_image_key_negative_returns_nil_and_warns", function()
    local warn_calls = 0
    local original_warn = logger.warn
    logger.warn = function(...)
      warn_calls = warn_calls + 1
      return original_warn(...)
    end
    local result = role_avatar.sanitize_image_key(-1)
    logger.warn = original_warn
    assert.equals(nil, result, "sanitize_image_key(-1) must return nil")
    assert.is_true(warn_calls >= 1, "sanitize_image_key(-1) must call logger.warn")
  end)

  it("sanitize_image_key_positive_returns_integer", function()
    local result = role_avatar.sanitize_image_key(42)
    assert.equals(42, result, "sanitize_image_key(42) must return 42")
  end)
end)
