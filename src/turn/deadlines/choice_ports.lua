local resolve_port = require("src.turn.loop.resolve_port")
local owner = require("src.turn.choice.owner")

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

function choice_ports.ensure_actor_role_id(game, choice, action)
  owner.ensure_actor_role_id(game, choice, action)
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
projectHash=da79175f27c2e507
scope.0.id=chunk:src/turn/deadlines/choice_ports.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=70
scope.0.semanticHash=5684a4f7c8de39da
scope.1.id=function:choice_ports.resolve_modal_ports:6
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=12
scope.1.semanticHash=510a2f464a0ed770
scope.2.id=function:choice_ports.resolve_output_ports:14
scope.2.kind=function
scope.2.startLine=14
scope.2.endLine=16
scope.2.semanticHash=08eb94ac9f2a6741
scope.3.id=function:choice_ports.is_action_dispatchable:18
scope.3.kind=function
scope.3.startLine=18
scope.3.endLine=25
scope.3.semanticHash=7175582efe598c4e
scope.4.id=function:choice_ports.ensure_actor_role_id:27
scope.4.kind=function
scope.4.startLine=27
scope.4.endLine=29
scope.4.semanticHash=b80727044a55c035
scope.5.id=function:_dispatch_to_game:31
scope.5.kind=function
scope.5.startLine=31
scope.5.endLine=35
scope.5.semanticHash=b4f9ad763b53e113
scope.6.id=function:_clear_game_pending_choice:37
scope.6.kind=function
scope.6.startLine=37
scope.6.endLine=44
scope.6.semanticHash=200338944bc4867a
scope.7.id=function:_close_modal_choice:46
scope.7.kind=function
scope.7.startLine=46
scope.7.endLine=51
scope.7.semanticHash=dfb34b586e4193f1
scope.8.id=function:_clear_output_choice:53
scope.8.kind=function
scope.8.startLine=53
scope.8.endLine=60
scope.8.semanticHash=655da856cfd7ca59
scope.9.id=function:choice_ports.dispatch_via_close_choice:62
scope.9.kind=function
scope.9.startLine=62
scope.9.endLine=67
scope.9.semanticHash=71848c07e192d8da
]]
