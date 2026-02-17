local inventory = require("game.item.inventory")
local tile = require("game.tile")
local monopoly_event = require("game.event")
local movement = require("game.move")
local bankruptcy = require("game.rule.bankrupt")
local gameplay_rules = require("cfg.GameplayRules")
local vehicles_cfg = require("cfg.Generated.Vehicles")
local vehicle_feature = require("game.vehicle")
local number_utils = require("core.math")

local action_anim_duration = gameplay_rules.action_anim_default_seconds or 1.0

local tile_state = tile.get_state

local vehicle_name_by_id = {}
for _, cfg in ipairs(vehicles_cfg) do
  vehicle_name_by_id[cfg.id] = cfg.name
end

local utils = {}

function utils.emit_event(kind, payload)
  if TriggerCustomEvent then
    TriggerCustomEvent(kind, payload or {})
  end
end

function utils.abs_value(value)
  if value < 0 then
    return -value
  end
  return value
end

function utils.apply_cash_change(game, player, delta)
  game:add_player_cash(player, delta)
end

function utils.adjust_chance_delta(game, player, delta)
  if delta > 0 and game:player_has_deity(player, "rich") then
    return delta * 2
  end
  if delta < 0 and game:player_has_deity(player, "poor") then
    return delta * 2
  end
  return delta
end

function utils.handle_bankruptcy_if_negative(game, player, reason)
  if game:player_balance(player, "金币") > 0 then
    return
  end
  bankruptcy.eliminate(game, player, { reason = reason })
end

function utils.apply_cash_and_maybe_bankrupt(game, player, delta, reason)
  utils.apply_cash_change(game, player, delta)
  utils.handle_bankruptcy_if_negative(game, player, reason)
end

function utils.queue_action_anim(game, payload)
  if not game or not payload then
    return false
  end
  local ui_port = game.ui_port
  if not (ui_port and ui_port.wait_action_anim) then
    return false
  end
  if not game.queue_action_anim then
    return false
  end
  game:queue_action_anim(payload)
  return true
end

function utils.queue_move_effect(game, player, from_index, to_index, visited)
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
  return utils.queue_action_anim(game, payload)
end

function utils.move_steps(game, player, steps, opts)
  local from_index = player.position
  local res = movement.move(game, player, steps, opts)
  assert(res ~= nil, "missing move result")
  utils.queue_move_effect(game, player, from_index, player.position, res.visited)
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

utils.tile_state = tile_state
utils.vehicle_name_by_id = vehicle_name_by_id
utils.number_utils = number_utils
utils.inventory = inventory
utils.vehicle_feature = vehicle_feature
utils.monopoly_event = monopoly_event

return utils
