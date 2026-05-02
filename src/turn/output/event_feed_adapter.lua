local event_log = require("src.state.event_log")
local timing = require("src.config.gameplay.timing")
local logger = require("src.foundation.log.logger")

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

  local intent = {
    text = event.text,
    duration = event.tip_duration or timing.event_tip_default_seconds or 1.0,
    dedupe_key = event.tip_dedupe_key,
    blocks_inter_turn = event.blocks_inter_turn == true,
    source = event.source or ("event_feed:" .. tostring(event.kind)),
  }

  local port = game.tip_output_port
  if port and type(port.enqueue) == "function" then
    port.enqueue(game, intent)
  else
    logger.warn("[event_feed_adapter]", "tip_output_port missing, falling back to tip_queue | event:", tostring(event.kind))
    require("src.foundation.coordination.tip_queue").enqueue(intent)
  end
  return true
end

return Adapter
