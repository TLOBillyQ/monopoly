local runtime_state = require("src.ui.state.runtime")
local camera_sync = require("src.ui.ports.ui_sync.camera")
local choice_ui_state = require("src.ui.ports.ui_sync.choice_state")
local ui_gate_sync = require("src.ui.ports.ui_sync.gate")
local ui_model_sync = require("src.ui.ports.ui_sync.model")

local ui_sync_ports = {}

function ui_sync_ports.build(common)
  return {
    apply_input_lock = ui_model_sync.apply_input_lock,
    on_pending_choice = function(game, state, pending)
      runtime_state.set_ui_dirty(state, true)
      ui_model_sync.reopen_choice_modal_if_needed(game, state, pending)
    end,
    resolve_choice_ui_state = function(game, state, choice)
      return choice_ui_state.resolve_gate_state(game, state, choice)
    end,
    build_model = ui_model_sync.build_model,
    refresh_from_dirty = function(game, state, dirty)
      return ui_model_sync.refresh_from_dirty(game, state, dirty, common)
    end,
    follow_camera = camera_sync.follow_camera,
    sync_camera_position = camera_sync.sync_camera_position,
    pan_camera_to_position = camera_sync.pan_camera_to_position,
    release_target_pan = camera_sync.release_target_pan,
    get_ui_state = function(state)
      return ui_gate_sync.get_ui_state(state, common)
    end,
    resolve_ui_gate = function(state)
      return ui_gate_sync.resolve_ui_gate(state, common)
    end,
    is_input_blocked = function(state)
      return ui_gate_sync.is_input_blocked(state, common)
    end,
    is_popup_active = function(state)
      return ui_gate_sync.is_popup_active(state, common)
    end,
    is_choice_active = function(state)
      return ui_gate_sync.is_choice_active(state, common)
    end,
    get_popup_owner_index = function(state)
      return ui_gate_sync.get_popup_owner_index(state, common)
    end,
    set_input_blocked = function(state, blocked)
      return ui_gate_sync.set_input_blocked(state, blocked, common)
    end,
  }
end

ui_sync_ports._model = ui_model_sync
ui_sync_ports._camera = camera_sync
ui_sync_ports._choice_state = choice_ui_state
ui_sync_ports._gate = ui_gate_sync

return ui_sync_ports

--[[ mutate4lua-manifest
version=2
projectHash=c83cc2f1333ed79e
scope.0.id=chunk:src/ui/ports/ui_sync.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=60
scope.0.semanticHash=d59da0f10b4eb042
scope.0.lastMutatedAt=2026-05-29T14:23:08Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=5
scope.0.lastMutationKilled=5
scope.1.id=function:anonymous@12:12
scope.1.kind=function
scope.1.startLine=12
scope.1.endLine=15
scope.1.semanticHash=b7478a0c77863b15
scope.1.lastMutatedAt=2026-05-29T14:23:08Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=2
scope.1.lastMutationKilled=2
scope.2.id=function:anonymous@16:16
scope.2.kind=function
scope.2.startLine=16
scope.2.endLine=18
scope.2.semanticHash=bb80036c88b63f8c
scope.2.lastMutatedAt=2026-05-29T14:23:08Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=1
scope.2.lastMutationKilled=1
scope.3.id=function:anonymous@20:20
scope.3.kind=function
scope.3.startLine=20
scope.3.endLine=22
scope.3.semanticHash=58a58f1484d191d0
scope.3.lastMutatedAt=2026-05-29T14:23:08Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=1
scope.3.lastMutationKilled=1
scope.4.id=function:anonymous@27:27
scope.4.kind=function
scope.4.startLine=27
scope.4.endLine=29
scope.4.semanticHash=576b6803830e2fce
scope.4.lastMutatedAt=2026-05-29T14:23:08Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=1
scope.4.lastMutationKilled=1
scope.5.id=function:anonymous@30:30
scope.5.kind=function
scope.5.startLine=30
scope.5.endLine=32
scope.5.semanticHash=3374f58d05ed3f82
scope.5.lastMutatedAt=2026-05-29T14:23:08Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=1
scope.5.lastMutationKilled=1
scope.6.id=function:anonymous@33:33
scope.6.kind=function
scope.6.startLine=33
scope.6.endLine=35
scope.6.semanticHash=577a784aa65ddff1
scope.6.lastMutatedAt=2026-05-29T14:23:08Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=1
scope.6.lastMutationKilled=1
scope.7.id=function:anonymous@36:36
scope.7.kind=function
scope.7.startLine=36
scope.7.endLine=38
scope.7.semanticHash=e72125b46dcd88cf
scope.7.lastMutatedAt=2026-05-29T14:23:08Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=1
scope.7.lastMutationKilled=1
scope.8.id=function:anonymous@39:39
scope.8.kind=function
scope.8.startLine=39
scope.8.endLine=41
scope.8.semanticHash=d6b07cd21a3c87c6
scope.8.lastMutatedAt=2026-05-29T14:23:08Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=1
scope.8.lastMutationKilled=1
scope.9.id=function:anonymous@42:42
scope.9.kind=function
scope.9.startLine=42
scope.9.endLine=44
scope.9.semanticHash=9b770408e403ed99
scope.9.lastMutatedAt=2026-05-29T14:23:08Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=passed
scope.9.lastMutationSites=1
scope.9.lastMutationKilled=1
scope.10.id=function:anonymous@45:45
scope.10.kind=function
scope.10.startLine=45
scope.10.endLine=47
scope.10.semanticHash=2f944aea25995741
scope.10.lastMutatedAt=2026-05-29T14:23:08Z
scope.10.lastMutationLane=behavior
scope.10.lastMutationStatus=passed
scope.10.lastMutationSites=1
scope.10.lastMutationKilled=1
scope.11.id=function:anonymous@48:48
scope.11.kind=function
scope.11.startLine=48
scope.11.endLine=50
scope.11.semanticHash=b28aab4bdb65152b
scope.11.lastMutatedAt=2026-05-29T14:23:08Z
scope.11.lastMutationLane=behavior
scope.11.lastMutationStatus=passed
scope.11.lastMutationSites=1
scope.11.lastMutationKilled=1
scope.12.id=function:ui_sync_ports.build:9
scope.12.kind=function
scope.12.startLine=9
scope.12.endLine=52
scope.12.semanticHash=460402629360b02f
scope.12.lastMutatedAt=2026-05-29T14:23:08Z
scope.12.lastMutationLane=behavior
scope.12.lastMutationStatus=no_sites
scope.12.lastMutationSites=0
scope.12.lastMutationKilled=0
]]
