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
    landing_visual_hold = "src.ui.visual_hold",
    host_runtime = "src.ui.host_bridge",
  },
  import_allowlists = {
    runtime_state = {
      "src.ui.state.runtime",
    },
    landing_visual_hold = {
      "src.ui.visual_hold",
    },
    host_runtime = {
      "src.ui.host_bridge",
      "src.ui.ports.state",
      "src.app.ui_bootstrap",
      "src.app.event_bridge",
    },
  },
  state_field_allowlists = {
    presentation_runtime = {
      "src.app.gameplay_start",
      "src.turn.loop",
      "src.ui.render.action_anim",
       "src.ui.render.anim.overlay_runtime",
      "src.ui.render.building_effects",
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
      "src.turn.waits.timeout",
      "src.turn.waits.ui_gate",
      "src.ui.input.dispatch.item_phase_ask",
      "src.ui.input.dispatch.pre_confirm",
      "src.ui.input.dispatch.turn_action_port",
      "src.ui.input.dispatch.view_command",
    },
    resolved_gameplay_loop_ports = {
      "src.turn.loop",
      "src.turn.actions.action_dispatcher",
      "src.turn.waits.choice_timeout",
      "src.turn.waits.timeout",
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
      "src.ui.render.board.startup_render",
      "src.ui.render.board_feedback_service",
      "src.ui.render.board.visual_sync",
    },
  },
}

function presentation_ports.build()
  return {
    modal = modal_ports.build(),
    anim = anim_ports.build(),
    ui_sync = ui_sync_ports.build(common),
    debug = event_log_ports.build(common),
    clock = clock_ports.build(),
    state = state_ports.build(),
    view_command = view_command_ports.build(),
    actor_context = actor_context_ports.build(),
  }
end

function presentation_ports.describe_boundary_contract()
  return boundary_contract
end

return presentation_ports
