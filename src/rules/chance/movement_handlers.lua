local movement_handlers = {}

local teleport_tile_types = {
  hospital = true,
  mountain = true,
  tax = true,
  market = true,
}

function movement_handlers.register(handlers, common)
  local function _backward_move_opts(context)
    local move_opts = {
      facing_mode = "relative_backward",
      skip_market_check = true,
    }
    if context and context.arrival_direction ~= nil then
      move_opts.direction = context.arrival_direction
    end
    return move_opts
  end

  handlers.move_backward = function(game, player, card, context)
    local res = common.move_steps(game, player, -(card.steps or 0), _backward_move_opts(context))
    if res and res.move_result then
      res.move_result.allow_optional = true
    end
    return res
  end

  handlers.move_forward = function(game, player, card)
    return common.move_steps(game, player, card.steps or 0)
  end

  handlers.forced_move = function(game, player, card, context)
    local from_index = player.position
    local idx, t = game:player_relocate(player, {
      destination_tile_id = assert(card.destination_tile_id, "forced_move requires destination_tile_id"),
      move_dir_mode = "forced_move",
    })
    if teleport_tile_types[t.type] == true then
      common.queue_forced_relocation(game, player, from_index, idx)
    else
      common.queue_move_effect(game, player, from_index, idx, nil)
    end
    return {
      kind = "need_landing",
      player_id = player.id,
      board_index = idx,
      move_result = context,
    }
  end
end

return movement_handlers

--[[ mutate4lua-manifest
version=4
projectHash=929a12c8993f4f8b
scope.0.id=chunk:src/rules/chance/movement_handlers.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=55
scope.0.semanticHash=a03946c5a4cbb89d
scope.1.id=function:movement_handlers.register
scope.1.kind=function
scope.1.startLine=10
scope.1.endLine=52
scope.1.semanticHash=cc45e5420c446857
scope.2.id=function:_backward_move_opts
scope.2.kind=function
scope.2.startLine=11
scope.2.endLine=20
scope.2.semanticHash=ed5a118649e54f91
scope.3.id=function:handlers.move_backward
scope.3.kind=function
scope.3.startLine=22
scope.3.endLine=28
scope.3.semanticHash=ee9f353c81c5105b
scope.4.id=function:handlers.move_forward
scope.4.kind=function
scope.4.startLine=30
scope.4.endLine=32
scope.4.semanticHash=0d144a6d54fba61a
scope.5.id=function:handlers.forced_move
scope.5.kind=function
scope.5.startLine=34
scope.5.endLine=51
scope.5.semanticHash=203f5acaa664d601
]]
