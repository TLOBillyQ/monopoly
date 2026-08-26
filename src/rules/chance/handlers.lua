local inventory = require("src.rules.items.inventory")
local tile = require("src.rules.board.tile")
local monopoly_event = require("src.foundation.events")
local movement = require("src.rules.movement")
local timing = require("src.config.gameplay.timing")
local number_utils = require("src.foundation.number")
local action_anim_port = require("src.foundation.ports.action_anim")
local move_anim_port = require("src.foundation.ports.move_anim")
local event_feed = require("src.rules.ports.event_feed")
local event_kinds = require("src.config.gameplay.event_kinds")
local achievement_progress = require("src.rules.ports.achievement_progress")
local cash_handlers = require("src.rules.chance.cash_handlers")
local asset_handlers = require("src.rules.chance.asset_handlers")
local movement_handlers = require("src.rules.chance.movement_handlers")

local shared = {}

local action_anim_duration = timing.action_anim_default_seconds or 1.0
local tile_state = tile.get_state

function shared.emit_event(game, kind, payload)
  payload = payload or {}
  monopoly_event.emit(kind, payload)
  if game and type(payload.text) == "string" then
    event_feed.publish(game, {
      kind = event_kinds.chance_card,
      text = payload.text,
    })
  end
end

shared.abs_value = math.abs

function shared.apply_cash_change(game, player, delta, opts)
  game:add_player_cash(player, delta, opts)
  local amount = number_utils.to_integer(delta)
  shared.record_cash_received(game, player, amount)
end

function shared.record_cash_received(game, player, amount)
  if amount and amount > 0 then
    achievement_progress.cash_received(game, player, amount)
  end
end

function shared.adjust_chance_delta(game, player, delta)
  if delta > 0 and game:player_has_deity(player, "rich") then
    return delta * 2
  end
  if delta < 0 and game:player_has_deity(player, "poor") then
    return delta * 2
  end
  return delta
end

function shared.queue_action_anim(game, payload)
  if not payload then
    return false
  end
  return action_anim_port.queue(game, payload)
end

local function _queue_relocation_anim(game, kind, player, from_index, to_index, visited)
  if not player then
    return false
  end
  local payload = {
    kind = kind,
    player_id = player.id,
    from_index = from_index,
    to_index = to_index,
    visited = visited,
    duration = action_anim_duration,
  }
  return shared.queue_action_anim(game, payload)
end

function shared.queue_move_effect(game, player, from_index, to_index, visited)
  return _queue_relocation_anim(game, "move_effect", player, from_index, to_index, visited)
end

function shared.queue_forced_relocation(game, player, from_index, to_index)
  return _queue_relocation_anim(game, "forced_relocation", player, from_index, to_index, nil)
end

local function _build_chance_move_anim_payload(player, from_index, move_result)
  return {
    player_id = player.id,
    from_index = from_index,
    to_index = player.position,
    visited = move_result.visited,
    steps = move_result.steps,
    source = "chance_move",
  }
end

function shared.move_steps(game, player, steps, opts)
  local from_index = player.position
  local res = movement.move(game, player, steps, opts)
  assert(res ~= nil, "missing move result")
  local queued = move_anim_port.queue(game, _build_chance_move_anim_payload(player, from_index, res))
  if not queued then
    shared.queue_move_effect(game, player, from_index, player.position, res.visited)
  end
  return {
    kind = "need_landing",
    player_id = player.id,
    board_index = player.position,
    move_result = res,
    wait_move_anim = queued == true,
  }
end

function shared.dependencies()
  return {
    inventory = inventory,
    tile_state = tile_state,
    monopoly_event = monopoly_event,
    number_utils = number_utils,
  }
end

local handlers = {}

function handlers.build()
  local built = {}
  cash_handlers.register(built, shared)
  asset_handlers.register(built, shared)
  movement_handlers.register(built, shared)
  built.handlers = built
  return built
end

handlers._cash = cash_handlers
handlers._asset = asset_handlers

return handlers

--[[ mutate4lua-manifest
version=4
projectHash=5db756d6bcffa0e6
scope.0.id=chunk:src/rules/chance/handlers.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=138
scope.0.semanticHash=f761f9fb737dbb45
scope.1.id=function:shared.emit_event
scope.1.kind=function
scope.1.startLine=21
scope.1.endLine=30
scope.1.semanticHash=8fa9ece60f4fada2
scope.2.id=function:shared.apply_cash_change
scope.2.kind=function
scope.2.startLine=34
scope.2.endLine=38
scope.2.semanticHash=b76b5880f7864f80
scope.3.id=function:shared.record_cash_received
scope.3.kind=function
scope.3.startLine=40
scope.3.endLine=44
scope.3.semanticHash=1e9a7ef67167ffd9
scope.4.id=function:shared.adjust_chance_delta
scope.4.kind=function
scope.4.startLine=46
scope.4.endLine=54
scope.4.semanticHash=e94c327dc047995a
scope.5.id=function:shared.queue_action_anim
scope.5.kind=function
scope.5.startLine=56
scope.5.endLine=61
scope.5.semanticHash=d777eacfec5974ff
scope.6.id=function:_queue_relocation_anim
scope.6.kind=function
scope.6.startLine=63
scope.6.endLine=76
scope.6.semanticHash=dfe016c49834040c
scope.7.id=function:shared.queue_move_effect
scope.7.kind=function
scope.7.startLine=78
scope.7.endLine=80
scope.7.semanticHash=3636edac36ec76d7
scope.8.id=function:shared.queue_forced_relocation
scope.8.kind=function
scope.8.startLine=82
scope.8.endLine=84
scope.8.semanticHash=8f8c7ea3d1e6fd65
scope.9.id=function:_build_chance_move_anim_payload
scope.9.kind=function
scope.9.startLine=86
scope.9.endLine=95
scope.9.semanticHash=9128526da7103830
scope.10.id=function:shared.move_steps
scope.10.kind=function
scope.10.startLine=97
scope.10.endLine=112
scope.10.semanticHash=89f8c0ce9952d6d0
scope.11.id=function:shared.dependencies
scope.11.kind=function
scope.11.startLine=114
scope.11.endLine=121
scope.11.semanticHash=20b0251f00785710
scope.12.id=function:handlers.build
scope.12.kind=function
scope.12.startLine=125
scope.12.endLine=132
scope.12.semanticHash=7b4fc651c64ab776
]]
