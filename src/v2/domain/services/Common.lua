local constants = require("Config.Generated.Constants")
local gameplay_rules = require("Config.GameplayRules")

local common = {}

local item_ids = gameplay_rules.item_ids or {}

common.item_ids = item_ids

local function _max_inventory(player)
  local inv = player and player.inventory
  if not inv then
    return constants.inventory_slots or 5
  end
  return inv.max_slots or constants.inventory_slots or 5
end

function common.find_item_index(player, item_id)
  local items = player and player.inventory and player.inventory.items or {}
  for index, item in ipairs(items) do
    if item and item.id == item_id then
      return index
    end
  end
  return nil
end

function common.has_item(player, item_id)
  return common.find_item_index(player, item_id) ~= nil
end

function common.consume_item(player, item_id)
  local idx = common.find_item_index(player, item_id)
  if not idx then
    return nil
  end
  return table.remove(player.inventory.items, idx)
end

function common.give_item(player, item_id)
  local items = player and player.inventory and player.inventory.items or nil
  if not items then
    return false
  end
  if #items >= _max_inventory(player) then
    return false
  end
  items[#items + 1] = { id = item_id }
  return true
end

function common.count_item(player)
  local items = player and player.inventory and player.inventory.items or {}
  return #items
end

function common.clear_inventory(player)
  if not player or not player.inventory then
    return
  end
  player.inventory.items = {}
end

function common.balance_of(player, currency)
  if currency == "金币" then
    return player.cash or 0
  end
  return (player.balances and player.balances[currency]) or 0
end

function common.set_balance(player, currency, value)
  if currency == "金币" then
    player.cash = value
    return
  end
  player.balances = player.balances or {}
  player.balances[currency] = value
end

function common.change_balance(player, currency, delta)
  local next_value = common.balance_of(player, currency) + delta
  common.set_balance(player, currency, next_value)
  return next_value
end

function common.has_deity(player, deity_name)
  local deity = player and player.status and player.status.deity
  if not deity then
    return false
  end
  return deity.type == deity_name and (deity.remaining or 0) > 0
end

function common.clear_temporal_flags(player)
  local status = player.status
  status.pending_dice_multiplier = 1
  status.pending_free_rent = false
  status.pending_tax_free = false
  status.pending_remote_dice = nil
end

function common.default_dice_count(player)
  if not player then
    return constants.default_dice_count or 1
  end
  local seat = player.seat_vehicle_id
  if seat then
    return constants.dice_with_vehicle or 2
  end
  return constants.default_dice_count or 1
end

function common.total_assets(state, seat)
  local player = state.players[seat]
  if not player then
    return 0
  end
  local total = player.cash or 0
  for tile_id in pairs(player.properties or {}) do
    local def = state.board.tile_defs[tile_id]
    local st = state.board.tile_states[tile_id]
    if def and st then
      local level = st.level or 0
      total = total + (def.price or 0)
      local costs = def.upgrade_costs or {}
      for index = 1, level do
        total = total + (costs[index] or 0)
      end
    end
  end
  return total
end

return common
