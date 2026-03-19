local inventory = require("src.rules.items.inventory")
local tile = require("src.rules.board.tile")
local monopoly_event = require("src.core.events.monopoly_events")
local movement = require("src.rules.movement")
local bankruptcy_port = require("src.rules.ports.bankruptcy_port")
local gameplay_rules = require("src.config.gameplay.gameplay_rules")
local vehicle_feature = require("src.rules.vehicle")
local number_utils = require("src.core.utils.number_utils")
local action_anim_port = require("src.core.ports.action_anim_port")

local common = {}

local action_anim_duration = gameplay_rules.action_anim_default_seconds or 1.0
local tile_state = tile.get_state
function common.emit_event(kind, payload)
  monopoly_event.emit(kind, payload or {})
end

function common.abs_value(value)
  if value < 0 then
    return -value
  end
  return value
end

function common.apply_cash_change(game, player, delta)
  game:add_player_cash(player, delta)
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

function common.queue_move_effect(game, player, from_index, to_index, visited)
  if not player then
    return false
  end
  local payload = {
    kind = "move_effect",
    player_id = player.id,
    from_index = from_index,
    to_index = to_index,
    visited = visited,
    duration = action_anim_duration,
  }
  return common.queue_action_anim(game, payload)
end

function common.move_steps(game, player, steps, opts)
  local from_index = player.position
  local res = movement.move(game, player, steps, opts)
  assert(res ~= nil, "missing move result")
  common.queue_move_effect(game, player, from_index, player.position, res.visited)
  return {
    kind = "need_landing",
    player_id = player.id,
    board_index = player.position,
    move_result = res,
  }
end

function common.dependencies()
  return {
    inventory = inventory,
    tile_state = tile_state,
    monopoly_event = monopoly_event,
    vehicle_feature = vehicle_feature,
    number_utils = number_utils,
  }
end

return common
