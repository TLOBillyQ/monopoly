local bankruptcy = require("src.game.core.runtime.bankruptcy")

local adapter = {}

function adapter.build()
  return {
    eliminate = function(game, player, opts)
      return bankruptcy.eliminate(game, player, opts)
    end,
  }
end

return adapter
