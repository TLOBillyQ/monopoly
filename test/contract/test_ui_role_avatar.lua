local lu = require("luaunit")
local role_avatar = require("src.ui.view.role_avatar")
local logger = require("src.foundation.log")

-- 0 is the Eggy platform sentinel for "no avatar set" — it must return nil silently.
-- Negative values are genuinely invalid and must still warn.

TestUiRoleAvatar = {}

function TestUiRoleAvatar:test_sanitize_image_key_zero_returns_nil_no_warn()
  local warn_calls = 0
  local original_warn = logger.warn
  logger.warn = function(...)
    warn_calls = warn_calls + 1
    return original_warn(...)
  end
  local result = role_avatar.sanitize_image_key(0)
  logger.warn = original_warn
  lu.assertNil(result, "sanitize_image_key(0) must return nil")
  lu.assertIs(warn_calls, 0, "sanitize_image_key(0) must not call logger.warn")
end

function TestUiRoleAvatar:test_sanitize_image_key_negative_returns_nil_and_warns()
  local warn_calls = 0
  local original_warn = logger.warn
  logger.warn = function(...)
    warn_calls = warn_calls + 1
    return original_warn(...)
  end
  local result = role_avatar.sanitize_image_key(-1)
  logger.warn = original_warn
  lu.assertNil(result, "sanitize_image_key(-1) must return nil")
  lu.assertTrue(warn_calls >= 1, "sanitize_image_key(-1) must call logger.warn")
end

function TestUiRoleAvatar:test_sanitize_image_key_positive_returns_integer()
  local result = role_avatar.sanitize_image_key(42)
  lu.assertIs(result, 42, "sanitize_image_key(42) must return 42")
end


return TestUiRoleAvatar
