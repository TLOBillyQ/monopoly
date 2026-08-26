-- #329:端口组解析 accessor 归 turn.output(中立归属),deadlines 不再反向
-- require loop。
local resolve_port = require("src.turn.output.resolve_port")
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
version=4
projectHash=fc991ffa314ef1bf
scope.0.id=chunk:src/turn/deadlines/choice_ports.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=72
scope.0.semanticHash=24da0fd20d429985
scope.1.id=function:choice_ports.resolve_modal_ports
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=14
scope.1.semanticHash=be98e4513051dc44
scope.2.id=function:choice_ports.resolve_output_ports
scope.2.kind=function
scope.2.startLine=16
scope.2.endLine=18
scope.2.semanticHash=b1e501e556f06c3b
scope.3.id=function:choice_ports.is_action_dispatchable
scope.3.kind=function
scope.3.startLine=20
scope.3.endLine=27
scope.3.semanticHash=8f4a13065b29a66b
scope.4.id=function:choice_ports.ensure_actor_role_id
scope.4.kind=function
scope.4.startLine=29
scope.4.endLine=31
scope.4.semanticHash=2fc68b1d0ce722c8
scope.5.id=function:_dispatch_to_game
scope.5.kind=function
scope.5.startLine=33
scope.5.endLine=37
scope.5.semanticHash=8ed4b55feb1a2071
scope.6.id=function:_clear_game_pending_choice
scope.6.kind=function
scope.6.startLine=39
scope.6.endLine=46
scope.6.semanticHash=980886d2e0f8dffc
scope.7.id=function:_close_modal_choice
scope.7.kind=function
scope.7.startLine=48
scope.7.endLine=53
scope.7.semanticHash=286af9d2407616c9
scope.8.id=function:_clear_output_choice
scope.8.kind=function
scope.8.startLine=55
scope.8.endLine=62
scope.8.semanticHash=e98b38a7b851aee8
scope.9.id=function:choice_ports.dispatch_via_close_choice
scope.9.kind=function
scope.9.startLine=64
scope.9.endLine=69
scope.9.semanticHash=3121ef1015156d3f
]]
