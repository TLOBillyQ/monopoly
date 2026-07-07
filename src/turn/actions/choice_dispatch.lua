local force_resolve = require("src.turn.deadlines")
local optional_action_completion = require("src.turn.optional_action_completion")
local ctx_mod = require("src.turn.actions.context")

local choice_dispatch = {}

local function _clear_choice_if_closed(game, state, opts, choice, turn_dispatch_ref)
  local pending = game and game.turn and game.turn.pending_choice or nil
  if choice and (not pending or not pending.id or pending.id ~= choice.id) then
    turn_dispatch_ref.clear_choice(state, opts)
  end
end

function choice_dispatch.handle_choice_action(game, state, action, opts, ctx, validator, dispatch_action, turn_dispatch_ref)
  local choice = ctx_mod.resolve_pending_choice(game, state, ctx)
  if not validator.validate_choice_action(game, action, choice) then
    return { status = "rejected" }
  end
  if game then
    assert(game.dispatch_action ~= nil, "missing game.dispatch_action")
    game:dispatch_action(action)
  end
  _clear_choice_if_closed(game, state, opts, choice, turn_dispatch_ref)
  return { status = "applied" }
end

local function _apply_market_navigation(game, state, action, ctx, choice, validator, market_service)
  if not choice or choice.kind ~= "market_buy" then
    return false
  end
  if not validator.validate_choice_action(game, action, choice) then
    return false
  end
  if not market_service.choice.apply_navigation(game, choice, action) then
    return false
  end
  ctx.output_ports.sync_pending_choice(state, choice)
  return true
end

function choice_dispatch.handle_market_navigation(game, state, action, ctx, validator, market_service)
  local choice = ctx_mod.resolve_pending_choice(game, state, ctx)
  if not _apply_market_navigation(game, state, action, ctx, choice, validator, market_service) then
    return { status = "rejected" }
  end
  return { status = "applied" }
end

function choice_dispatch.handle_force_skip(game, state, action, ctx)
  local choice = ctx_mod.resolve_pending_choice(game, state, ctx)
  force_resolve.force_skip(game, state, choice, action.reason or "dispatch")
  return { status = "applied" }
end

local function _optional_completion_status(result)
  if result.ok == true then
    return { status = "applied" }
  end
  if result.reason == "blocked" then
    return { status = "blocked", reason = result.reason }
  end
  return { status = "rejected", reason = result.reason }
end

function choice_dispatch.handle_optional_action_completion(game, state, action, opts, ctx, validator, dispatch_action)
  local gate_state = validator.resolve_gate_state(state, ctx.ui_sync_ports)
  local result = optional_action_completion.complete_optional_action_phase(game, action.actor_role_id, state, {
    gate_state = gate_state,
    input_source = action.input_source,
    dispatch_choice_action = function(choice_action)
      return dispatch_action(game, state, choice_action, opts, ctx)
    end,
  })
  return _optional_completion_status(result)
end

return choice_dispatch

--[[ mutate4lua-manifest
version=2
projectHash=d8f38d60f38a3fd4
scope.0.id=chunk:src/turn/actions/choice_dispatch.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=78
scope.0.semanticHash=764afd9814fea08d
scope.0.lastMutatedAt=2026-07-06T17:31:46Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=3
scope.0.lastMutationKilled=3
scope.1.id=function:_clear_choice_if_closed:7
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=12
scope.1.semanticHash=0baff23cbdbb498d
scope.1.lastMutatedAt=2026-07-06T17:31:46Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=10
scope.1.lastMutationKilled=10
scope.2.id=function:choice_dispatch.handle_choice_action:14
scope.2.kind=function
scope.2.startLine=14
scope.2.endLine=25
scope.2.semanticHash=374e7b0c4afe8d27
scope.2.lastMutatedAt=2026-07-06T17:31:46Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=8
scope.2.lastMutationKilled=8
scope.3.id=function:_apply_market_navigation:27
scope.3.kind=function
scope.3.startLine=27
scope.3.endLine=39
scope.3.semanticHash=8a583c3e0364b595
scope.3.lastMutatedAt=2026-07-06T17:31:46Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=13
scope.3.lastMutationKilled=13
scope.4.id=function:choice_dispatch.handle_market_navigation:41
scope.4.kind=function
scope.4.startLine=41
scope.4.endLine=47
scope.4.semanticHash=1d95277d2652a3e9
scope.4.lastMutatedAt=2026-07-06T17:31:46Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=5
scope.4.lastMutationKilled=5
scope.5.id=function:choice_dispatch.handle_force_skip:49
scope.5.kind=function
scope.5.startLine=49
scope.5.endLine=53
scope.5.semanticHash=58eb10d261bbc2f2
scope.5.lastMutatedAt=2026-07-06T17:31:46Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=3
scope.5.lastMutationKilled=3
scope.6.id=function:_optional_completion_status:55
scope.6.kind=function
scope.6.startLine=55
scope.6.endLine=63
scope.6.semanticHash=5db81f4b4bfdd66f
scope.6.lastMutatedAt=2026-07-06T17:31:46Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=7
scope.6.lastMutationKilled=7
scope.7.id=function:anonymous@70:70
scope.7.kind=function
scope.7.startLine=70
scope.7.endLine=72
scope.7.semanticHash=57d777edada70b89
scope.7.lastMutatedAt=2026-07-06T17:29:15Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=no_sites
scope.7.lastMutationSites=0
scope.7.lastMutationKilled=0
scope.8.id=function:choice_dispatch.handle_optional_action_completion:65
scope.8.kind=function
scope.8.startLine=65
scope.8.endLine=75
scope.8.semanticHash=b29028d270c4173b
scope.8.lastMutatedAt=2026-07-06T17:31:46Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=3
scope.8.lastMutationKilled=3
]]
