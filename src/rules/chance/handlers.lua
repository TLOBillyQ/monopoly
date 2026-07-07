local inventory = require("src.rules.items.inventory")
local tile = require("src.rules.board.tile")
local monopoly_event = require("src.foundation.events")
local movement = require("src.rules.movement")
local bankruptcy_port = require("src.rules.ports.bankruptcy")
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

function shared.handle_bankruptcy_if_non_positive(game, player, reason)
  if game:player_cash(player) > 0 then
    return
  end
  bankruptcy_port.eliminate(game, player, { reason = reason })
end

function shared.apply_cash_and_maybe_bankrupt(game, player, delta, reason)
  shared.apply_cash_change(game, player, delta)
  shared.handle_bankruptcy_if_non_positive(game, player, reason)
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
version=2
projectHash=339ea2fc5c3e209d
scope.0.id=chunk:src/rules/chance/handlers.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=453
scope.0.semanticHash=c2cc96e8f2c9e253
scope.0.lastMutatedAt=2026-06-01T04:05:09Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=survived
scope.0.lastMutationSites=81
scope.0.lastMutationKilled=80
scope.1.id=function:shared.emit_event:19
scope.1.kind=function
scope.1.startLine=19
scope.1.endLine=28
scope.1.semanticHash=93b00a792d15b855
scope.1.lastMutatedAt=2026-06-01T04:05:09Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=survived
scope.1.lastMutationSites=7
scope.1.lastMutationKilled=6
scope.2.id=function:shared.apply_cash_change:32
scope.2.kind=function
scope.2.startLine=32
scope.2.endLine=34
scope.2.semanticHash=6f946c54fefb76e5
scope.2.lastMutatedAt=2026-06-01T04:05:09Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=1
scope.2.lastMutationKilled=1
scope.3.id=function:shared.adjust_chance_delta:36
scope.3.kind=function
scope.3.startLine=36
scope.3.endLine=44
scope.3.semanticHash=8bfbb9f8a46c2cc4
scope.3.lastMutatedAt=2026-06-01T04:05:09Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=survived
scope.3.lastMutationSites=10
scope.3.lastMutationKilled=7
scope.4.id=function:shared.handle_bankruptcy_if_non_positive:46
scope.4.kind=function
scope.4.startLine=46
scope.4.endLine=51
scope.4.semanticHash=107a94b630a14373
scope.4.lastMutatedAt=2026-06-01T04:05:09Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=4
scope.4.lastMutationKilled=4
scope.5.id=function:shared.apply_cash_and_maybe_bankrupt:53
scope.5.kind=function
scope.5.startLine=53
scope.5.endLine=56
scope.5.semanticHash=748f524ba83eecab
scope.5.lastMutatedAt=2026-06-01T04:05:09Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=2
scope.5.lastMutationKilled=2
scope.6.id=function:shared.queue_action_anim:58
scope.6.kind=function
scope.6.startLine=58
scope.6.endLine=63
scope.6.semanticHash=4f32cbf0112d879d
scope.6.lastMutatedAt=2026-06-01T04:05:09Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=survived
scope.6.lastMutationSites=3
scope.6.lastMutationKilled=2
scope.7.id=function:_queue_relocation_anim:65
scope.7.kind=function
scope.7.startLine=65
scope.7.endLine=78
scope.7.semanticHash=8a32e710d5eccab0
scope.7.lastMutatedAt=2026-06-01T04:05:09Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=survived
scope.7.lastMutationSites=3
scope.7.lastMutationKilled=2
scope.8.id=function:shared.queue_move_effect:80
scope.8.kind=function
scope.8.startLine=80
scope.8.endLine=82
scope.8.semanticHash=0a42cb662d828fbe
scope.8.lastMutatedAt=2026-06-01T04:05:09Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=1
scope.8.lastMutationKilled=1
scope.9.id=function:shared.queue_forced_relocation:84
scope.9.kind=function
scope.9.startLine=84
scope.9.endLine=86
scope.9.semanticHash=20de6b46ef8d9085
scope.9.lastMutatedAt=2026-06-01T04:05:09Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=passed
scope.9.lastMutationSites=1
scope.9.lastMutationKilled=1
scope.10.id=function:_build_chance_move_anim_payload:88
scope.10.kind=function
scope.10.startLine=88
scope.10.endLine=97
scope.10.semanticHash=7a1a1710b6260cd5
scope.10.lastMutatedAt=2026-06-01T04:05:09Z
scope.10.lastMutationLane=behavior
scope.10.lastMutationStatus=passed
scope.10.lastMutationSites=1
scope.10.lastMutationKilled=1
scope.11.id=function:shared.move_steps:99
scope.11.kind=function
scope.11.startLine=99
scope.11.endLine=114
scope.11.semanticHash=d0342d17aef38778
scope.11.lastMutatedAt=2026-06-01T04:05:09Z
scope.11.lastMutationLane=behavior
scope.11.lastMutationStatus=passed
scope.11.lastMutationSites=8
scope.11.lastMutationKilled=8
scope.12.id=function:shared.dependencies:116
scope.12.kind=function
scope.12.startLine=116
scope.12.endLine=123
scope.12.semanticHash=13d59334abf08103
scope.13.id=function:anonymous@138:138
scope.13.kind=function
scope.13.startLine=138
scope.13.endLine=147
scope.13.semanticHash=f18e213474a32a26
scope.14.id=function:anonymous@136:136
scope.14.kind=function
scope.14.startLine=136
scope.14.endLine=159
scope.14.semanticHash=f12db4f60c3f3e66
scope.14.lastMutatedAt=2026-06-01T04:05:09Z
scope.14.lastMutationLane=behavior
scope.14.lastMutationStatus=passed
scope.14.lastMutationSites=6
scope.14.lastMutationKilled=6
scope.15.id=function:_apply_payment:161
scope.15.kind=function
scope.15.startLine=161
scope.15.endLine=172
scope.15.semanticHash=1f9cd53d983d4b6a
scope.15.lastMutatedAt=2026-06-01T04:05:09Z
scope.15.lastMutationLane=behavior
scope.15.lastMutationStatus=passed
scope.15.lastMutationSites=8
scope.15.lastMutationKilled=8
scope.16.id=function:anonymous@176:176
scope.16.kind=function
scope.16.startLine=176
scope.16.endLine=182
scope.16.semanticHash=745724e933b18a5e
scope.17.id=function:_dispatch_payment:174
scope.17.kind=function
scope.17.startLine=174
scope.17.endLine=186
scope.17.semanticHash=b8b611aabfb71c6f
scope.17.lastMutatedAt=2026-06-01T04:05:09Z
scope.17.lastMutationLane=behavior
scope.17.lastMutationStatus=passed
scope.17.lastMutationSites=4
scope.17.lastMutationKilled=4
scope.18.id=function:_fee_flat:188
scope.18.kind=function
scope.18.startLine=188
scope.18.endLine=188
scope.18.semanticHash=a95c7c89770a8336
scope.19.id=function:_fee_percent:189
scope.19.kind=function
scope.19.startLine=189
scope.19.endLine=191
scope.19.semanticHash=f4806f818e79518d
scope.19.lastMutatedAt=2026-06-01T04:05:09Z
scope.19.lastMutationLane=behavior
scope.19.lastMutationStatus=passed
scope.19.lastMutationSites=1
scope.19.lastMutationKilled=1
scope.20.id=function:anonymous@193:193
scope.20.kind=function
scope.20.startLine=193
scope.20.endLine=195
scope.20.semanticHash=a010c205852f6a60
scope.20.lastMutatedAt=2026-06-01T04:05:09Z
scope.20.lastMutationLane=behavior
scope.20.lastMutationStatus=passed
scope.20.lastMutationSites=1
scope.20.lastMutationKilled=1
scope.21.id=function:anonymous@197:197
scope.21.kind=function
scope.21.startLine=197
scope.21.endLine=199
scope.21.semanticHash=c28ee76cc0bffb56
scope.21.lastMutatedAt=2026-06-01T04:05:09Z
scope.21.lastMutationLane=behavior
scope.21.lastMutationStatus=passed
scope.21.lastMutationSites=1
scope.21.lastMutationKilled=1
scope.22.id=function:anonymous@224:224
scope.22.kind=function
scope.22.startLine=224
scope.22.endLine=254
scope.22.semanticHash=eb1a362cff4bae8b
scope.22.lastMutatedAt=2026-06-01T04:05:09Z
scope.22.lastMutationLane=behavior
scope.22.lastMutationStatus=passed
scope.22.lastMutationSites=19
scope.22.lastMutationKilled=19
scope.23.id=function:anonymous@299:299
scope.23.kind=function
scope.23.startLine=299
scope.23.endLine=301
scope.23.semanticHash=12895306c12a287b
scope.23.lastMutatedAt=2026-06-01T04:05:09Z
scope.23.lastMutationLane=behavior
scope.23.lastMutationStatus=passed
scope.23.lastMutationSites=1
scope.23.lastMutationKilled=1
scope.24.id=function:anonymous@336:336
scope.24.kind=function
scope.24.startLine=336
scope.24.endLine=343
scope.24.semanticHash=3cb10b96dddc41c7
scope.24.lastMutatedAt=2026-06-01T04:02:54Z
scope.24.lastMutationLane=behavior
scope.24.lastMutationStatus=no_sites
scope.24.lastMutationSites=0
scope.24.lastMutationKilled=0
scope.25.id=function:_resolve_drop_rng:347
scope.25.kind=function
scope.25.startLine=347
scope.25.endLine=354
scope.25.semanticHash=8fe86b430d501cf2
scope.25.lastMutatedAt=2026-06-01T04:05:09Z
scope.25.lastMutationLane=behavior
scope.25.lastMutationStatus=survived
scope.25.lastMutationSites=9
scope.25.lastMutationKilled=6
scope.26.id=function:_pick_property_index:356
scope.26.kind=function
scope.26.startLine=356
scope.26.endLine=361
scope.26.semanticHash=53cb6d4b963a86d5
scope.26.lastMutatedAt=2026-06-01T04:05:09Z
scope.26.lastMutationLane=behavior
scope.26.lastMutationStatus=passed
scope.26.lastMutationSites=2
scope.26.lastMutationKilled=2
scope.27.id=function:anonymous@363:363
scope.27.kind=function
scope.27.startLine=363
scope.27.endLine=389
scope.27.semanticHash=f4452049b1d4d1ee
scope.27.lastMutatedAt=2026-06-01T04:05:09Z
scope.27.lastMutationLane=behavior
scope.27.lastMutationStatus=passed
scope.27.lastMutationSites=13
scope.27.lastMutationKilled=13
scope.28.id=function:anonymous@399:399
scope.28.kind=function
scope.28.startLine=399
scope.28.endLine=412
scope.28.semanticHash=5686b4eb5564e41e
scope.28.lastMutatedAt=2026-06-01T04:05:09Z
scope.28.lastMutationLane=behavior
scope.28.lastMutationStatus=survived
scope.28.lastMutationSites=7
scope.28.lastMutationKilled=6
scope.29.id=function:anonymous@414:414
scope.29.kind=function
scope.29.startLine=414
scope.29.endLine=416
scope.29.semanticHash=d80139c1d7cab276
scope.29.lastMutatedAt=2026-06-01T04:05:09Z
scope.29.lastMutationLane=behavior
scope.29.lastMutationStatus=passed
scope.29.lastMutationSites=1
scope.29.lastMutationKilled=1
scope.30.id=function:anonymous@418:418
scope.30.kind=function
scope.30.startLine=418
scope.30.endLine=435
scope.30.semanticHash=3bb6d85e8910f848
scope.30.lastMutatedAt=2026-06-01T04:05:09Z
scope.30.lastMutationLane=behavior
scope.30.lastMutationStatus=passed
scope.30.lastMutationSites=6
scope.30.lastMutationKilled=6
scope.31.id=function:_register_movement_handlers:398
scope.31.kind=function
scope.31.startLine=398
scope.31.endLine=436
scope.31.semanticHash=d3db4d3cafcd9507
scope.31.lastMutatedAt=2026-06-01T04:02:54Z
scope.31.lastMutationLane=behavior
scope.31.lastMutationStatus=no_sites
scope.31.lastMutationSites=0
scope.31.lastMutationKilled=0
scope.32.id=function:handlers.build:440
scope.32.kind=function
scope.32.startLine=440
scope.32.endLine=447
scope.32.semanticHash=d9658e8261da808b
scope.32.lastMutatedAt=2026-06-01T04:05:09Z
scope.32.lastMutationLane=behavior
scope.32.lastMutationStatus=passed
scope.32.lastMutationSites=3
scope.32.lastMutationKilled=3
]]
