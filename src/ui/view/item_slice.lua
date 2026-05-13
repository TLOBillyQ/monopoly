local role_id_utils = require("src.foundation.identity.role_id")
local choice_contract = require("src.config.choice.contract")

local item_slice = {}

function item_slice.resolve_slot_count(ui_runtime)
  local slot_count = 5
  if ui_runtime and type(ui_runtime.item_slots) == "table" and #ui_runtime.item_slots > 0 then
    slot_count = #ui_runtime.item_slots
  end
  return slot_count
end

local _empty_items = {}

local function _fill_item_slots(item_slots, items, slot_count)
  local pos = 1
  for i = 1, #items do
    if pos > slot_count then
      break
    end
    local item = items[i]
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

local _standalone_item_slots = {}

function item_slice.build_item_slots_for_player(player, slot_count)
  local items = (player and player.inventory and type(player.inventory.items) == "table")
    and player.inventory.items or _empty_items
  return _fill_item_slots(_standalone_item_slots, items, slot_count)
end

local _slots_by_player = {}
local _slots_pool = {}
local _auto_by_player = {}

function item_slice.build_item_slots_by_player(players, slot_count)
  for k in pairs(_slots_by_player) do
    _slots_by_player[k] = nil
  end
  for _, player in ipairs(players or {}) do
    local player_id = role_id_utils.normalize(player and player.id or nil)
    if player_id then
      local items = (player and player.inventory and type(player.inventory.items) == "table")
        and player.inventory.items or _empty_items
      local slots = _slots_pool[player_id]
      if slots == nil then
        slots = {}
        _slots_pool[player_id] = slots
      end
      _fill_item_slots(slots, items, slot_count)
      role_id_utils.write(_slots_by_player, player_id, slots)
    end
  end
  return _slots_by_player
end

function item_slice.build_auto_enabled_by_player(players)
  for k in pairs(_auto_by_player) do
    _auto_by_player[k] = nil
  end
  for _, player in ipairs(players or {}) do
    local player_id = role_id_utils.normalize(player and player.id or nil)
    if player_id then
      role_id_utils.write(_auto_by_player, player_id, player.auto == true)
    end
  end
  return _auto_by_player
end

function item_slice.resolve_item_choice_owner_id(game, choice, current_player_id)
  local owner_role_id = role_id_utils.normalize(current_player_id)
  local pending = game and game.turn and game.turn.pending_choice or nil
  local pending_owner_role_id = choice_contract.resolve_owner_role_id(pending)
  if pending_owner_role_id ~= nil then
    return pending_owner_role_id
  end
  local choice_owner_role_id = choice_contract.resolve_owner_role_id(choice)
  if choice_owner_role_id ~= nil then
    owner_role_id = choice_owner_role_id
  end
  return owner_role_id
end

return item_slice
