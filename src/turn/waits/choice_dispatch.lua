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
version=4
projectHash=91de1f315552b706
scope.0.id=chunk:src/turn/waits/choice_dispatch.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=25
scope.0.semanticHash=e716a683d6d28d23
scope.1.id=function:choice_dispatch.resolve_choice_owner_id
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=7
scope.1.semanticHash=aba9250a8c6b104f
scope.2.id=function:choice_dispatch.ensure_action_actor_role_id
scope.2.kind=function
scope.2.startLine=9
scope.2.endLine=11
scope.2.semanticHash=d590c542c8c308c5
scope.3.id=function:choice_dispatch.dispatch_choice_tick_action
scope.3.kind=function
scope.3.startLine=13
scope.3.endLine=22
scope.3.semanticHash=0c0576d92e7f1610
]]
