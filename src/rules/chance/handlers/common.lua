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

local common = {}

local action_anim_duration = timing.action_anim_default_seconds or 1.0
local tile_state = tile.get_state
function common.emit_event(game, kind, payload)
  payload = payload or {}
  monopoly_event.emit(kind, payload)
  if game and type(payload.text) == "string" then
    event_feed.publish(game, {
      kind = event_kinds.chance_card,
      text = payload.text,
    })
  end
end

common.abs_value = math.abs

function common.apply_cash_change(game, player, delta, opts)
  game:add_player_cash(player, delta, opts)
end

function common.adjust_chance_delta(game, player, delta)
  if delta > 0 and game:player_has_deity(player, "rich") then
    return delta * 2
  end
  if delta < 0 and game:player_has_deity(player, "poor") then
    return delta * 2
  end
  return delta
end

function common.handle_bankruptcy_if_non_positive(game, player, reason)
  if game:player_balance(player, "金币") > 0 then
    return
  end
  bankruptcy_port.eliminate(game, player, { reason = reason })
end

function common.apply_cash_and_maybe_bankrupt(game, player, delta, reason)
  common.apply_cash_change(game, player, delta)
  common.handle_bankruptcy_if_non_positive(game, player, reason)
end

function common.queue_action_anim(game, payload)
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
  return common.queue_action_anim(game, payload)
end

function common.queue_move_effect(game, player, from_index, to_index, visited)
  return _queue_relocation_anim(game, "move_effect", player, from_index, to_index, visited)
end

function common.queue_forced_relocation(game, player, from_index, to_index)
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

function common.move_steps(game, player, steps, opts)
  local from_index = player.position
  local res = movement.move(game, player, steps, opts)
  assert(res ~= nil, "missing move result")
  local queued = move_anim_port.queue(game, _build_chance_move_anim_payload(player, from_index, res))
  if not queued then
    common.queue_move_effect(game, player, from_index, player.position, res.visited)
  end
  return {
    kind = "need_landing",
    player_id = player.id,
    board_index = player.position,
    move_result = res,
    wait_move_anim = queued == true,
  }
end

function common.dependencies()
  return {
    inventory = inventory,
    tile_state = tile_state,
    monopoly_event = monopoly_event,
    number_utils = number_utils,
  }
end

return common
