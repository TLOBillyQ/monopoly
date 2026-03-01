local inventory = require("src.game.systems.items.ItemInventory")
local tile = require("src.game.systems.board.Tile")
local monopoly_event = require("src.core.events.MonopolyEvents")
local movement = require("src.game.systems.movement.Movement")
local bankruptcy = require("src.game.core.runtime.Bankruptcy")
local gameplay_rules = require("Config.GameplayRules")
local vehicles_cfg = require("Config.Generated.Vehicles")
local vehicle_feature = require("src.game.systems.vehicle.VehicleFeature")
local number_utils = require("src.core.NumberUtils")
local action_anim_port = require("src.core.ActionAnimPort")

local common = {}

local action_anim_duration = gameplay_rules.action_anim_default_seconds or 1.0
local tile_state = tile.get_state
local vehicle_name_by_id = {}
for _, cfg in ipairs(vehicles_cfg) do
  vehicle_name_by_id[cfg.id] = cfg.name
end

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
  bankruptcy.eliminate(game, player, { reason = reason })
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
  if res.stopped_on_roadblock then
    local stay = player.status.stay_turns or 0
    if stay < 1 then
      game:set_player_status(player, "stay_turns", 1)
    end
  end
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
    vehicle_name_by_id = vehicle_name_by_id,
    number_utils = number_utils,
  }
end

return common

