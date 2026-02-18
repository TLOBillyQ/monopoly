local gameplay_rules = require("Config.GameplayRules")
local logger = require("src.core.Logger")
local tick_ui_sync = require("src.game.flow.turn.TickUISync")
local ui_event_state = require("src.presentation.interaction.UIEventState")

local M = {}

function M.build()
  return {
    log_status = function(view)
      tick_ui_sync.log_status(view)
    end,
    sync_debug_log = function(state)
      local debug_enabled = ui_event_state.resolve_debug_enabled(state)
      if state._debug_log_enabled ~= debug_enabled then
        state._debug_log_enabled = debug_enabled
        local ui_view = require("src.presentation.api.UIViewService")
        ui_view.set_debug_visible(state, debug_enabled)
        if debug_enabled then
          state._debug_log_seq = nil
        else
          ui_view.set_debug_log(state, "")
        end
      end
      if debug_enabled then
        local seq = logger.get_seq()
        if seq ~= state._debug_log_seq then
          state._debug_log_seq = seq
          local ui_view = require("src.presentation.api.UIViewService")
          local max_lines = gameplay_rules.debug_log_max_lines or 50
          ui_view.set_debug_log(state, logger.get_text_by_level("event", max_lines))
        end
      end
    end,
    resolve_debug_enabled = function(state)
      return ui_event_state.resolve_debug_enabled(state)
    end,
  }
end

return M
