local deadlines = require("src.turn.deadlines")

local choice_tracking = {}

local function _scope_for_choice(active_choice)
  if active_choice and active_choice.kind == "market_buy" then
    return "market_buy"
  end
  return "choice"
end

function choice_tracking.sync_deadline_for_choice(state, active_choice, timeout)
  local scope = _scope_for_choice(active_choice)
  local other_scope = scope == "choice" and "market_buy" or "choice"
  if deadlines.is_active(state, other_scope) then
    deadlines.cancel(state, other_scope)
  end
  if not deadlines.is_active(state, scope) then
    deadlines.start(state, scope, {
      timeout_seconds = timeout,
      priority = 100,
    })
  end
end

function choice_tracking.cancel_deadline_when_no_choice(state)
  deadlines.cancel(state, "choice")
  deadlines.cancel(state, "market_buy")
end

function choice_tracking.reset_choice_tracking(state, output_ports)
  output_ports.set_pending_choice_elapsed(state, 0)
  output_ports.set_pending_choice_id(state, nil)
  choice_tracking.cancel_deadline_when_no_choice(state)
end

function choice_tracking.sync_elapsed_choice_id(state, output_ports, active_choice)
  if output_ports.get_pending_choice_id(state) ~= active_choice.id then
    output_ports.set_pending_choice_elapsed(state, 0)
    output_ports.set_pending_choice_id(state, active_choice.id)
    deadlines.cancel(state, "choice")
    deadlines.cancel(state, "market_buy")
  end
end

return choice_tracking

--[[ mutate4lua-manifest
version=2
projectHash=677a14af5e78a91b
scope.0.id=chunk:src/turn/waits/choice_tracking.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=47
scope.0.semanticHash=0661d7712a7c79a9
scope.0.lastMutatedAt=2026-07-07T02:48:54Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=1
scope.0.lastMutationKilled=1
scope.1.id=function:_scope_for_choice:5
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=10
scope.1.semanticHash=e6f4b028e48643eb
scope.1.lastMutatedAt=2026-07-07T02:48:54Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=5
scope.1.lastMutationKilled=5
scope.2.id=function:choice_tracking.sync_deadline_for_choice:12
scope.2.kind=function
scope.2.startLine=12
scope.2.endLine=24
scope.2.semanticHash=57bb9e45aa225e82
scope.2.lastMutatedAt=2026-07-07T02:48:54Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=12
scope.2.lastMutationKilled=12
scope.3.id=function:choice_tracking.cancel_deadline_when_no_choice:26
scope.3.kind=function
scope.3.startLine=26
scope.3.endLine=29
scope.3.semanticHash=e5670995692723d9
scope.3.lastMutatedAt=2026-07-07T02:48:54Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=2
scope.3.lastMutationKilled=2
scope.4.id=function:choice_tracking.reset_choice_tracking:31
scope.4.kind=function
scope.4.startLine=31
scope.4.endLine=35
scope.4.semanticHash=25e886a7c39536a7
scope.4.lastMutatedAt=2026-07-07T02:48:54Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=3
scope.4.lastMutationKilled=3
scope.5.id=function:choice_tracking.sync_elapsed_choice_id:37
scope.5.kind=function
scope.5.startLine=37
scope.5.endLine=44
scope.5.semanticHash=1136708b430ebf54
scope.5.lastMutatedAt=2026-07-07T02:48:54Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=6
scope.5.lastMutationKilled=6
]]
