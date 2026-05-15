local logger = require("src.foundation.log")
local debug_flags = require("src.config.gameplay.debug_flags")

local M = {}

function M.should_log()
  return logger.is_anim_debug_enabled() or debug_flags.move_anim_debug_log_enabled == true
end

function M.log(...)
  if not M.should_log() then
    return
  end
  logger.info_unlimited("[MoveAnim]", ...)
end

return M
