local number_utils = require("src.core.NumberUtils")
local role_id_utils = require("src.core.RoleId")

local item_slice = {}

function item_slice.resolve_slot_count(ui_runtime)
  local slot_count = 5
  if ui_runtime and type(ui_runtime.item_slots) == "table" and #ui_runtime.item_slots > 0 then
    slot_count = #ui_runtime.item_slots
  end
  return slot_count
end

function item_slice.build_item_slots_for_player(player, slot_count)
  local current_items = {}
  if player and player.inventory and type(player.inventory.items) == "table" then
    current_items = player.inventory.items
  end
  local item_slots = {}
  local pos = 1
  for i = 1, #current_items do
    if pos > slot_count then
      break
    end
    local item = current_items[i]
    if item and item.id then
      item_slots[pos] = item.id
      pos = pos + 1
    end
  end
  for i = pos, slot_count do
    item_slots[i] = nil
  end
  return item_slots
end

function item_slice.build_item_slots_by_player(players, slot_count)
  local out = {}
  for _, player in ipairs(players or {}) do
    local player_id = role_id_utils.normalize(player and player.id or nil)
    if player_id then
      role_id_utils.write(out, player_id, item_slice.build_item_slots_for_player(player, slot_count))
    end
  end
  return out
end

function item_slice.build_auto_enabled_by_player(players)
  local out = {}
  for _, player in ipairs(players or {}) do
    local player_id = role_id_utils.normalize(player and player.id or nil)
    if player_id then
      role_id_utils.write(out, player_id, player.auto == true)
    end
  end
  return out
end

function item_slice.resolve_item_choice_owner_id(game, choice, current_player_id)
  local owner_role_id = role_id_utils.normalize(current_player_id)
  local pending = game and game.turn and game.turn.pending_choice or nil
  if pending and pending.owner_role_id ~= nil then
    owner_role_id = number_utils.to_integer(pending.owner_role_id)
    return owner_role_id
  end
  if choice and choice.owner_role_id ~= nil then
    owner_role_id = number_utils.to_integer(choice.owner_role_id)
  end
  return owner_role_id
end

return item_slice
