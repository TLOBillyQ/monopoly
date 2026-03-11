local property_query = require("src.game.systems.board.property_query")

local resolver = {}

function resolver.safe_tile_state(game, tile)
  return property_query.safe_tile_state(game, tile)
end

function resolver.resolve_rent_owner(game, tile, state_fn)
  return property_query.resolve_rent_owner(game, tile, state_fn)
end

function resolver.contiguous_rent(game, board, index, owner_id)
  return property_query.contiguous_rent(game, board, index, owner_id)
end

return resolver
