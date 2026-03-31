local debug_flags = require("src.config.gameplay.debug_flags")
local logger = require("src.core.utils.logger")

local debug_mod = {}

function debug_mod.should_debug_log()
  return logger.is_anim_debug_enabled() or debug_flags.move_anim_debug_log_enabled == true
end

function debug_mod.debug_log(...)
  if not debug_mod.should_debug_log() then
    return
  end
  logger.info_unlimited("[MoveAnim]", ...)
end

return debug_mod
