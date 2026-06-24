local resolve_port = require("src.turn.loop.resolve_port")

local choice_ports = {}

function choice_ports.resolve_modal_ports(state)
  local resolved = state and (state._resolved_gameplay_loop_ports or state.gameplay_loop_ports) or nil
  if type(resolved) ~= "table" then
    return nil
  end
  return resolved.modal
end

function choice_ports.resolve_output_ports(state)
  return resolve_port.resolve(state, "output", require("src.turn.output.state_adapter"))
end

function choice_ports.is_action_dispatchable(action)
  if type(action) ~= "table" then
    return false
  end
  return action.type == "choice_select"
    or action.type == "choice_cancel"
    or action.type == "complete_optional_action_phase"
end

local function _resolve_owner_actor_id(choice)
  return choice and choice.owner_role_id or nil
end

local function _resolve_current_player_actor_id(game)
  local p = game and game.turn and game.turn.current_player_index and game.players and game.players[game.turn.current_player_index]
  return p and p.id or nil
end

function choice_ports.ensure_actor_role_id(game, choice, action)
  if action.actor_role_id ~= nil then return end
  action.actor_role_id = _resolve_owner_actor_id(choice) or _resolve_current_player_actor_id(game)
end

local function _dispatch_to_game(game, action)
  if game and type(game.dispatch_action) == "function" then
    pcall(game.dispatch_action, game, action)
  end
end

local function _clear_game_pending_choice(game, action)
  if game and game.turn then
    local pending = game.turn.pending_choice
    if not pending or pending.id ~= action.choice_id then
      game.turn.pending_choice = nil
    end
  end
end

local function _close_modal_choice(state)
  local modal_ports = choice_ports.resolve_modal_ports(state)
  if modal_ports and type(modal_ports.close_choice_modal) == "function" then
    pcall(modal_ports.close_choice_modal, state)
  end
end

local function _clear_output_choice(state)
  if type(state) == "table" then
    local output_ports = choice_ports.resolve_output_ports(state)
    if output_ports and type(output_ports.clear_pending_choice) == "function" then
      pcall(output_ports.clear_pending_choice, state)
    end
  end
end

function choice_ports.dispatch_via_close_choice(game, state, action)
  _dispatch_to_game(game, action)
  _clear_game_pending_choice(game, action)
  _close_modal_choice(state)
  _clear_output_choice(state)
end

return choice_ports

--[[ mutate4lua-manifest
version=2
projectHash=bd0ef1152b274c5f
scope.0.id=chunk:src/turn/deadlines/choice_ports.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=79
scope.0.semanticHash=730e4015ac196f35
scope.1.id=function:choice_ports.resolve_modal_ports:5
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=11
scope.1.semanticHash=510a2f464a0ed770
scope.2.id=function:choice_ports.resolve_output_ports:13
scope.2.kind=function
scope.2.startLine=13
scope.2.endLine=15
scope.2.semanticHash=08eb94ac9f2a6741
scope.3.id=function:choice_ports.is_action_dispatchable:17
scope.3.kind=function
scope.3.startLine=17
scope.3.endLine=24
scope.3.semanticHash=7175582efe598c4e
scope.4.id=function:_resolve_owner_actor_id:26
scope.4.kind=function
scope.4.startLine=26
scope.4.endLine=28
scope.4.semanticHash=a36f90c40f1f7fda
scope.5.id=function:_resolve_current_player_actor_id:30
scope.5.kind=function
scope.5.startLine=30
scope.5.endLine=33
scope.5.semanticHash=75813f76748301e3
scope.6.id=function:choice_ports.ensure_actor_role_id:35
scope.6.kind=function
scope.6.startLine=35
scope.6.endLine=38
scope.6.semanticHash=53d7cb37beb8b0bb
scope.7.id=function:_dispatch_to_game:40
scope.7.kind=function
scope.7.startLine=40
scope.7.endLine=44
scope.7.semanticHash=b4f9ad763b53e113
scope.8.id=function:_clear_game_pending_choice:46
scope.8.kind=function
scope.8.startLine=46
scope.8.endLine=53
scope.8.semanticHash=200338944bc4867a
scope.9.id=function:_close_modal_choice:55
scope.9.kind=function
scope.9.startLine=55
scope.9.endLine=60
scope.9.semanticHash=dfb34b586e4193f1
scope.10.id=function:_clear_output_choice:62
scope.10.kind=function
scope.10.startLine=62
scope.10.endLine=69
scope.10.semanticHash=655da856cfd7ca59
scope.11.id=function:choice_ports.dispatch_via_close_choice:71
scope.11.kind=function
scope.11.startLine=71
scope.11.endLine=76
scope.11.semanticHash=71848c07e192d8da
]]
