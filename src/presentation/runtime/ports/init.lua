local common = require("src.presentation.runtime.ports.common")
local modal_ports = require("src.presentation.runtime.ports.modal_ports")
local anim_ports = require("src.presentation.runtime.ports.anim_ports")
local ui_sync_ports = require("src.presentation.runtime.ports.ui_sync_ports")
local debug_ports = require("src.presentation.runtime.ports.debug_ports")
local state_ports = require("src.presentation.runtime.ports.state_ports")
local clock_ports = require("src.presentation.runtime.ports.clock_ports")
local view_command_ports = require("src.presentation.runtime.ports.view_command_ports")
local actor_context_ports = require("src.presentation.runtime.ports.actor_context_ports")

local presentation_ports = {}

function presentation_ports.build()
  return {
    modal = modal_ports.build(),
    anim = anim_ports.build(),
    ui_sync = ui_sync_ports.build(common),
    debug = debug_ports.build(common),
    clock = clock_ports.build(),
    state = state_ports.build(),
    view_command = view_command_ports.build(),
    actor_context = actor_context_ports.build(),
  }
end

return presentation_ports
