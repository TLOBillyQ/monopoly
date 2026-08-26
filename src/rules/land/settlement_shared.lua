local effect_runner = require("src.rules.effects.runner")

local shared = {}

function shared.reject(reason)
  return {
    ok = false,
    status = "rejected",
    reason = reason,
  }
end

function shared.settled()
  return {
    ok = true,
    status = "settled",
    settled = true,
  }
end

function shared.with_ok(result)
  if type(result) == "table" and result.ok == nil then
    result.ok = true
  end
  return result
end

function shared.resolve_actor(game, actor_id)
  if not (game and type(game.find_player_by_id) == "function") then
    return nil
  end
  return game:find_player_by_id(actor_id)
end

local function _resolve_board(game)
  return game and game.board or nil
end

local function _call_board_tile_method(board, method_name, value)
  local method = board and board[method_name] or nil
  if value == nil or type(method) ~= "function" then
    return nil
  end
  return method(board, value)
end

local function _context_tile(context)
  return context and context.tile or nil
end

local function _resolve_board_tile(board, actor, context)
  if context.tile_id ~= nil then
    return _call_board_tile_method(board, "get_tile_by_id", context.tile_id)
  end
  local index = context.board_index or (actor and actor.position)
  return _call_board_tile_method(board, "get_tile", index)
end

function shared.resolve_tile(game, actor, context)
  context = context or {}
  local tile = _context_tile(context)
  if tile ~= nil then
    return tile
  end
  local board = _resolve_board(game)
  if board == nil then
    return nil
  end
  return _resolve_board_tile(board, actor, context)
end

function shared.build_game_ctx(game, move_result, phase_default)
  return effect_runner.build_game_ctx(game, move_result, {
    phase_default = phase_default or "landing",
    on_landing = true,
  })
end

function shared.option_id_from_action(action)
  return action and action.option_id or nil
end

function shared.choice_meta(choice)
  local meta = choice and choice.meta or nil
  if type(meta) ~= "table" then
    return nil, shared.reject("missing_landing_choice_meta")
  end
  return meta
end

function shared.resolve_choice_player(game, meta)
  local player = shared.resolve_actor(game, meta.player_id)
  if player == nil then
    return nil, shared.reject("missing_actor")
  end
  return player
end

function shared.resolve_choice_tile(game, player, meta)
  local tile = shared.resolve_tile(game, player, { tile_id = meta.tile_id })
  if tile == nil then
    return nil, shared.reject("missing_tile")
  end
  return tile
end

return shared

--[[ mutate4lua-manifest
version=4
projectHash=09dd924a506a331f
scope.0.id=chunk:src/rules/land/settlement_shared.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=108
scope.0.semanticHash=c304c24ec24924cf
scope.1.id=function:shared.reject
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=11
scope.1.semanticHash=f58cd2476f4cc2f6
scope.2.id=function:shared.settled
scope.2.kind=function
scope.2.startLine=13
scope.2.endLine=19
scope.2.semanticHash=36cad352785de4cf
scope.3.id=function:shared.with_ok
scope.3.kind=function
scope.3.startLine=21
scope.3.endLine=26
scope.3.semanticHash=1926112522915ead
scope.4.id=function:shared.resolve_actor
scope.4.kind=function
scope.4.startLine=28
scope.4.endLine=33
scope.4.semanticHash=0dafd48e169cdbeb
scope.5.id=function:_resolve_board
scope.5.kind=function
scope.5.startLine=35
scope.5.endLine=37
scope.5.semanticHash=616a2ca60599c94f
scope.6.id=function:_call_board_tile_method
scope.6.kind=function
scope.6.startLine=39
scope.6.endLine=45
scope.6.semanticHash=535e8a73b5b1d448
scope.7.id=function:_context_tile
scope.7.kind=function
scope.7.startLine=47
scope.7.endLine=49
scope.7.semanticHash=616a2ca60599c94f
scope.8.id=function:_resolve_board_tile
scope.8.kind=function
scope.8.startLine=51
scope.8.endLine=57
scope.8.semanticHash=36b4d2b3e3d52222
scope.9.id=function:shared.resolve_tile
scope.9.kind=function
scope.9.startLine=59
scope.9.endLine=70
scope.9.semanticHash=18906c6577594b71
scope.10.id=function:shared.build_game_ctx
scope.10.kind=function
scope.10.startLine=72
scope.10.endLine=77
scope.10.semanticHash=5d4ec4162a5e70f3
scope.11.id=function:shared.option_id_from_action
scope.11.kind=function
scope.11.startLine=79
scope.11.endLine=81
scope.11.semanticHash=616a2ca60599c94f
scope.12.id=function:shared.choice_meta
scope.12.kind=function
scope.12.startLine=83
scope.12.endLine=89
scope.12.semanticHash=a5cf34fb97efa6f8
scope.13.id=function:shared.resolve_choice_player
scope.13.kind=function
scope.13.startLine=91
scope.13.endLine=97
scope.13.semanticHash=7d9edb198acd5336
scope.14.id=function:shared.resolve_choice_tile
scope.14.kind=function
scope.14.startLine=99
scope.14.endLine=105
scope.14.semanticHash=29dbcaa59855240a
]]
