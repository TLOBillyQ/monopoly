local common = require("src.presentation.runtime.presentation_ports.common")
local modal_ports = require("src.presentation.runtime.presentation_ports.modal_ports")
local anim_ports = require("src.presentation.runtime.presentation_ports.anim_ports")
local ui_sync_ports = require("src.presentation.runtime.presentation_ports.ui_sync_ports")
local debug_ports = require("src.presentation.runtime.presentation_ports.debug_ports")
local state_ports = require("src.presentation.runtime.presentation_ports.state_ports")
local clock_ports = require("src.presentation.runtime.presentation_ports.clock_ports")

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
