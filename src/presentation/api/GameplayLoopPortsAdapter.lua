local modal_ports = require("src.presentation.api.ports.ModalPorts")
local anim_ports = require("src.presentation.api.ports.AnimPorts")
local ui_sync_ports = require("src.presentation.api.ports.UISyncPorts")
local debug_ports = require("src.presentation.api.ports.DebugPorts")
local state_ports = require("src.presentation.api.ports.StatePorts")

local adapter = {}

function adapter.build(_)
  return {
    modal = modal_ports.build(),
    anim = anim_ports.build(),
    ui_sync = ui_sync_ports.build(),
    debug = debug_ports.build(),
    state = state_ports.build(),
  }
end

return adapter
