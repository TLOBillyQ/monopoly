local movement_handlers = {}

local teleport_tile_types = {
  hospital = true,
  mountain = true,
  tax = true,
  market = true,
}

function movement_handlers.register(handlers, common)
  handlers.move_backward = function(game, player, card, context)
    local move_opts = {
      facing_mode = "relative_backward",
      skip_market_check = true,
    }
    if context and context.arrival_direction ~= nil then
      move_opts.direction = context.arrival_direction
    end
    local res = common.move_steps(game, player, -(card.steps or 0), move_opts)
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
version=2
projectHash=7a0ffe697d60fe7e
scope.0.id=chunk:src/rules/chance/movement_handlers.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=51
scope.0.semanticHash=5470e825ec0ca9ad
scope.0.lastMutatedAt=2026-07-07T04:14:13Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=4
scope.0.lastMutationKilled=4
scope.1.id=function:anonymous@11:11
scope.1.kind=function
scope.1.startLine=11
scope.1.endLine=24
scope.1.semanticHash=5686b4eb5564e41e
scope.1.lastMutatedAt=2026-07-07T04:14:13Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=7
scope.1.lastMutationKilled=7
scope.2.id=function:anonymous@26:26
scope.2.kind=function
scope.2.startLine=26
scope.2.endLine=28
scope.2.semanticHash=d80139c1d7cab276
scope.2.lastMutatedAt=2026-07-07T04:14:13Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=1
scope.2.lastMutationKilled=1
scope.3.id=function:anonymous@30:30
scope.3.kind=function
scope.3.startLine=30
scope.3.endLine=47
scope.3.semanticHash=3bb6d85e8910f848
scope.3.lastMutatedAt=2026-07-07T04:14:13Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=6
scope.3.lastMutationKilled=6
scope.4.id=function:movement_handlers.register:10
scope.4.kind=function
scope.4.startLine=10
scope.4.endLine=48
scope.4.semanticHash=b1c870931c7caccf
scope.4.lastMutatedAt=2026-07-07T03:30:04Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=no_sites
scope.4.lastMutationSites=0
scope.4.lastMutationKilled=0
]]
