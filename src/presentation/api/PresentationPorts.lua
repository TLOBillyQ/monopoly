local common = require("src.presentation.api.presentation_ports.Common")
local modal_ports = require("src.presentation.api.presentation_ports.ModalPorts")
local anim_ports = require("src.presentation.api.presentation_ports.AnimPorts")
local ui_sync_ports = require("src.presentation.api.presentation_ports.UISyncPorts")
local debug_ports = require("src.presentation.api.presentation_ports.DebugPorts")
local state_ports = require("src.presentation.api.presentation_ports.StatePorts")

local presentation_ports = {}

function presentation_ports.build()
  return {
    modal = modal_ports.build(),
    anim = anim_ports.build(),
    ui_sync = ui_sync_ports.build(common),
    debug = debug_ports.build(common),
    state = state_ports.build(),
  }
end

return presentation_ports
