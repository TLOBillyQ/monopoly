local auto_play_port_adapter = require("src.game.runtime.auto_play_port_adapter")
local bankruptcy_port_adapter = require("src.game.runtime.bankruptcy_port_adapter")

local default_ports = {}

local function _build_missing_port(current, builder)
  if type(current) == "table" then
    return current
  end
  return builder()
end

function default_ports.resolve_game_opts(opts)
  opts = opts or {}
  opts.auto_play_port = _build_missing_port(opts.auto_play_port, auto_play_port_adapter.build)
  opts.bankruptcy_port = _build_missing_port(opts.bankruptcy_port, bankruptcy_port_adapter.build)
  return opts
end

function default_ports.install(game)
  if type(game) ~= "table" then
    return game
  end
  game.auto_play_port = _build_missing_port(game.auto_play_port, auto_play_port_adapter.build)
  game.bankruptcy_port = _build_missing_port(game.bankruptcy_port, bankruptcy_port_adapter.build)
  return game
end

return default_ports
