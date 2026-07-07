local role_id_utils = require("src.foundation.identity")

local optional_action_completion = {}

local function _indexed_current_player(game)
  local turn = game.turn
  local index = turn and turn.current_player_index or nil
  if index == nil or game.players == nil then
    return nil
  end
  return game.players[index]
end

local function _current_player(game)
  if game == nil then
    return nil
  end
  if type(game.current_player) == "function" then
    return game:current_player()
  end
  return _indexed_current_player(game)
end

local function _current_player_id(game)
  local player = _current_player(game)
  return role_id_utils.normalize(player and player.id or nil)
end

local function _pending_choice(game, opts)
  if opts and opts.choice ~= nil then
    return opts.choice
  end
  return game and game.turn and game.turn.pending_choice or nil
end

local function _is_blocked(opts)
  local gate_state = opts and opts.gate_state or nil
  return gate_state and gate_state.input_blocked == true
end

function optional_action_completion.is_optional_action_choice(choice)
  local kind = choice and choice.kind or nil
  return kind == "item_phase_passive" or kind == "landing_optional_effect"
end

function optional_action_completion.is_cancelable_optional_action_choice(choice)
  return optional_action_completion.is_optional_action_choice(choice) and choice.allow_cancel ~= false
end

-- A pre_action item phase passive choice is opened at turn start, before the roll.
-- Unlike post_action/landing optional phases (which resolve through the 结束 button),
-- skipping it belongs on the 行动 button so 行动 precedes the roll even while a
-- pre-action card is still in the bag. Item target selection (passive_origin) keeps
-- its own 取消 affordance and is excluded here.
function optional_action_completion.is_pre_action_item_phase_choice(choice)
  if not optional_action_completion.is_cancelable_optional_action_choice(choice) then
    return false
  end
  if choice.kind ~= "item_phase_passive" then
    return false
  end
  local meta = choice.meta
  return type(meta) == "table" and meta.phase == "pre_action" and meta.passive_origin ~= true
end

local function _rejected(reason, choice)
  local result = { ok = false, reason = reason }
  if reason ~= "no_optional_action" and choice ~= nil then
    result.choice = choice
  end
  return result
end

local function _choice_rejection_reason(choice, opts)
  if not optional_action_completion.is_optional_action_choice(choice) then
    return "no_optional_action"
  end
  if choice.allow_cancel == false then
    return "not_cancelable_optional_action"
  end
  if _is_blocked(opts) then
    return "blocked"
  end
  return nil
end

local function _actor_rejection_reason(game, actor_id, opts)
  if opts.require_actor == false then
    return nil
  end
  local normalized_actor_id = role_id_utils.normalize(actor_id)
  if normalized_actor_id == nil then
    return "missing_actor"
  end
  local current_player_id = _current_player_id(game)
  if current_player_id ~= nil and not role_id_utils.equals(normalized_actor_id, current_player_id) then
    return "not_current_player"
  end
  return nil
end

function optional_action_completion.can_complete_optional_action_phase(game, actor_id, state, opts)
  opts = opts or {}
  local choice = _pending_choice(game, opts)
  local choice_reason = _choice_rejection_reason(choice, opts)
  if choice_reason ~= nil then
    return _rejected(choice_reason, choice)
  end
  local actor_reason = _actor_rejection_reason(game, actor_id, opts)
  if actor_reason ~= nil then
    return _rejected(actor_reason, choice)
  end
  return { ok = true, choice = choice }
end

local function _build_choice_cancel_action(choice, actor_id, input_source)
  return {
    type = "choice_cancel",
    choice_id = choice.id,
    actor_role_id = role_id_utils.normalize(actor_id),
    input_source = input_source,
  }
end

local function _dispatch_with_game(game, action)
  if game and type(game.dispatch_action) == "function" then
    game:dispatch_action(action)
    return { status = "applied" }
  end
  return { status = "rejected" }
end

local function _dispatch_choice_cancel(game, action, dispatch)
  if type(dispatch) == "function" then
    return dispatch(action)
  end
  return _dispatch_with_game(game, action)
end

local function _completion_result(status, action, choice)
  local reason = nil
  if status ~= "applied" then
    reason = "dispatch_rejected"
  end
  return {
    ok = status == "applied",
    status = status,
    reason = reason,
    action = action,
    choice = choice,
  }
end

function optional_action_completion.complete_optional_action_phase(game, actor_id, state, opts)
  opts = opts or {}
  local allowed = optional_action_completion.can_complete_optional_action_phase(game, actor_id, state, opts)
  if allowed.ok ~= true then
    return allowed
  end
  local action = _build_choice_cancel_action(allowed.choice, actor_id, opts.input_source)
  local dispatch_result = _dispatch_choice_cancel(game, action, opts.dispatch_choice_action)
  local status = dispatch_result and dispatch_result.status or nil
  return _completion_result(status, action, allowed.choice)
end

return optional_action_completion

--[[ mutate4lua-manifest
version=2
projectHash=fd0061b05bff33b4
scope.0.id=chunk:src/turn/optional_action_completion.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=151
scope.0.semanticHash=1801ade8afe825c1
scope.0.lastMutatedAt=2026-06-24T08:07:30Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=1
scope.0.lastMutationKilled=1
scope.1.id=function:_indexed_current_player:5
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=12
scope.1.semanticHash=07275ddf46bc61f7
scope.1.lastMutatedAt=2026-06-24T08:07:30Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=5
scope.1.lastMutationKilled=5
scope.2.id=function:_current_player:14
scope.2.kind=function
scope.2.startLine=14
scope.2.endLine=22
scope.2.semanticHash=8fd75a938f56fe42
scope.2.lastMutatedAt=2026-06-24T08:07:30Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=6
scope.2.lastMutationKilled=6
scope.3.id=function:_current_player_id:24
scope.3.kind=function
scope.3.startLine=24
scope.3.endLine=27
scope.3.semanticHash=2af5fe7dfec94bdd
scope.3.lastMutatedAt=2026-06-24T08:07:30Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=2
scope.3.lastMutationKilled=2
scope.4.id=function:_pending_choice:29
scope.4.kind=function
scope.4.startLine=29
scope.4.endLine=34
scope.4.semanticHash=e8ad574ff8859578
scope.4.lastMutatedAt=2026-06-24T08:07:30Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=5
scope.4.lastMutationKilled=5
scope.5.id=function:_is_blocked:36
scope.5.kind=function
scope.5.startLine=36
scope.5.endLine=39
scope.5.semanticHash=c78fb122b2f024f0
scope.5.lastMutatedAt=2026-06-24T08:07:30Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=5
scope.5.lastMutationKilled=5
scope.6.id=function:optional_action_completion.is_optional_action_choice:41
scope.6.kind=function
scope.6.startLine=41
scope.6.endLine=44
scope.6.semanticHash=4ca971bfcbc44439
scope.6.lastMutatedAt=2026-06-24T08:07:30Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=7
scope.6.lastMutationKilled=7
scope.7.id=function:optional_action_completion.is_cancelable_optional_action_choice:46
scope.7.kind=function
scope.7.startLine=46
scope.7.endLine=48
scope.7.semanticHash=8dff6c21821f60db
scope.7.lastMutatedAt=2026-06-24T08:07:30Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=4
scope.7.lastMutationKilled=4
scope.8.id=function:_rejected:50
scope.8.kind=function
scope.8.startLine=50
scope.8.endLine=56
scope.8.semanticHash=13b8d51bf1f35c07
scope.8.lastMutatedAt=2026-06-24T08:07:30Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=5
scope.8.lastMutationKilled=5
scope.9.id=function:_choice_rejection_reason:58
scope.9.kind=function
scope.9.startLine=58
scope.9.endLine=69
scope.9.semanticHash=c5c1b2e3cd50d08c
scope.9.lastMutatedAt=2026-06-24T08:07:30Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=passed
scope.9.lastMutationSites=8
scope.9.lastMutationKilled=8
scope.10.id=function:_actor_rejection_reason:71
scope.10.kind=function
scope.10.startLine=71
scope.10.endLine=84
scope.10.semanticHash=e01bd054960bd736
scope.10.lastMutatedAt=2026-06-24T08:07:30Z
scope.10.lastMutationLane=behavior
scope.10.lastMutationStatus=passed
scope.10.lastMutationSites=11
scope.10.lastMutationKilled=11
scope.11.id=function:optional_action_completion.can_complete_optional_action_phase:86
scope.11.kind=function
scope.11.startLine=86
scope.11.endLine=98
scope.11.semanticHash=31de2114f65ad0e9
scope.11.lastMutatedAt=2026-06-24T08:07:30Z
scope.11.lastMutationLane=behavior
scope.11.lastMutationStatus=passed
scope.11.lastMutationSites=9
scope.11.lastMutationKilled=9
scope.12.id=function:_build_choice_cancel_action:100
scope.12.kind=function
scope.12.startLine=100
scope.12.endLine=107
scope.12.semanticHash=bc28b80d43bc85ee
scope.12.lastMutatedAt=2026-06-24T08:07:30Z
scope.12.lastMutationLane=behavior
scope.12.lastMutationStatus=passed
scope.12.lastMutationSites=2
scope.12.lastMutationKilled=2
scope.13.id=function:_dispatch_with_game:109
scope.13.kind=function
scope.13.startLine=109
scope.13.endLine=115
scope.13.semanticHash=6287391231a4e9e7
scope.13.lastMutatedAt=2026-06-24T08:07:30Z
scope.13.lastMutationLane=behavior
scope.13.lastMutationStatus=passed
scope.13.lastMutationSites=7
scope.13.lastMutationKilled=7
scope.14.id=function:_dispatch_choice_cancel:117
scope.14.kind=function
scope.14.startLine=117
scope.14.endLine=122
scope.14.semanticHash=a9a5b6ff512ffa14
scope.14.lastMutatedAt=2026-06-24T08:07:30Z
scope.14.lastMutationLane=behavior
scope.14.lastMutationStatus=passed
scope.14.lastMutationSites=5
scope.14.lastMutationKilled=5
scope.15.id=function:_completion_result:124
scope.15.kind=function
scope.15.startLine=124
scope.15.endLine=136
scope.15.semanticHash=3abe42c1ef435825
scope.15.lastMutatedAt=2026-06-24T08:07:30Z
scope.15.lastMutationLane=behavior
scope.15.lastMutationStatus=passed
scope.15.lastMutationSites=5
scope.15.lastMutationKilled=5
scope.16.id=function:optional_action_completion.complete_optional_action_phase:138
scope.16.kind=function
scope.16.startLine=138
scope.16.endLine=148
scope.16.semanticHash=9d1f34e0864765af
scope.16.lastMutatedAt=2026-06-24T08:07:30Z
scope.16.lastMutationLane=behavior
scope.16.lastMutationStatus=passed
scope.16.lastMutationSites=9
scope.16.lastMutationKilled=9
]]
