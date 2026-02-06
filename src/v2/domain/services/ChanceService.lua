local chance_cards = require("Config.Generated.ChanceCards")

local common = require("src.v2.domain.services.Common")
local movement_service = require("src.v2.domain.services.MovementService")

local chance_service = {}

local weight_sum = 0
for _, card in ipairs(chance_cards) do
  local weight = card.weight or 0
  if weight < 0 then
    weight = 0
  end
  weight_sum = weight_sum + weight
end

local function _random_card(state)
  if #chance_cards == 0 then
    return nil
  end
  if weight_sum <= 0 then
    return chance_cards[1]
  end
  local seed = state.rng_seed or 1
  seed = (1103515245 * seed + 12345) % 2147483647
  if seed <= 0 then
    seed = 1
  end
  state.rng_seed = seed
  local picked = (seed % weight_sum) + 1
  local acc = 0
  for _, card in ipairs(chance_cards) do
    local weight = card.weight or 0
    if weight < 0 then
      weight = 0
    end
    acc = acc + weight
    if picked <= acc then
      return card
    end
  end
  return chance_cards[1]
end

function chance_service.pick_card(state)
  return _random_card(state)
end

function chance_service.resolve(state, seat, card)
  local player = state.players[seat]
  if not player or not card then
    return {}
  end
  local outcomes = {}

  local function add_cash(target_seat, delta, reason)
    outcomes[#outcomes + 1] = {
      kind = "cash",
      seat = target_seat,
      delta = delta,
      reason = reason,
      card = card,
    }
  end

  local function set_status(target_seat, key, value)
    outcomes[#outcomes + 1] = {
      kind = "status",
      seat = target_seat,
      key = key,
      value = value,
      card = card,
    }
  end

  local function add_item(target_seat, item_id)
    outcomes[#outcomes + 1] = {
      kind = "give_item",
      seat = target_seat,
      item_id = item_id,
      card = card,
    }
  end

  local function discard_item(target_seat, count)
    outcomes[#outcomes + 1] = {
      kind = "discard_item",
      seat = target_seat,
      count = count,
      card = card,
    }
  end

  local function discard_property(target_seat, count)
    outcomes[#outcomes + 1] = {
      kind = "discard_property",
      seat = target_seat,
      count = count,
      card = card,
    }
  end

  local function move_player(target_seat, steps)
    outcomes[#outcomes + 1] = {
      kind = "move_steps",
      seat = target_seat,
      steps = steps,
      card = card,
    }
  end

  local function forced_move(target_seat, tile_id)
    outcomes[#outcomes + 1] = {
      kind = "forced_move",
      seat = target_seat,
      tile_id = tile_id,
      card = card,
    }
  end

  if card.negative and common.has_deity(player, "angel") then
    outcomes[#outcomes + 1] = {
      kind = "immune",
      seat = seat,
      card = card,
    }
    return outcomes
  end

  local effect = card.effect
  if effect == "add_cash" then
    if card.target == "all" then
      for target_seat, target in ipairs(state.players) do
        if not target.eliminated then
          add_cash(target_seat, card.amount or 0, effect)
        end
      end
    else
      add_cash(seat, card.amount or 0, effect)
    end
    return outcomes
  end

  if effect == "pay_cash" then
    if card.target == "all" then
      for target_seat, target in ipairs(state.players) do
        if not target.eliminated then
          add_cash(target_seat, -(card.amount or 0), effect)
        end
      end
    else
      add_cash(seat, -(card.amount or 0), effect)
    end
    return outcomes
  end

  if effect == "percent_pay_cash" then
    if card.target == "all" then
      for target_seat, target in ipairs(state.players) do
        if not target.eliminated then
          local fee = math.floor((target.cash or 0) * ((card.percent or 0) / 100))
          add_cash(target_seat, -fee, effect)
        end
      end
    else
      local fee = math.floor((player.cash or 0) * ((card.percent or 0) / 100))
      add_cash(seat, -fee, effect)
    end
    return outcomes
  end

  if effect == "pay_others" then
    for target_seat, target in ipairs(state.players) do
      if target_seat ~= seat and not target.eliminated then
        local amount = card.amount or 0
        add_cash(seat, -amount, effect)
        add_cash(target_seat, amount, effect)
      end
    end
    return outcomes
  end

  if effect == "collect_from_others" then
    for target_seat, target in ipairs(state.players) do
      if target_seat ~= seat and not target.eliminated then
        local amount = card.amount or 0
        add_cash(target_seat, -amount, effect)
        add_cash(seat, amount, effect)
      end
    end
    return outcomes
  end

  if effect == "set_vehicle" then
    set_status(seat, "seat_vehicle_id", card.vehicle_id)
    return outcomes
  end

  if effect == "grant_item" then
    add_item(seat, card.item_id)
    return outcomes
  end

  if effect == "discard_items" then
    discard_item(seat, card.count or 0)
    return outcomes
  end

  if effect == "discard_properties" then
    discard_property(seat, card.count or 0)
    return outcomes
  end

  if effect == "move_backward" then
    move_player(seat, -(card.steps or 0))
    return outcomes
  end

  if effect == "move_forward" then
    move_player(seat, card.steps or 0)
    return outcomes
  end

  if effect == "forced_move" then
    forced_move(seat, card.destination_tile_id)
    return outcomes
  end

  if effect == "destroy_buildings_on_path" then
    outcomes[#outcomes + 1] = { kind = "destroy_buildings_on_path", seat = seat, card = card }
    return outcomes
  end

  if effect == "reset_tiles_on_path" then
    outcomes[#outcomes + 1] = { kind = "reset_tiles_on_path", seat = seat, card = card }
    return outcomes
  end

  outcomes[#outcomes + 1] = { kind = "noop", seat = seat, card = card }
  return outcomes
end

function chance_service.move_steps(state, seat, steps, opts)
  return movement_service.move(state, seat, steps, opts)
end

return chance_service
