local bankruptcy_port = {}

local function _fallback_port()
  local runtime_bankruptcy = require("src.game.core.runtime.Bankruptcy")
  return {
    eliminate = function(game, player, opts)
      return runtime_bankruptcy.eliminate(game, player, opts)
    end,
  }
end

local function _resolve_port(game)
  if not game then
    return nil
  end
  local port = game.bankruptcy_port
  if type(port) == "table" then
    return port
  end
  return _fallback_port()
end

function bankruptcy_port.eliminate(game, player, opts)
  local port = _resolve_port(game)
  if not port or type(port.eliminate) ~= "function" then
    return nil
  end
  return port.eliminate(game, player, opts)
end

return bankruptcy_port
