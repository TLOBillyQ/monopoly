local deadlines = require("src.turn.deadlines")
local choice_scope = require("src.turn.deadlines.choice_scope")

local choice_tracking = {}

function choice_tracking.sync_deadline_for_choice(state, active_choice, timeout)
  local scope = choice_scope.for_choice(active_choice)
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
projectHash=586b17a2b381629d
scope.0.id=chunk:src/turn/waits/choice_tracking.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=41
scope.0.semanticHash=08ff16bbcb987e54
scope.1.id=function:choice_tracking.sync_deadline_for_choice:6
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=18
scope.1.semanticHash=fbc30a9ea5d8556c
scope.2.id=function:choice_tracking.cancel_deadline_when_no_choice:20
scope.2.kind=function
scope.2.startLine=20
scope.2.endLine=23
scope.2.semanticHash=e5670995692723d9
scope.3.id=function:choice_tracking.reset_choice_tracking:25
scope.3.kind=function
scope.3.startLine=25
scope.3.endLine=29
scope.3.semanticHash=25e886a7c39536a7
scope.4.id=function:choice_tracking.sync_elapsed_choice_id:31
scope.4.kind=function
scope.4.startLine=31
scope.4.endLine=38
scope.4.semanticHash=1136708b430ebf54
]]
