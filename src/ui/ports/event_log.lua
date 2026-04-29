local debug_flags = require("src.config.gameplay.debug_flags")
local with_client_role = require("src.core.utils.with_client_role")
local logger = require("src.core.utils.logger")
local event_log = require("src.state.event_log")
local ui_event_state = require("src.ui.ctl.event_state")
local runtime = require("src.ui.render.runtime_ui")
local role_id_utils = require("src.core.utils.role_id")

local event_log_ports = {}

local function _resolve_event_text(game, max_lines)
  local logger_text = logger.get_text_by_level("event", max_lines)
  if game and game.state and game.state.event_log then
    local feed_text = event_log.get_text(game.state.event_log, max_lines)
    if feed_text and feed_text ~= "" then
      return feed_text
    end
  end
  return logger_text or ""
end

function event_log_ports.build(common)
  return {
    log_status = function(view)
      common.log_status(view)
    end,
    sync_event_log = function(state)
      state._debug_log_enabled_by_role = state._debug_log_enabled_by_role or {}
      state._debug_log_seq_by_role = state._debug_log_seq_by_role or {}
      local ui_view = require("src.ui.ctl.ui_runtime")
      runtime.for_each_role_or_global(function(role)
        local role_id = role_id_utils.normalize(runtime.resolve_role_id(role))
        if role_id == nil then
          return
        end
        with_client_role(runtime, role, function()
          local event_log_enabled = ui_event_state.resolve_event_log_enabled(state, role_id)
          if role_id_utils.read(state._debug_log_enabled_by_role, role_id) ~= event_log_enabled then
            role_id_utils.write(state._debug_log_enabled_by_role, role_id, event_log_enabled)
            ui_view.set_event_log_visible_for_role(state, role, event_log_enabled)
            if event_log_enabled then
              role_id_utils.write(state._debug_log_seq_by_role, role_id, nil)
            else
              ui_view.set_event_log_for_role(state, role, "")
            end
          end
          if event_log_enabled then
            local seq = logger.get_event_seq()
            if seq ~= role_id_utils.read(state._debug_log_seq_by_role, role_id) then
              role_id_utils.write(state._debug_log_seq_by_role, role_id, seq)
              local max_lines = debug_flags.debug_log_max_lines or 50
              ui_view.set_event_log_for_role(state, role, _resolve_event_text(state and state.game, max_lines))
            end
          end
        end)
      end)
      runtime.set_client_role(nil)
    end,
    resolve_event_log_enabled = function(state, role_id)
      return ui_event_state.resolve_event_log_enabled(state, role_id)
    end,
  }
end

return event_log_ports
