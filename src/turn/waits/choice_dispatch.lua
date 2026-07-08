local owner = require("src.turn.choice.owner")

local choice_dispatch = {}

function choice_dispatch.resolve_choice_owner_id(game, choice)
  return owner.resolve_role_id(game, choice)
end

function choice_dispatch.ensure_action_actor_role_id(game, choice, action)
  return owner.ensure_actor_role_id(game, choice, action)
end

function choice_dispatch.dispatch_choice_tick_action(game, state, choice, output_ports, opts, payload)
  local action = opts.build_action(game, state, choice, payload)
  if not action then
    return false
  end
  choice_dispatch.ensure_action_actor_role_id(game, choice, action)
  output_ports.set_pending_choice_elapsed(state, 0)
  opts.dispatch_action_with_close_choice(game, state, action)
  return true
end

return choice_dispatch

--[[ mutate4lua-manifest
version=2
projectHash=7206eb533c0930a2
scope.0.id=chunk:src/turn/waits/choice_dispatch.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=41
scope.0.semanticHash=a84390b1029f0998
scope.0.lastMutatedAt=2026-07-07T02:48:44Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=1
scope.0.lastMutationKilled=1
scope.1.id=function:choice_dispatch.resolve_choice_owner_id:5
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=16
scope.1.semanticHash=fbc070713c9c3164
scope.1.lastMutatedAt=2026-07-07T02:48:44Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=11
scope.1.lastMutationKilled=11
scope.2.id=function:choice_dispatch.ensure_action_actor_role_id:18
scope.2.kind=function
scope.2.startLine=18
scope.2.endLine=27
scope.2.semanticHash=33cae4f9cff0c9cc
scope.2.lastMutatedAt=2026-07-07T02:48:44Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=5
scope.2.lastMutationKilled=5
scope.3.id=function:choice_dispatch.dispatch_choice_tick_action:29
scope.3.kind=function
scope.3.startLine=29
scope.3.endLine=38
scope.3.semanticHash=f3605af0fa4de5b7
scope.3.lastMutatedAt=2026-07-07T02:48:44Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=7
scope.3.lastMutationKilled=7
]]
