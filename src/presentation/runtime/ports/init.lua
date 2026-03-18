local common = require("src.presentation.runtime.ports.common")
local modal_ports = require("src.presentation.runtime.ports.modal")
local anim_ports = require("src.presentation.runtime.ports.anim")
local ui_sync_ports = require("src.presentation.runtime.ports.ui_sync")
local debug_ports = require("src.presentation.runtime.ports.debug")
local state_ports = require("src.presentation.runtime.ports.state")
local clock_ports = require("src.presentation.runtime.ports.clock")
local view_command_ports = require("src.presentation.runtime.ports.view_command")
local actor_context_ports = require("src.presentation.runtime.ports.actor_context")

local presentation_ports = {}
local boundary_contract = {
  state_seam_modules = {
    runtime_state = "src.ui.runtime.state",
    landing_visual_hold = "src.ui.runtime.landing_visual_hold",
    host_runtime = "src.ui.runtime.host_bridge",
  },
  import_allowlists = {
    runtime_state = {
      "src.ui.runtime.state",
    },
    landing_visual_hold = {
      "src.ui.runtime.landing_visual_hold",
    },
    host_runtime = {
      "src.ui.runtime.host_bridge",
      "src.presentation.runtime.ports.state",
      "src.presentation.runtime.ui_bootstrap",
      "src.presentation.runtime.runtime_event_bridge",
    },
  },
  state_field_allowlists = {
    presentation_runtime = {
      "src.presentation.runtime.gameplay_runtime_bootstrap",
      "src.turn.loop",
      "src.ui.render.action_anim",
      "src.ui.render.anim_overlay_runtime",
      "src.ui.render.building_effects",
      "src.ui.render.board.visual_sync",
      "src.ui.render.board_feedback_service",
      "src.ui.render.market",
      "src.ui.render.market_controls",
      "src.ui.render.status3d",
      "src.ui.render.anim_unit_overlay",
      "src.ui.wid.panel_presenter",
      "src.ui.wid.turn_effects",
      "src.presentation.runtime.ports.anim",
    },
    gameplay_loop_ports = {
      "src.presentation.runtime.gameplay_runtime_bootstrap",
      "src.turn.loop",
      "src.turn.actions.action_dispatcher",
      "src.turn.waits.choice_timeout",
      "src.turn.waits.timeout",
      "src.turn.waits.ui_gate",
      "src.ui.input.dispatch_item_phase_ask",
      "src.ui.input.dispatch_pre_confirm",
      "src.ui.input.dispatch_turn_action_port",
      "src.ui.input.dispatch_view_command",
    },
    resolved_gameplay_loop_ports = {
      "src.turn.loop",
      "src.turn.actions.action_dispatcher",
      "src.turn.waits.choice_timeout",
      "src.turn.waits.timeout",
    },
    game = {
      "src.presentation.runtime.runtime_event_bridge",
      "src.turn.loop",
      "src.turn.loop.loop_runtime",
      "src.turn.actions.validator",
      "src.ui.ctl.event_handlers",
      "src.ui.ctl.modal_controller",
      "src.ui.ctl.target_choice_effects",
      "src.ui.render.anim_overlay_compute",
      "src.ui.render.anim_tip_text",
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
    debug = debug_ports.build(common),
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
