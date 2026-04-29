local event_log = require("src.state.event_log")
local timing = require("src.config.gameplay.timing")

local Adapter = {}
Adapter.__index = Adapter

function Adapter.new(game)
  local self = setmetatable({}, Adapter)
  self.game = game
  game.state = game.state or {}
  game.state.event_log = game.state.event_log or event_log.new()
  return self
end

function Adapter:publish(game, event)
  event_log.append(game.state.event_log, event)

  if event.tip == false then
    return true
  end

  local port = game.tip_output_port
  if not (port and type(port.enqueue) == "function") then
    return true
  end

  port:enqueue(game, {
    text = event.text,
    duration = event.tip_duration or timing.event_tip_default_seconds or 1.0,
    dedupe_key = event.tip_dedupe_key,
    blocks_inter_turn = event.blocks_inter_turn == true,
    source = event.source or ("event_feed:" .. tostring(event.kind)),
  })
  return true
end

return Adapter
