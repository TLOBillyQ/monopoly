local common = require("src.presentation.adapter.presentation_ports.Common")
local modal_ports = require("src.presentation.adapter.presentation_ports.ModalPorts")
local anim_ports = require("src.presentation.adapter.presentation_ports.AnimPorts")
local ui_sync_ports = require("src.presentation.adapter.presentation_ports.UISyncPorts")
local debug_ports = require("src.presentation.adapter.presentation_ports.DebugPorts")
local state_ports = require("src.presentation.adapter.presentation_ports.StatePorts")
local clock_ports = require("src.presentation.adapter.presentation_ports.ClockPorts")

local presentation_ports = {}

function presentation_ports.build()
  return {
    modal = modal_ports.build(),
    anim = anim_ports.build(),
    ui_sync = ui_sync_ports.build(common),
    debug = debug_ports.build(common),
    clock = clock_ports.build(),
    state = state_ports.build(),
  }
end

return presentation_ports
