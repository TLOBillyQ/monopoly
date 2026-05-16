local debug_flags = require("src.config.gameplay.debug_flags")
local logger = require("src.foundation.log")

local debug_mod = {}

local function _should_debug_log()
  return logger.is_anim_debug_enabled() or debug_flags.move_anim_debug_log_enabled == true
end

debug_mod.enabled = _should_debug_log

function debug_mod.debug_log(...)
  if not _should_debug_log() then
    return
  end
  logger.info_unlimited("[MoveAnim]", ...)
end

return debug_mod
