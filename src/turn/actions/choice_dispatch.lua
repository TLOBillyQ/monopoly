local force_resolve = require("src.turn.deadlines")
local optional_action_completion = require("src.turn.optional_action_completion")

local choice_dispatch = {}

local function _resolve_pending_choice(game, state, ctx)
  local turn = game and game.turn or nil
  local turn_choice = turn and turn.pending_choice or nil
  if turn_choice ~= nil then
    return turn_choice
  end
  return ctx.output_ports.get_pending_choice(state)
end

local function _clear_choice_if_closed(game, state, opts, choice, turn_dispatch_ref)
  local pending = game and game.turn and game.turn.pending_choice or nil
  if choice and (not pending or not pending.id or pending.id ~= choice.id) then
    turn_dispatch_ref.clear_choice(state, opts)
  end
end

function choice_dispatch.handle_choice_action(game, state, action, opts, ctx, validator, dispatch_action, turn_dispatch_ref)
  local choice = _resolve_pending_choice(game, state, ctx)
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
  local choice = _resolve_pending_choice(game, state, ctx)
  if not _apply_market_navigation(game, state, action, ctx, choice, validator, market_service) then
    return { status = "rejected" }
  end
  return { status = "applied" }
end

function choice_dispatch.handle_force_skip(game, state, action, ctx)
  local choice = _resolve_pending_choice(game, state, ctx)
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
projectHash=b3d0f73783973006
scope.0.id=chunk:src/turn/actions/choice_dispatch.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=86
scope.0.semanticHash=91803166e685be3b
scope.1.id=function:_resolve_pending_choice:6
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=13
scope.1.semanticHash=a3b657a5b4d5d4f2
scope.2.id=function:_clear_choice_if_closed:15
scope.2.kind=function
scope.2.startLine=15
scope.2.endLine=20
scope.2.semanticHash=0baff23cbdbb498d
scope.3.id=function:choice_dispatch.handle_choice_action:22
scope.3.kind=function
scope.3.startLine=22
scope.3.endLine=33
scope.3.semanticHash=89f8056e40db3a14
scope.4.id=function:_apply_market_navigation:35
scope.4.kind=function
scope.4.startLine=35
scope.4.endLine=47
scope.4.semanticHash=8a583c3e0364b595
scope.5.id=function:choice_dispatch.handle_market_navigation:49
scope.5.kind=function
scope.5.startLine=49
scope.5.endLine=55
scope.5.semanticHash=5e53b39cb93038e8
scope.6.id=function:choice_dispatch.handle_force_skip:57
scope.6.kind=function
scope.6.startLine=57
scope.6.endLine=61
scope.6.semanticHash=d96b55cb9604f4dd
scope.7.id=function:_optional_completion_status:63
scope.7.kind=function
scope.7.startLine=63
scope.7.endLine=71
scope.7.semanticHash=5db81f4b4bfdd66f
scope.8.id=function:anonymous@78:78
scope.8.kind=function
scope.8.startLine=78
scope.8.endLine=80
scope.8.semanticHash=57d777edada70b89
scope.9.id=function:choice_dispatch.handle_optional_action_completion:73
scope.9.kind=function
scope.9.startLine=73
scope.9.endLine=83
scope.9.semanticHash=b29028d270c4173b
]]
