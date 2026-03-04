local gameplay_rules = require("src.core.config.GameplayRules")
local logger = require("src.core.Logger")
local ui_event_state = require("src.presentation.interaction.UIEventState")
local runtime = require("src.presentation.api.UIRuntimePort")

local debug_ports = {}

function debug_ports.build(common)
  return {
    log_status = function(view)
      common.log_status(view)
    end,
    sync_debug_log = function(state)
      state._debug_log_enabled_by_role = state._debug_log_enabled_by_role or {}
      state._debug_log_seq_by_role = state._debug_log_seq_by_role or {}
      local ui_view = require("src.presentation.api.UIViewService")
      runtime.for_each_role_or_global(function(role)
        local role_id = runtime.resolve_role_id(role)
        if role_id == nil then
          return
        end
        local debug_enabled = ui_event_state.resolve_debug_enabled(state, role_id)
        if state._debug_log_enabled_by_role[role_id] ~= debug_enabled then
          state._debug_log_enabled_by_role[role_id] = debug_enabled
          ui_view.set_debug_visible_for_role(state, role, debug_enabled)
          if debug_enabled then
            state._debug_log_seq_by_role[role_id] = nil
          else
            ui_view.set_debug_log_for_role(state, role, "")
          end
        end
        if debug_enabled then
          local seq = logger.get_seq()
          if seq ~= state._debug_log_seq_by_role[role_id] then
            state._debug_log_seq_by_role[role_id] = seq
            local max_lines = gameplay_rules.debug_log_max_lines or 50
            ui_view.set_debug_log_for_role(state, role, logger.get_text_by_level("event", max_lines))
          end
        end
      end)
      runtime.set_client_role(nil)
    end,
    resolve_debug_enabled = function(state, role_id)
      return ui_event_state.resolve_debug_enabled(state, role_id)
    end,
  }
end

return debug_ports
