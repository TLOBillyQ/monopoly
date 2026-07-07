local runtime_state = require("src.state.runtime")

local choice_ui_sync = {}

function choice_ui_sync.sync_pending_choice_ui(game, state, opts, output_ports)
  local pending = game.turn.pending_choice
  local active_choice = output_ports.get_pending_choice(state)
  if pending and (not active_choice or active_choice.id ~= pending.id) then
    output_ports.sync_pending_choice(state, pending)
    opts.on_pending_choice(state, pending)
  elseif not pending then
    output_ports.clear_pending_choice(state)
  end
  return pending, output_ports.get_pending_choice(state)
end

function choice_ui_sync.resolve_missing_ui_warning(state, game, opts, pending, active_choice, ui_choice_active)
  local active = pending ~= nil or active_choice ~= nil
  local resolved_ui_gate = nil
  if active and active_choice and type(opts.resolve_choice_ui_state) == "function" then
    resolved_ui_gate = opts.resolve_choice_ui_state(game, state, active_choice)
  end
  local should_warn_missing_ui = active and active_choice and not ui_choice_active
  if type(resolved_ui_gate) == "table" then
    should_warn_missing_ui = resolved_ui_gate.should_warn == true
  end
  return active, should_warn_missing_ui
end

function choice_ui_sync.maybe_warn_missing_ui(state, active_choice, should_warn_missing_ui)
  if not should_warn_missing_ui then
    return
  end
  runtime_state.log_once(
    state,
    "warn",
    "choice_runtime_without_ui_" .. tostring(active_choice.id),
    "[Eggy]",
    "runtime pending choice active without ui.choice_active",
    "choice_id=" .. tostring(active_choice.id),
    "kind=" .. tostring(active_choice.kind),
    "owner_role_id=" .. tostring(active_choice.owner_role_id),
    "route_key=" .. tostring(active_choice.route_key)
  )
end

return choice_ui_sync

--[[ mutate4lua-manifest
version=2
projectHash=dca5bcee6250d147
scope.0.id=chunk:src/turn/waits/choice_ui_sync.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=48
scope.0.semanticHash=140f0566130beec7
scope.0.lastMutatedAt=2026-07-07T02:49:04Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=1
scope.0.lastMutationKilled=1
scope.1.id=function:choice_ui_sync.sync_pending_choice_ui:5
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=15
scope.1.semanticHash=1c303697b6457552
scope.1.lastMutatedAt=2026-07-07T02:49:04Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=10
scope.1.lastMutationKilled=10
scope.2.id=function:choice_ui_sync.resolve_missing_ui_warning:17
scope.2.kind=function
scope.2.startLine=17
scope.2.endLine=28
scope.2.semanticHash=2283b0e3359c0b30
scope.2.lastMutatedAt=2026-07-07T02:49:04Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=17
scope.2.lastMutationKilled=17
scope.3.id=function:choice_ui_sync.maybe_warn_missing_ui:30
scope.3.kind=function
scope.3.startLine=30
scope.3.endLine=45
scope.3.semanticHash=6f6d35af8f88b29c
scope.3.lastMutatedAt=2026-07-07T02:49:04Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=2
scope.3.lastMutationKilled=2
]]
