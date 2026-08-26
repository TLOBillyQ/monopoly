local common = require("src.ui.ports.common")
local modal_ports = require("src.ui.ports.modal")
local anim_ports = require("src.ui.ports.anim")
local ui_sync_ports = require("src.ui.ports.ui_sync")
local event_log_ports = require("src.ui.ports.event_log")
local state_ports = require("src.ui.ports.state")
local clock_ports = require("src.ui.ports.clock")
local view_command_ports = require("src.ui.ports.view_command")
local actor_context_ports = require("src.ui.ports.actor_context")

local presentation_ports = {}
local boundary_contract = {
  state_seam_modules = {
    runtime_state = "src.ui.state.runtime",
    visual_hold = "src.ui.visual_hold",
    host_runtime = "src.ui.seams.host_runtime",
  },
  import_allowlists = {
    runtime_state = {
      "src.ui.state.runtime",
    },
    visual_hold = {
      "src.ui.visual_hold",
    },
    host_runtime = {
      "src.ui.seams.host_runtime",
      "src.ui.ports.state",
      "src.app.ui_bootstrap",
      "src.app.event_bridge",
    },
  },
  state_field_allowlists = {
    presentation_runtime = {
      "src.app.gameplay_start",
      "src.turn.loop",
      "src.ui.render.anim",
       "src.ui.render.anim.overlay_runtime",
      "src.ui.render.board.building_effects",
      "src.ui.render.board.visual_sync",
       "src.ui.render.board_feedback.service",
       "src.ui.render.market",
       "src.ui.render.market.controls",
      "src.ui.render.status3d",
       "src.ui.render.anim.unit_overlay",
      "src.ui.render.widgets.presenter",
      "src.ui.render.widgets.turn_effects",
      "src.ui.ports.anim",
    },
    gameplay_loop_ports = {
      "src.app.gameplay_start",
      "src.turn.loop",
      "src.turn.actions.action_dispatcher",
      "src.turn.waits.choice_timeout",
      "src.turn.waits.modal_timeout",
      "src.turn.waits.ui_gate",
      "src.ui.input.item_phase_ask",
      "src.ui.input.pre_confirm",
      "src.ui.input.turn_action",
      "src.ui.input.view_command",
    },
    resolved_gameplay_loop_ports = {
      "src.turn.loop",
      "src.turn.actions.action_dispatcher",
      "src.turn.waits.choice_timeout",
      "src.turn.waits.modal_timeout",
    },
    game = {
      "src.app.event_bridge",
      "src.turn.loop",
      "src.turn.loop.runtime",
      "src.turn.actions.validator",
      "src.ui.coord.event_handlers",
      "src.ui.coord.modal",
      "src.ui.render.anim.overlay_compute",
      "src.ui.render.anim.tip_text",
      "src.ui.render.board_feedback.service",
      "src.ui.render.board.visual_sync",
    },
  },
}

function presentation_ports.build()
  local debug = event_log_ports.build()
  return {
    modal = modal_ports.build(),
    anim = anim_ports.build(),
    ui_sync = ui_sync_ports.build(common),
    debug = debug,
    clock = clock_ports.build(),
    state = state_ports.build(),
    view_command = view_command_ports.build({ sync_event_log = debug.sync_event_log }),
    actor_context = actor_context_ports.build(),
  }
end

function presentation_ports.describe_boundary_contract()
  return boundary_contract
end

return presentation_ports

--[[ mutate4lua-manifest
version=4
projectHash=22909d715d291cc4
scope.0.id=chunk:src/ui/ports/init.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=101
scope.0.semanticHash=2cfff9d3759ff8f7
scope.1.id=function:presentation_ports.build
scope.1.kind=function
scope.1.startLine=82
scope.1.endLine=94
scope.1.semanticHash=b8b3c06918de14eb
scope.2.id=function:presentation_ports.describe_boundary_contract
scope.2.kind=function
scope.2.startLine=96
scope.2.endLine=98
scope.2.semanticHash=1136505bd37c301e
]]
